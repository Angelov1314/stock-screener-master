#!/usr/bin/env python3
"""
IBKR 限价单买入 AMD - 挂到周一开盘
账户: U22127907
"""

from ib_insync import IB, Stock, LimitOrder

TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 12

def main():
    ib = IB()
    
    try:
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID, timeout=10)
        account = 'U22127907'
        
        # 获取当前价格
        amd = Stock('AMD', 'SMART', 'USD')
        ib.qualifyContracts(amd)
        
        ticker = ib.reqMktData(amd)
        ib.sleep(2)
        
        current_price = ticker.last or ticker.close or 200.0
        limit_price = round(current_price * 1.02, 2)  # 限价 +2%
        
        print(f"当前价: ${current_price}")
        print(f"限价: ${limit_price} (+2%)")
        
        # 创建限价单（GTC = 持续到取消）
        order = LimitOrder('BUY', 1, limit_price)
        order.account = account
        order.tif = 'GTC'  # Good Till Cancelled
        
        print(f"\n提交限价单: 买入 1股 AMD @ ${limit_price}")
        
        trade = ib.placeOrder(amd, order)
        print(f"订单ID: {trade.order.orderId}")
        print(f"状态: {trade.orderStatus.status}")
        
        ib.sleep(2)
        print(f"最新状态: {trade.orderStatus.status}")
        
    except Exception as e:
        print(f"错误: {e}")
    finally:
        ib.disconnect()

if __name__ == '__main__':
    main()
