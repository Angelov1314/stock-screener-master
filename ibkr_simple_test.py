#!/usr/bin/env python3
"""
IBKR TWS 连接测试 - 同步版本（更简单）
"""

from ib_insync import IB, Stock

# 配置
TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 1

def main():
    ib = IB()
    
    try:
        print(f"🔗 连接 TWS {TWS_HOST}:{TWS_PORT} ...")
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID)
        
        print("\n✅ 连接成功！")
        print(f"   服务器版本: {ib.client.serverVersion()}")
        print(f"   连接时间: {ib.client.connectTime}")
        
        # 账户信息
        accounts = ib.managedAccounts()
        print(f"\n💰 账户: {accounts}")
        
        # AAPL 报价
        aapl = Stock('AAPL', 'SMART', 'USD')
        ib.qualifyContracts(aapl)
        
        ticker = ib.reqMktData(aapl)
        ib.sleep(2)
        
        print(f"\n📈 AAPL 实时报价:")
        print(f"   买价 (Bid): ${ticker.bid}")
        print(f"   卖价 (Ask): ${ticker.ask}")
        print(f"   最后价: ${ticker.last}")
        
        ib.cancelMktData(aapl)
        print("\n🎉 测试完成！")
        
    except Exception as e:
        print(f"\n❌ 连接失败: {e}")
        print("\n请检查:")
        print("   1. TWS 是否已启动？")
        print("   2. Edit → Configuration → API → Enable ActiveX/Socket clients")
        print("   3. Port 是否设为 7496？")
    finally:
        ib.disconnect()

if __name__ == '__main__':
    main()
