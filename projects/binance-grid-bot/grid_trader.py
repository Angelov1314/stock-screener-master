#!/usr/bin/env python3
"""
Grid Trading Bot - 网格交易核心框架
包含: 行情连接、网格逻辑、订单管理
"""

import yaml
import asyncio
import logging
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime
import ccxt.async_support as ccxt
import numpy as np
import pandas as pd
from ta.volatility import BollingerBands
from ta.trend import ADXIndicator


@dataclass
class GridLevel:
    """网格层级数据"""
    level: int
    price: float
    side: str  # 'buy' or 'sell'
    amount: float
    order_id: Optional[str] = None
    filled: bool = False


@dataclass
class Position:
    """持仓数据"""
    symbol: str
    quantity: float
    avg_price: float
    unrealized_pnl: float
    layers: int = 0


class GridTrader:
    """网格交易主类"""
    
    def __init__(self, config_path: str = "config.yaml"):
        # 加载配置
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # 初始化交易所
        self.exchange = None
        self.symbol = self.config['trading']['symbol']
        
        # 网格状态
        self.grid_levels: List[GridLevel] = []
        self.position = Position(symbol=self.symbol, quantity=0, avg_price=0, unrealized_pnl=0)
        self.current_price = 0.0
        self.anchor_price = 0.0
        
        # 风控状态
        self.consecutive_errors = 0
        self.circuit_breaker_active = False
        self.cooldown_until = None
        
        # 日志
        self.setup_logging()
        
    def setup_logging(self):
        """设置日志"""
        log_level = getattr(logging, self.config['runtime']['log_level'])
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(f'logs/grid_bot_{datetime.now().strftime("%Y%m%d")}.log'),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    async def initialize(self):
        """初始化交易所连接"""
        try:
            exchange_id = self.config['trading']['exchange']
            market_type = self.config['trading'].get('market_type', 'spot')
            
            # 动态创建交易所实例
            exchange_class = getattr(ccxt, exchange_id)
            self.exchange = exchange_class({
                'apiKey': os.getenv('BINANCE_API_KEY'),
                'secret': os.getenv('BINANCE_SECRET_KEY'),
                'enableRateLimit': True,
                'options': {
                    'defaultType': 'future' if market_type == 'future' else 'spot'
                }
            })
            
            # 加载市场数据
            await self.exchange.load_markets()
            self.logger.info(f"✅ 交易所初始化成功: {exchange_id} {market_type}")
            
        except Exception as e:
            self.logger.error(f"❌ 交易所初始化失败: {e}")
            raise
            
    async def fetch_ohlcv(self, timeframe: str = '5m', limit: int = 100) -> pd.DataFrame:
        """获取 K 线数据"""
        try:
            ohlcv = await self.exchange.fetch_ohlcv(self.symbol, timeframe, limit=limit)
            df = pd.DataFrame(ohlcv, columns=['timestamp', 'open', 'high', 'low', 'close', 'volume'])
            df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
            return df
        except Exception as e:
            self.logger.error(f"获取 K 线失败: {e}")
            raise
            
    def calculate_anchor(self, df: pd.DataFrame) -> float:
        """计算中轴价格 (布林带中轨)"""
        method = self.config['anchor']['method']
        
        if method == 'bb_middle':
            bb_period = self.config['anchor']['bb_period']
            bb_std = self.config['anchor']['bb_std']
            
            bb = BollingerBands(df['close'], window=bb_period, window_dev=bb_std)
            anchor = bb.bollinger_mavg().iloc[-1]
        else:
            # 使用最新价
            anchor = df['close'].iloc[-1]
            
        return float(anchor)
        
    def calculate_dynamic_spacing(self, df: pd.DataFrame) -> float:
        """计算动态网格间距"""
        base_spacing = self.config['grid']['base_spacing']
        
        if not self.config['grid']['dynamic_spacing']['enabled']:
            return base_spacing
            
        # 计算 ADX
        adx_period = 14
        if len(df) >= adx_period * 2:
            adx = ADXIndicator(df['high'], df['low'], df['close'], window=adx_period)
            adx_value = adx.adx().iloc[-1]
            
            # ADX 越高，间距越大
            adx_multiplier = self.config['grid']['dynamic_spacing']['adx_multiplier']
            spacing = base_spacing * (1 + (adx_value / 100) * adx_multiplier)
        else:
            spacing = base_spacing
            
        # 计算 Bollinger Band 宽度影响
        bb_period = self.config['anchor']['bb_period']
        if len(df) >= bb_period:
            bb = BollingerBands(df['close'], window=bb_period)
            bb_width = (bb.bollinger_hband() - bb.bollinger_lband()) / bb.bollinger_mavg()
            bb_factor = self.config['grid']['dynamic_spacing']['bb_width_factor']
            spacing *= (1 + bb_width.iloc[-1] * bb_factor)
            
        # 最小间距限制
        min_spacing = self.config['grid']['dynamic_spacing']['min_spacing']
        return max(spacing, min_spacing)
        
    def generate_grid_levels(self, anchor: float, spacing: float) -> List[GridLevel]:
        """生成网格层级"""
        grid_count = self.config['grid']['grid_count']
        amount_per_grid = self.config['grid']['amount_per_grid']
        
        levels = []
        
        # 上方网格 (卖单)
        for i in range(1, grid_count + 1):
            price = anchor * (1 + spacing * i)
            levels.append(GridLevel(
                level=i,
                price=price,
                side='sell',
                amount=amount_per_grid
            ))
            
        # 下方网格 (买单)
        for i in range(1, grid_count + 1):
            price = anchor * (1 - spacing * i)
            levels.append(GridLevel(
                level=-i,
                price=price,
                side='buy',
                amount=amount_per_grid
            ))
            
        return sorted(levels, key=lambda x: x.price)
        
    async def place_order(self, side: str, amount: float, price: Optional[float] = None) -> dict:
        """下单"""
        try:
            order_type = 'limit' if price else 'market'
            
            if side == 'buy':
                order = await self.exchange.create_limit_buy_order(
                    self.symbol, amount, price
                ) if price else await self.exchange.create_market_buy_order(
                    self.symbol, amount
                )
            else:
                order = await self.exchange.create_limit_sell_order(
                    self.symbol, amount, price
                ) if price else await self.exchange.create_market_sell_order(
                    self.symbol, amount
                )
                
            self.logger.info(f"✅ 下单成功: {side} {amount} @ {price or 'market'}")
            self.consecutive_errors = 0  # 重置错误计数
            return order
            
        except Exception as e:
            self.logger.error(f"❌ 下单失败: {e}")
            self.consecutive_errors += 1
            raise
            
    async def cancel_order(self, order_id: str) -> bool:
        """撤单"""
        try:
            await self.exchange.cancel_order(order_id, self.symbol)
            self.logger.info(f"✅ 撤单成功: {order_id}")
            return True
        except Exception as e:
            self.logger.error(f"❌ 撤单失败: {e}")
            return False
            
    async def update_position(self):
        """更新持仓信息"""
        try:
            balance = await self.exchange.fetch_balance()
            
            # 获取标的资产 (ETH)
            base_asset = self.symbol.split('/')[0]
            quote_asset = self.symbol.split('/')[1]
            
            base_balance = balance.get(base_asset, {}).get('free', 0)
            quote_balance = balance.get(quote_asset, {}).get('free', 0)
            
            # 更新持仓
            self.position.quantity = base_balance
            
            # 获取当前价格计算未实现盈亏
            ticker = await self.exchange.fetch_ticker(self.symbol)
            self.current_price = ticker['last']
            
            if self.position.avg_price > 0 and self.position.quantity > 0:
                self.position.unrealized_pnl = (
                    self.current_price - self.position.avg_price
                ) * self.position.quantity
                
            self.logger.debug(f"持仓更新: {base_balance} {base_asset}, "
                            f"未实现盈亏: {self.position.unrealized_pnl:.2f}")
                            
        except Exception as e:
            self.logger.error(f"更新持仓失败: {e}")
            
    async def check_circuit_breaker(self) -> bool:
        """检查熔断条件"""
        if self.cooldown_until and datetime.now() < self.cooldown_until:
            return True
            
        # 连续错误熔断
        max_errors = self.config['risk_management']['circuit_breaker']['max_consecutive_errors']
        if self.consecutive_errors >= max_errors:
            self.logger.warning(f"🚨 连续错误达到 {max_errors} 次，触发熔断")
            self.activate_circuit_breaker()
            return True
            
        return False
        
    def activate_circuit_breaker(self):
        """激活熔断"""
        self.circuit_breaker_active = True
        cooldown = self.config['risk_management']['circuit_breaker']['cooldown_seconds']
        self.cooldown_until = datetime.now().timestamp() + cooldown
        self.logger.warning(f"🔒 熔断激活，冷却时间: {cooldown}秒")
        
    async def run(self):
        """主循环"""
        self.logger.info("🚀 网格交易机器人启动")
        
        await self.initialize()
        
        while True:
            try:
                # 检查熔断
                if await self.check_circuit_breaker():
                    await asyncio.sleep(60)
                    continue
                    
                # 获取行情数据
                df = await self.fetch_ohlcv()
                
                # 计算中轴和间距
                self.anchor_price = self.calculate_anchor(df)
                spacing = self.calculate_dynamic_spacing(df)
                
                # 生成网格
                self.grid_levels = self.generate_grid_levels(self.anchor_price, spacing)
                
                # 更新持仓
                await self.update_position()
                
                # 检查并执行网格交易
                await self.execute_grid_strategy()
                
                # 等待下一次循环
                await asyncio.sleep(10)
                
            except Exception as e:
                self.logger.error(f"主循环错误: {e}")
                await asyncio.sleep(30)
                
    async def execute_grid_strategy(self):
        """执行网格策略（子类实现）"""
        # 基础框架，具体策略在子类实现
        pass
        
    async def close(self):
        """关闭连接"""
        if self.exchange:
            await self.exchange.close()
            self.logger.info("👋 交易所连接已关闭")


if __name__ == "__main__":
    import os
    
    # 测试运行
    async def test():
        trader = GridTrader()
        await trader.initialize()
        
        # 获取行情测试
        df = await trader.fetch_ohlcv()
        print(f"✅ 获取 K 线成功: {len(df)} 条")
        
        anchor = trader.calculate_anchor(df)
        spacing = trader.calculate_dynamic_spacing(df)
        print(f"📊 中轴价格: {anchor:.2f}, 动态间距: {spacing:.4f}")
        
        grid = trader.generate_grid_levels(anchor, spacing)
        print(f"📈 生成网格: {len(grid)} 层")
        print(f"   最高卖价: {max([g.price for g in grid if g.side == 'sell']):.2f}")
        print(f"   最低买价: {min([g.price for g in grid if g.side == 'buy']):.2f}")
        
        await trader.close()
        
    asyncio.run(test())
