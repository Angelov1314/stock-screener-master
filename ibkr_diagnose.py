#!/usr/bin/env python3
"""
IBKR TWS 连接测试 - 修复版
添加诊断信息和错误处理
"""

from ib_insync import IB, Stock, util
from datetime import datetime
import sys

TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 1

def check_market_hours():
    """检查美股交易时间"""
    now = datetime.now()
    weekday = now.weekday()
    hour = now.hour
    
    # 美股时间 (EST/EDT) 粗略判断
    if weekday >= 5:  # 周六日
        return False, "周末休市"
    return True, "工作日"

def main():
    ib = IB()
    
    try:
        print(f"🔗 连接 TWS {TWS_HOST}:{TWS_PORT} ...")
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID)
        print("✅ TWS 连接成功！")
        
        # 连接信息
        print(f"\n📡 连接详情:")
        print(f"   服务器版本: {ib.client.serverVersion()}")
        print(f"   连接时间: {ib.client.connectTime}")
        
        # 账户
        accounts = ib.managedAccounts()
        print(f"\n💰 账户: {accounts}")
        
        if not accounts:
            print("⚠️ 未获取到账户信息")
        
        # 检查市场状态
        is_open, reason = check_market_hours()
        print(f"\n🏦 市场状态: {reason}")
        
        # === 测试 AAPL ===
        print("\n📈 测试 AAPL 合约...")
        aapl = Stock('AAPL', 'SMART', 'USD')
        
        # 验证合约
        qualified = ib.qualifyContracts(aapl)
        if not qualified:
            print("❌ 合约验证失败！")
            return
        
        print(f"✅ 合约验证成功: {aapl.conId}")
        print(f"   交易所: {aapl.exchange}")
        print(f"   货币: {aapl.currency}")
        
        # 请求市场数据
        print("\n⏳ 请求市场数据 (等待3秒)...")
        ticker = ib.reqMktData(aapl, '', False, False)
        ib.sleep(3)
        
        # 检查结果
        print(f"\n📊 AAPL 数据:")
        print(f"   合约状态: {ticker.contract}")
        print(f"   市场数据类型: {ticker.marketDataType}")
        print(f"   时间: {ticker.time}")
        print(f"   买价 (Bid): {ticker.bid if ticker.bid else '无数据'}")
        print(f"   卖价 (Ask): {ticker.ask if ticker.ask else '无数据'}")
        print(f"   最后价 (Last): {ticker.last if ticker.last else '无数据'}")
        print(f"   成交量: {ticker.volume if ticker.volume else '无数据'}")
        
        # 诊断
        if ticker.bid is None and ticker.ask is None and ticker.last is None:
            print("\n⚠️ 警告: 所有价格数据为空！")
            print("\n可能原因:")
            print("   1. 美股已收盘 (当前北京时间)")
            print("   2. 没有实时数据订阅 (Delayed Data)")
            print("   3. TWS 市场数据权限未开启")
            print("\n尝试获取延迟数据...")
            
            # 尝试请求延迟数据
            ib.reqMarketDataType(3)  # 3 = Delayed
            ib.sleep(2)
            
            ticker_delayed = ib.reqMktData(aapl, '', False, False)
            ib.sleep(2)
            
            print(f"\n📊 延迟数据 (Delayed):")
            print(f"   买价 (Bid): {ticker_delayed.bid if ticker_delayed.bid else '无'}")
            print(f"   卖价 (Ask): {ticker_delayed.ask if ticker_delayed.ask else '无'}")
            print(f"   最后价 (Last): {ticker_delayed.last if ticker_delayed.last else '无'}")
            
            ib.reqMarketDataType(1)  # 恢复实时
        else:
            print("\n✅ 市场数据正常！")
        
        ib.cancelMktData(aapl)
        
        # === 尝试获取历史数据 ===
        print("\n📜 测试获取历史数据...")
        try:
            bars = ib.reqHistoricalData(
                aapl,
                endDateTime='',
                durationStr='1 D',
                barSizeSetting='1 hour',
                whatToShow='TRADES',
                useRTH=True
            )
            if bars:
                print(f"✅ 历史数据获取成功，共 {len(bars)} 条")
                df = util.df(bars)
                if df is not None and not df.empty:
                    print(df[['date', 'open', 'high', 'low', 'close', 'volume']].tail(3))
            else:
                print("⚠️ 历史数据为空（可能没有数据订阅）")
        except Exception as e:
            print(f"❌ 历史数据失败: {e}")
        
        print("\n🎉 测试完成！")
        
    except ConnectionRefusedError:
        print(f"\n❌ 连接被拒绝")
        print("请检查 TWS 是否已启动，API 是否启用，端口是否为 7496")
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()
    finally:
        if ib.isConnected():
            ib.disconnect()
            print("👋 已断开连接")

if __name__ == '__main__':
    main()
