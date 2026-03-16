#!/usr/bin/env python3
"""
IBKR TWS 连接测试 - 7496 端口（实盘）
使用前确保：
1. TWS 已启动并登录
2. TWS → Edit → Global Configuration → API → Settings 中启用 API
3. Socket port 设置为 7496
4. 允许连接此电脑
"""

import asyncio
import sys
from ib_insync import IB, Stock

# 配置
TWS_HOST = '127.0.0.1'  # 本机运行，如果是远程改IP
TWS_PORT = 7496         # 实盘端口（模拟账户用7497）
CLIENT_ID = 1           # 客户端ID，多连接时用不同数字

async def test_connection():
    """测试 TWS 连接"""
    ib = IB()
    
    try:
        print(f"🔗 正在连接 TWS {TWS_HOST}:{TWS_PORT} ...")
        await ib.connectAsync(TWS_HOST, TWS_PORT, clientId=CLIENT_ID)
        
        # 1. 获取连接信息
        print("\n✅ 连接成功！")
        print(f"   服务器版本: {ib.client.serverVersion()}")
        print(f"   连接时间: {ib.client.connectTime}")
        
        # 2. 获取账户信息
        accounts = ib.managedAccounts()
        print(f"\n💰 账户列表: {accounts}")
        
        if accounts:
            account = accounts[0]
            print(f"\n📊 获取账户 {account} 摘要...")
            
            # 请求账户摘要
            account_summary = ib.accountSummary(account)
            for item in account_summary:
                if item.tag in ['NetLiquidation', 'AvailableFunds', 'BuyingPower']:
                    print(f"   {item.tag}: {item.value} {item.currency}")
        
        # 3. 获取市场数据测试（AAPL）
        print("\n📈 测试获取市场数据 (AAPL)...")
        aapl = Stock('AAPL', 'SMART', 'USD')
        await ib.qualifyContractsAsync(aapl)
        
        # 获取快照报价
        tick = ib.reqMktData(aapl, '', False, False)
        await asyncio.sleep(2)  # 等待数据
        
        print(f"   合约: {aapl.symbol} @ {aapl.exchange}")
        print(f"   最后价: {tick.last if tick.last else 'N/A'}")
        print(f"   买价: {tick.bid if tick.bid else 'N/A'}")
        print(f"   卖价: {tick.ask if tick.ask else 'N/A'}")
        
        # 取消订阅
        ib.cancelMktData(aapl)
        
        print("\n🎉 所有测试通过！API 连接正常。")
        
    except ConnectionRefusedError:
        print(f"\n❌ 连接被拒绝 - 请检查:")
        print(f"   1. TWS 是否已启动并登录？")
        print(f"   2. Edit → Global Configuration → API → Settings 是否启用 API？")
        print(f"   3. Socket port 是否为 {TWS_PORT}？")
        print(f"   4. 是否勾选了 'Create API message log'？")
        sys.exit(1)
        
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
        
    finally:
        if ib.isConnected():
            print("\n👋 断开连接...")
            ib.disconnect()

if __name__ == '__main__':
    asyncio.run(test_connection())
