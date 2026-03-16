#!/usr/bin/env python3
"""
Grid Trading Bot - 主入口
整合: 行情连接 + 网格策略 + 风控模块
"""

import os
import asyncio
import signal
import sys
from datetime import datetime
import logging

# 导入模块
from grid_trader import GridTrader
from risk_manager import RiskManager, RiskCheckResult


class GridTradingBot(GridTrader):
    """完整的网格交易机器人"""
    
    def __init__(self, config_path: str = "config.yaml"):
        super().__init__(config_path)
        
        # 初始化风控
        self.risk_manager = RiskManager(self.config)
        
        # 运行状态
        self.running = False
        self.request_count = 0
        self.request_window_start = datetime.now()
        
        # 统计
        self.trade_count = 0
        self.profit_total = 0.0
        
        # 设置信号处理
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
        
    def signal_handler(self, signum, frame):
        """信号处理 - 优雅退出"""
        self.logger.info(f"\n🛑 接收到信号 {signum}, 正在优雅退出...")
        self.running = False
        
    async def check_rate_limit(self):
        """检查 API 限流"""
        result = self.risk_manager.check_rate_limit(
            self.request_count, 
            self.request_window_start
        )
        
        if not result.passed:
            self.logger.warning(f"⏳ API 限流: {result.reason}")
            await asyncio.sleep(result.cooldown_seconds)
            
            # 重置窗口
            self.request_count = 0
            self.request_window_start = datetime.now()
            
        self.request_count += 1
        
    async def execute_grid_strategy(self):
        """执行网格策略（完整版）"""
        # 1. 更新持仓
        await self.update_position()
        
        # 2. 风控检查
        context = {
            'position_ratio': abs(self.position.quantity * self.current_price / self.initial_balance) if self.initial_balance > 0 else 0,
            'current_balance': self.initial_balance + self.position.unrealized_pnl,
            'current_price': self.current_price,
            'request_count': self.request_count,
            'window_start': self.request_window_start
        }
        
        risk_result = await self.risk_manager.full_risk_check(context)
        if not risk_result.passed:
            self.logger.warning(f"🚫 风控拦截: {risk_result.reason}")
            if risk_result.action == "清仓止损":
                await self.emergency_close_all()
            return
            
        # 3. 检查现有订单
        try:
            await self.check_rate_limit()
            open_orders = await self.exchange.fetch_open_orders(self.symbol)
            
            # 取消偏离中轴太远的订单
            for order in open_orders:
                order_price = float(order['price'])
                if abs(order_price - self.anchor_price) / self.anchor_price > 0.1:  # 偏离10%
                    self.logger.info(f"🔄 取消偏离订单: {order['id']} @ {order_price}")
                    await self.cancel_order(order['id'])
                    
        except Exception as e:
            self.logger.error(f"查询订单失败: {e}")
            self.risk_manager.record_error(e)
            return
            
        # 4. 检查网格成交情况并下单
        for level in self.grid_levels:
            try:
                # 买单逻辑
                if level.side == 'buy' and self.current_price <= level.price:
                    # 检查仓位限制
                    position_check = self.risk_manager.check_position_limit(
                        context['position_ratio'] + (level.amount * level.price / self.initial_balance)
                    )
                    if not position_check.passed:
                        self.logger.warning(f"⚠️ 跳过买单 (仓位限制): {level.price:.2f}")
                        continue
                        
                    # 检查网格层数
                    if self.position.layers >= self.config['risk_management']['position_limits']['max_long_layers']:
                        self.logger.warning(f"⚠️ 已达最大多单层数: {self.position.layers}")
                        continue
                        
                    await self.check_rate_limit()
                    order = await self.place_order('buy', level.amount, level.price)
                    level.order_id = order['id']
                    self.position.layers += 1
                    self.trade_count += 1
                    
                # 卖单逻辑
                elif level.side == 'sell' and self.current_price >= level.price:
                    # 检查是否有持仓可卖
                    if self.position.quantity < level.amount:
                        continue
                        
                    # 检查单笔网格止损
                    if self.position.avg_price > 0:
                        stop_check = self.risk_manager.check_grid_stop_loss(
                            self.position.avg_price, 
                            self.current_price,
                            'long'
                        )
                        if not stop_check.passed:
                            self.logger.warning(f"🛑 网格止损触发: {stop_check.reason}")
                            await self.emergency_close_all()
                            return
                            
                    await self.check_rate_limit()
                    order = await self.place_order('sell', level.amount, level.price)
                    level.order_id = order['id']
                    self.position.layers = max(0, self.position.layers - 1)
                    self.trade_count += 1
                    
                    # 计算收益
                    profit = (level.price - self.position.avg_price) * level.amount
                    self.profit_total += profit
                    
            except Exception as e:
                self.logger.error(f"网格下单失败: {e}")
                self.risk_manager.record_error(e)
                
    async def emergency_close_all(self):
        """紧急平仓"""
        self.logger.warning("🚨 执行紧急平仓!")
        
        try:
            # 取消所有未成交订单
            await self.check_rate_limit()
            open_orders = await self.exchange.fetch_open_orders(self.symbol)
            for order in open_orders:
                await self.cancel_order(order['id'])
                
            # 卖出全部持仓
            if self.position.quantity > 0:
                await self.check_rate_limit()
                await self.place_order('sell', self.position.quantity)
                
            self.logger.info("✅ 紧急平仓完成")
            
        except Exception as e:
            self.logger.error(f"紧急平仓失败: {e}")
            
    async def print_status(self):
        """打印状态"""
        risk_status = self.risk_manager.get_status()
        
        self.logger.info("\n" + "=" * 50)
        self.logger.info("📊 运行状态")
        self.logger.info("=" * 50)
        self.logger.info(f"当前价格: {self.current_price:.2f} USDT")
        self.logger.info(f"中轴价格: {self.anchor_price:.2f} USDT")
        self.logger.info(f"持仓数量: {self.position.quantity:.6f} ETH")
        self.logger.info(f"持仓均价: {self.position.avg_price:.2f} USDT")
        self.logger.info(f"未实现盈亏: {self.position.unrealized_pnl:.2f} USDT")
        self.logger.info(f"累计成交: {self.trade_count} 笔")
        self.logger.info(f"累计收益: {self.profit_total:.2f} USDT")
        self.logger.info(f"熔断状态: {'激活' if risk_status['circuit_breaker_active'] else '正常'}")
        if risk_status['circuit_breaker_active']:
            self.logger.info(f"  原因: {risk_status['circuit_breaker_reason']}")
        self.logger.info("=" * 50)
        
    async def run(self):
        """主循环"""
        self.logger.info("🚀 网格交易机器人启动")
        self.running = True
        
        # 初始化
        await self.initialize()
        await self.risk_manager.initialize(self.exchange, self.symbol)
        
        # 获取初始资金
        balance = await self.exchange.fetch_balance()
        quote_asset = self.symbol.split('/')[1]
        self.initial_balance = balance.get(quote_asset, {}).get('total', 0)
        
        self.logger.info(f"💰 初始资金: {self.initial_balance} {quote_asset}")
        self.logger.info(f"📈 交易对: {self.symbol}")
        
        # 主循环
        loop_count = 0
        status_interval = self.config['runtime'].get('heartbeat_interval', 60) // 10
        
        while self.running:
            try:
                loop_count += 1
                
                # 1. 检查熔断
                circuit_check = self.risk_manager.check_circuit_breaker()
                if not circuit_check.passed:
                    self.logger.warning(f"⏳ {circuit_check.reason}")
                    await asyncio.sleep(60)
                    continue
                    
                # 2. 获取行情
                df = await self.fetch_ohlcv()
                
                # 3. 计算网格
                self.anchor_price = self.calculate_anchor(df)
                spacing = self.calculate_dynamic_spacing(df)
                self.grid_levels = self.generate_grid_levels(self.anchor_price, spacing)
                
                # 4. 执行策略
                await self.execute_grid_strategy()
                
                # 5. 定期打印状态
                if loop_count % status_interval == 0:
                    await self.print_status()
                    
                # 6. 等待下一轮
                await asyncio.sleep(10)
                
            except Exception as e:
                self.logger.error(f"主循环错误: {e}")
                self.risk_manager.record_error(e)
                await asyncio.sleep(30)
                
        # 优雅退出
        await self.close()
        await self.print_status()
        self.logger.info("👋 机器人已停止")


async def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Grid Trading Bot')
    parser.add_argument('--config', '-c', default='config.yaml', help='配置文件路径')
    parser.add_argument('--test', '-t', action='store_true', help='测试模式（不交易）')
    args = parser.parse_args()
    
    # 检查环境变量
    if not os.getenv('BINANCE_API_KEY') or not os.getenv('BINANCE_SECRET_KEY'):
        print("❌ 请设置环境变量: BINANCE_API_KEY 和 BINANCE_SECRET_KEY")
        sys.exit(1)
        
    # 创建日志目录
    os.makedirs('logs', exist_ok=True)
    
    # 启动机器人
    bot = GridTradingBot(args.config)
    
    try:
        if args.test:
            print("🧪 测试模式 - 只连接不交易")
            await bot.initialize()
            print("✅ 连接成功!")
            await bot.close()
        else:
            await bot.run()
    except KeyboardInterrupt:
        print("\n👋 用户中断")
    except Exception as e:
        print(f"\n💥 错误: {e}")
        

if __name__ == "__main__":
    # 使用方式:
    # python3 main.py              # 正常运行
    # python3 main.py --test       # 测试连接
    # python3 main.py -c config_custom.yaml  # 使用自定义配置
    asyncio.run(main())
