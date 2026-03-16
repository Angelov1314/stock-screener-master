#!/usr/bin/env python3
"""
Test Suite - 测试脚本集合
验证: API连接、风控模块、网格逻辑
"""

import asyncio
import os
import sys
from datetime import datetime

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from grid_trader import GridTrader
from risk_manager import RiskManager, RiskCheckResult
import yaml


class TestSuite:
    """测试套件"""
    
    def __init__(self):
        self.results = []
        
    def log(self, message: str, level: str = "INFO"):
        """记录测试日志"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] [{level}] {message}")
        
    def assert_true(self, condition: bool, message: str) -> bool:
        """断言测试"""
        if condition:
            self.log(f"✅ {message}")
            self.results.append((message, True))
            return True
        else:
            self.log(f"❌ {message}", "ERROR")
            self.results.append((message, False))
            return False
            
    def print_summary(self):
        """打印测试摘要"""
        total = len(self.results)
        passed = sum(1 for _, result in self.results if result)
        failed = total - passed
        
        print("\n" + "="*50)
        print(f"测试完成: 总计 {total} | 通过 {passed} | 失败 {failed}")
        print("="*50)
        
        if failed > 0:
            print("\n失败的测试:")
            for name, result in self.results:
                if not result:
                    print(f"  - {name}")
                    
    # ═══════════════════════════════════════════
    # API 连接测试
    # ═══════════════════════════════════════════
    
    async def test_api_connection(self):
        """测试 API 连接"""
        self.log("\n📡 测试 API 连接...")
        
        # 检查环境变量
        has_key = self.assert_true(
            os.getenv('BINANCE_API_KEY') is not None,
            "BINANCE_API_KEY 环境变量已设置"
        )
        
        has_secret = self.assert_true(
            os.getenv('BINANCE_SECRET_KEY') is not None,
            "BINANCE_SECRET_KEY 环境变量已设置"
        )
        
        if not (has_key and has_secret):
            self.log("⚠️ 缺少 API Key，跳过连接测试", "WARNING")
            return
            
        try:
            trader = GridTrader()
            await trader.initialize()
            
            self.assert_true(
                trader.exchange is not None,
                "交易所实例创建成功"
            )
            
            # 测试获取余额
            balance = await trader.exchange.fetch_balance()
            usdt_balance = balance.get('USDT', {}).get('free', 0)
            
            self.log(f"💰 当前 USDT 余额: {usdt_balance}")
            self.assert_true(
                usdt_balance >= 0,
                "成功获取账户余额"
            )
            
            # 测试获取行情
            ticker = await trader.exchange.fetch_ticker('ETH/USDT')
            self.log(f"📊 ETH 当前价格: {ticker['last']}")
            
            self.assert_true(
                ticker['last'] > 0,
                "成功获取行情数据"
            )
            
            await trader.close()
            
        except Exception as e:
            self.assert_true(False, f"API 连接测试失败: {e}")
            
    # ═══════════════════════════════════════════
    # 网格逻辑测试
    # ═══════════════════════════════════════════
    
    async def test_grid_logic(self):
        """测试网格逻辑"""
        self.log("\n📊 测试网格逻辑...")
        
        try:
            trader = GridTrader()
            
            # 测试获取 K 线
            df = await trader.fetch_ohlcv(limit=50)
            
            self.assert_true(
                len(df) > 0,
                f"成功获取 K 线数据 ({len(df)} 条)"
            )
            
            # 测试中轴计算
            anchor = trader.calculate_anchor(df)
            self.log(f"🎯 计算中轴价格: {anchor:.2f}")
            
            self.assert_true(
                anchor > 0,
                "中轴价格计算正确"
            )
            
            # 测试动态间距
            spacing = trader.calculate_dynamic_spacing(df)
            self.log(f"📏 动态网格间距: {spacing:.4f} ({spacing*100:.2f}%)")
            
            self.assert_true(
                spacing > 0,
                "动态间距计算正确"
            )
            
            # 测试网格生成
            grid = trader.generate_grid_levels(anchor, spacing)
            
            buy_grids = [g for g in grid if g.side == 'buy']
            sell_grids = [g for g in grid if g.side == 'sell']
            
            self.log(f"📈 生成网格: 买入 {len(buy_grids)} 层, 卖出 {len(sell_grids)} 层")
            self.log(f"   价格区间: {min([g.price for g in grid]):.2f} - {max([g.price for g in grid]):.2f}")
            
            self.assert_true(
                len(grid) > 0,
                "网格层级生成正确"
            )
            
            self.assert_true(
                len(buy_grids) == len(sell_grids),
                "买卖网格对称"
            )
            
        except Exception as e:
            self.assert_true(False, f"网格逻辑测试失败: {e}")
            
    # ═══════════════════════════════════════════
    # 风控模块测试
    # ═══════════════════════════════════════════
    
    async def test_risk_management(self):
        """测试风控模块"""
        self.log("\n🛡️ 测试风控模块...")
        
        try:
            rm = RiskManager()
            
            # 测试仓位限制
            result = rm.check_position_limits(400, 1000, 3, 'long')
            self.assert_true(
                result.passed,
                f"仓位限制检查: {result.reason or '通过'}"
            )
            
            # 测试超仓位
            result = rm.check_position_limits(600, 1000, 6, 'long')
            self.assert_true(
                not result.passed,
                f"超仓位检测正确: {result.reason}"
            )
            
            # 测试止损
            rm.initial_balance = 1000
            rm.peak_balance = 1000
            
            result = rm.check_stop_loss(950, [])
            self.assert_true(
                result.passed,
                f"正常回撤检查通过 (回撤: {rm.current_drawdown:.1%})"
            )
            
            # 测试触发止损
            result = rm.check_stop_loss(940, [])
            self.assert_true(
                not result.passed,
                f"5% 止损触发正确: {result.reason}"
            )
            
            # 测试熔断
            for i in range(5):
                result = rm.check_circuit_breaker(error_occurred=True)
                
            self.assert_true(
                not result.passed,
                f"连续错误熔断触发: {result.reason}"
            )
            
            self.assert_true(
                rm.circuit_breaker_active,
                "熔断状态正确"
            )
            
            # 测试 API 限流
            for i in range(10):
                result = await rm.rate_limit_check()
                
            self.assert_true(
                rm.request_count == 10,
                f"API 请求计数正确: {rm.request_count}"
            )
            
            self.log(f"📊 风控状态: {rm.get_status()}")
            
        except Exception as e:
            self.assert_true(False, f"风控模块测试失败: {e}")
            
    # ═══════════════════════════════════════════
    # 配置文件测试
    # ═══════════════════════════════════════════
    
    async def test_config(self):
        """测试配置文件"""
        self.log("\n⚙️ 测试配置文件...")
        
        try:
            with open('config.yaml', 'r') as f:
                config = yaml.safe_load(f)
                
            required_sections = [
                'trading', 'grid', 'anchor', 'risk_management', 'runtime'
            ]
            
            for section in required_sections:
                self.assert_true(
                    section in config,
                    f"配置节 [{section}] 存在"
                )
                
            self.log(f"📋 交易对: {config['trading']['symbol']}")
            self.log(f"📏 网格数: {config['grid']['grid_count']}")
            self.log(f"💰 每格金额: {config['grid']['amount_per_grid']} USDT")
            self.log(f"🛡️ 最大仓位: {config['risk_management']['position_limits']['max_position_ratio']:.0%}")
            
        except Exception as e:
            self.assert_true(False, f"配置文件测试失败: {e}")
            
    # ═══════════════════════════════════════════
    # 运行所有测试
    # ═══════════════════════════════════════════
    
    async def run_all(self):
        """运行全部测试"""
        self.log("="*50)
        self.log("🧪 开始网格交易机器人测试套件")
        self.log("="*50)
        
        await self.test_config()
        await self.test_api_connection()
        await self.test_grid_logic()
        await self.test_risk_management()
        
        self.print_summary()


if __name__ == "__main__":
    test_suite = TestSuite()
    asyncio.run(test_suite.run_all())
