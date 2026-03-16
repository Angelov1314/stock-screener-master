#!/usr/bin/env python3
"""
检查 IBKR 市场数据延迟情况
"""

from ib_insync import IB, Stock
import time

TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 13

def main():
    ib = IB()
    
    try:
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID, timeout=10)
        print("✅ 已连接 TWS\n")
        
        # 检查当前市场数据类型设置
        print("📊 当前市场数据类型:")
        print("   1 = 实时 (Live)")
        print("   2 = 冻结 (Frozen)")
        print("   3 = 延迟 (Delayed)")
        print("   4 = 延迟冻结 (Delayed Frozen)")
        
        # 测试 AAPL - 先请求实时
        aapl = Stock('AAPL', 'SMART', 'USD')
        ib.qualifyContracts(aapl)
        
        print("\n🔴 测试 1: 实时数据 (Market Data Type 1)")
        ib.reqMarketDataType(1)  # 实时
        ticker_live = ib.reqMktData(aapl)
        ib.sleep(2)
        
        print(f"   数据时间: {ticker_live.time}")
        print(f"   最后价: ${ticker_live.last}")
        print(f"   延迟状态: {'实时' if ticker_live.time else '无数据'}")
        
        ib.cancelMktData(aapl)
        
        # 测试延迟数据
        print("\n🟡 测试 2: 延迟数据 (Market Data Type 3)")
        ib.reqMarketDataType(3)  # 延迟
        ticker_delayed = ib.reqMktData(aapl)
        ib.sleep(2)
        
        print(f"   数据时间: {ticker_delayed.time}")
        print(f"   最后价: ${ticker_delayed.last}")
        
        ib.cancelMktData(aapl)
        
        # 检查 AMD 数据
        print("\n🔵 检查 AMD 数据:")
        amd = Stock('AMD', 'SMART', 'USD')
        ib.qualifyContracts(amd)
        
        ib.reqMarketDataType(1)  # 切回实时
        ticker_amd = ib.reqMktData(amd)
        ib.sleep(2)
        
        print(f"   数据时间: {ticker_amd.time}")
        print(f"   当前价: ${ticker_amd.last}")
        print(f"   买价: ${ticker_amd.bid}")
        print(f"   卖价: ${ticker_amd.ask}")
        
        # 判断是否有实时数据订阅
        print("\n📋 数据订阅状态判断:")
        if ticker_live.last and ticker_live.time:
            delay_seconds = (time.time() - ticker_live.time.timestamp()) if ticker_live.time else None
            if delay_seconds and delay_seconds < 5:
                print("   ✅ 有实时数据订阅 (延迟 < 5秒)")
            else:
                print(f"   ⚠️ 数据延迟: {delay_seconds:.0f}秒")
        else:
            print("   ⚠️ 无实时数据，可能在使用延迟数据")
            print("   延迟数据通常延迟: 15-20分钟")
        
        ib.cancelMktData(amd)
        
        # 恢复实时模式
        ib.reqMarketDataType(1)
        
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()
    finally:
        ib.disconnect()
        print("\n👋 已断开")

if __name__ == '__main__':
    main()
