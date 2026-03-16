#!/usr/bin/env python3
"""
IBKR TWS 连接测试 - 换 Client ID
"""

from ib_insync import IB

TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 999  # 换一个不常用的ID

def main():
    ib = IB()
    
    try:
        print(f"🔗 连接 TWS {TWS_HOST}:{TWS_PORT} (Client ID: {CLIENT_ID})...")
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID, timeout=10)
        
        print("✅ 连接成功！")
        print(f"   账户: {ib.managedAccounts()}")
        print(f"   服务器版本: {ib.client.serverVersion()}")
        
    except Exception as e:
        print(f"❌ 失败: {e}")
        print("\n请检查:")
        print("   1. TWS 是否已登录？看左上角名字")
        print("   2. TWS 右上角是否有'接受连接'弹窗？")
        print("   3. macOS 防火墙是否阻止了连接？")
        print("   4. 重启 TWS 试试")
    finally:
        if ib.isConnected():
            ib.disconnect()

if __name__ == '__main__':
    main()
