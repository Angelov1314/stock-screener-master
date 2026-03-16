#!/usr/bin/env python3
"""
IBKR TWS 连接测试 - 修复版
"""

from ib_insync import IB, Stock, util
from datetime import datetime
import sys

TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 1

def main():
    ib = IB()
    
    try:
        print(f"🔗 连接 TWS {TWS_HOST}:{TWS_PORT} ...")
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID, timeout=10)
        print("✅ TWS 连接成功！")
        
        print(f"\n📡 连接详情:")
        print(f"   服务器版本: {ib.client.serverVersion()}")
        
        # 账户
        accounts = ib.managedAccounts()
        print(f"\n💰 账户: {accounts}")
        
        # === 测试 AAPL ===
        print("\n📈 测试 AAPL 合约...")
        aapl = Stock('AAPL', 'SMART', 'USD')
        
        qualified = ib.qualifyContracts(aapl)
        if not qualified:
            print("❌ 合约验证失败！")
            return
        
        print(f"✅ 合约验证成功: {aapl.conId}")
        print(f"   交易所: {aapl.exchange}")
        
        # 请求市场数据
        print("\n⏳ 请求市场数据 (等待3秒)...")
        ticker = ib.reqMktData(aapl, '', False, False)
        ib.sleep(3)
        
        print(f"\n📊 AAPL 实时报价:")
        print(f"   买价 (Bid): ${ticker.bid if ticker.bid else '无数据'}")
        print(f"   卖价 (Ask): ${ticker.ask if ticker.ask else '无数据'}")
        print(f"   最后价 (Last): ${ticker.last if ticker.last else '无数据'}")
        print(f"   成交量: {ticker.volume if ticker.volume else '无数据'}")
        
        if ticker.bid is None and ticker.ask is None and ticker.last is None:
            print("\n⚠️ 警告: 所有价格数据为空（美股已收盘或没有订阅）")
        else:
            print("\n✅ 市场数据正常！")
        
        ib.cancelMktData(aapl)
        
        # === 历史数据 ===
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
                    print(df[['date', 'open', 'high', 'low', 'close']].tail(3).to_string())
            else:
                print("⚠️ 历史数据为空")
        except Exception as e:
            print(f"❌ 历史数据失败: {e}")
        
        print("\n🎉 所有测试完成！API 连接正常。")
        
    except Exception as e:
        print(f"\n❌ 错误: {e}")
    finally:
        if ib.isConnected():
            ib.disconnect()
            print("👋 已断开连接")

if __name__ == '__main__':
    main()
