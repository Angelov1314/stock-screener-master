#!/usr/bin/env python3
"""
测试脚本 - 验证 API 连接和基础功能
"""

import os
import asyncio
import logging
import ccxt.async_support as ccxt

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BinanceAPITest:
    """Binance API 测试类"""
    
    def __init__(self):
        self.api_key = os.getenv('BINANCE_API_KEY')
        self.api_secret = os.getenv('BINANCE_SECRET_KEY')
        self.exchange = None
        
    async def initialize(self):
        """初始化连接"""
        if not self.api_key or not self.api_secret:
            raise ValueError("请设置 BINANCE_API_KEY 和 BINANCE_SECRET_KEY 环境变量")
            
        self.exchange = ccxt.binance({
            'apiKey': self.api_key,
            'secret': self.api_secret,
            'enableRateLimit': True
        })
        
    async def test_connection(self):
        """测试连接"""
        try:
            await self.exchange.load_markets()
            logger.info("✅ API 连接成功")
            return True
        except Exception as e:
            logger.error(f"❌ API 连接失败: {e}")
            return False
            
    async def test_balance(self):
        """测试查询余额"""
        try:
            balance = await self.exchange.fetch_balance()
            usdt = balance.get('USDT', {})
            eth = balance.get('ETH', {})
            
            logger.info(f"💰 USDT 余额: 可用 {usdt.get('free', 0):.2f}, 冻结 {usdt.get('used', 0):.2f}, 总计 {usdt.get('total', 0):.2f}")
            logger.info(f"💰 ETH 余额: 可用 {eth.get('free', 0):.6f}, 冻结 {eth.get('used', 0):.6f}, 总计 {eth.get('total', 0):.6f}")
            return True
        except Exception as e:
            logger.error(f"❌ 查询余额失败: {e}")
            return False
            
    async def test_ticker(self):
        """测试获取行情"""
        try:
            ticker = await self.exchange.fetch_ticker('ETH/USDT')
            logger.info(f"📊 ETH/USDT 行情:")
            logger.info(f"   最新价: {ticker['last']:.2f}")
            logger.info(f"   买一: {ticker['bid']:.2f}")
            logger.info(f"   卖一: {ticker['ask']:.2f}")
            logger.info(f"   24h 涨跌: {ticker['percentage']:.2f}%")
            logger.info(f"   24h 成交量: {ticker['quoteVolume']:.2f} USDT")
            return True
        except Exception as e:
            logger.error(f"❌ 获取行情失败: {e}")
            return False
            
    async def test_order_book(self):
        """测试获取订单簿"""
        try:
            orderbook = await self.exchange.fetch_order_book('ETH/USDT', limit=5)
            logger.info(f"📖 ETH/USDT 订单簿 (前5档):")
            logger.info("   卖盘:")
            for price, amount in orderbook['asks'][:5]:
                logger.info(f"      {price:.2f} | {amount:.4f}")
            logger.info("   买盘:")
            for price, amount in orderbook['bids'][:5]:
                logger.info(f"      {price:.2f} | {amount:.4f}")
            return True
        except Exception as e:
            logger.error(f"❌ 获取订单簿失败: {e}")
            return False
            
    async def test_ohlcv(self):
        """测试获取 K 线数据"""
        try:
            ohlcv = await self.exchange.fetch_ohlcv('ETH/USDT', '5m', limit=10)
            logger.info(f"📈 ETH/USDT 5分钟 K 线 (最近10根):")
            logger.info("   时间                | 开       | 高       | 低       | 收       | 成交量")
            for candle in ohlcv:
                timestamp = candle[0]
                open_p, high_p, low_p, close_p, volume = candle[1:]
                from datetime import datetime
                time_str = datetime.fromtimestamp(timestamp/1000).strftime('%Y-%m-%d %H:%M')
                logger.info(f"   {time_str} | {open_p:8.2f} | {high_p:8.2f} | {low_p:8.2f} | {close_p:8.2f} | {volume:.4f}")
            return True
        except Exception as e:
            logger.error(f"❌ 获取 K 线失败: {e}")
            return False
            
    async def test_small_trade(self, amount_usdt: float = 7.5):
        """测试小额交易（买入 -> 卖出）"""
        symbol = 'ETH/USDT'
        
        try:
            # 获取当前价格
            ticker = await self.exchange.fetch_ticker(symbol)
            current_price = ticker['last']
            
            # 计算买入数量
            eth_amount = round(amount_usdt / current_price, 6)
            
            logger.info(f"\n🛒 开始测试交易: 买入 {eth_amount} ETH (~{amount_usdt} USDT)")
            
            # 下单买入（市价单）
            buy_order = await self.exchange.create_market_buy_order(symbol, eth_amount)
            logger.info(f"✅ 买入成功:")
            logger.info(f"   订单 ID: {buy_order['id']}")
            logger.info(f"   成交价格: {buy_order['average']:.2f} USDT")
            logger.info(f"   成交数量: {buy_order['filled']:.6f} ETH")
            logger.info(f"   实际花费: {buy_order['cost']:.2f} USDT")
            
            # 等待成交确认
            await asyncio.sleep(2)
            
            # 查询新的 ETH 余额
            balance = await self.exchange.fetch_balance()
            eth_balance = balance.get('ETH', {}).get('free', 0)
            
            if eth_balance > 0:
                logger.info(f"\n💰 当前 ETH 余额: {eth_balance:.6f}")
                
                # 卖出全部 ETH
                logger.info(f"\n💸 开始卖出: {eth_balance} ETH")
                sell_order = await self.exchange.create_market_sell_order(symbol, eth_balance)
                
                logger.info(f"✅ 卖出成功:")
                logger.info(f"   订单 ID: {sell_order['id']}")
                logger.info(f"   成交价格: {sell_order['average']:.2f} USDT")
                logger.info(f"   成交数量: {sell_order['filled']:.6f} ETH")
                logger.info(f"   实际获得: {sell_order['cost']:.2f} USDT")
                
                # 计算盈亏
                pnl = float(sell_order['cost']) - float(buy_order['cost'])
                pnl_percent = (pnl / float(buy_order['cost'])) * 100
                
                logger.info(f"\n📊 交易结果:")
                logger.info(f"   买入成本: {buy_order['cost']:.2f} USDT")
                logger.info(f"   卖出收入: {sell_order['cost']:.2f} USDT")
                logger.info(f"   盈亏: {pnl:.4f} USDT ({pnl_percent:+.2f}%)")
                
                return True
            else:
                logger.warning("⚠️ ETH 余额为 0，可能买入未成交")
                return False
                
        except Exception as e:
            logger.error(f"❌ 交易测试失败: {e}")
            return False
            
    async def run_all_tests(self, include_trade: bool = False, trade_amount: float = 7.5):
        """运行全部测试"""
        logger.info("=" * 50)
        logger.info("🧪 Binance API 测试开始")
        logger.info("=" * 50)
        
        results = []
        
        # 1. 连接测试
        logger.info("\n[1/6] 测试 API 连接...")
        results.append(("连接", await self.test_connection()))
        
        # 2. 余额查询
        logger.info("\n[2/6] 测试查询余额...")
        results.append(("余额", await self.test_balance()))
        
        # 3. 行情获取
        logger.info("\n[3/6] 测试获取行情...")
        results.append(("行情", await self.test_ticker()))
        
        # 4. 订单簿
        logger.info("\n[4/6] 测试获取订单簿...")
        results.append(("订单簿", await self.test_order_book()))
        
        # 5. K 线数据
        logger.info("\n[5/6] 测试获取 K 线...")
        results.append(("K线", await self.test_ohlcv()))
        
        # 6. 交易测试（可选）
        if include_trade:
            logger.info(f"\n[6/6] 测试小额交易 ({trade_amount} USDT)...")
            results.append(("交易", await self.test_small_trade(trade_amount)))
        else:
            logger.info("\n[6/6] 跳过交易测试 (使用 --trade 参数启用)")
            results.append(("交易", None))
            
        # 汇总结果
        logger.info("\n" + "=" * 50)
        logger.info("📋 测试结果汇总")
        logger.info("=" * 50)
        
        for name, passed in results:
            status = "✅ 通过" if passed else ("⏭️ 跳过" if passed is None else "❌ 失败")
            logger.info(f"   {name}: {status}")
            
        passed_count = sum(1 for _, p in results if p)
        total_count = sum(1 for _, p in results if p is not None)
        
        logger.info(f"\n总计: {passed_count}/{total_count} 项通过")
        
        return all(p for _, p in results if p is not None)
        
    async def close(self):
        """关闭连接"""
        if self.exchange:
            await self.exchange.close()
            logger.info("\n👋 连接已关闭")


async def main():
    """主函数"""
    import sys
    
    # 解析参数
    include_trade = '--trade' in sys.argv
    trade_amount = 7.5
    
    # 可以指定金额: --trade 5.0
    if include_trade:
        try:
            idx = sys.argv.index('--trade')
            if idx + 1 < len(sys.argv) and sys.argv[idx + 1].replace('.', '').isdigit():
                trade_amount = float(sys.argv[idx + 1])
        except:
            pass
            
    tester = BinanceAPITest()
    
    try:
        await tester.initialize()
        success = await tester.run_all_tests(include_trade, trade_amount)
        
        if success:
            logger.info("\n🎉 所有测试通过! API 连接正常")
        else:
            logger.warning("\n⚠️ 部分测试未通过，请检查配置")
            
    except Exception as e:
        logger.error(f"\n💥 测试过程中出错: {e}")
    finally:
        await tester.close()


if __name__ == "__main__":
    # 使用方式:
    # python3 test_api.py              # 只测试连接，不交易
    # python3 test_api.py --trade      # 测试并执行 7.5 USDT 交易
    # python3 test_api.py --trade 5.0  # 测试并执行 5 USDT 交易
    asyncio.run(main())
