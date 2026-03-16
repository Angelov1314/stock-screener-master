#!/usr/bin/env python3
"""
查询 IBKR 持仓和订单状态
"""

from ib_insync import IB

TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 11

def main():
    ib = IB()
    
    try:
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID, timeout=10)
        
        account = 'U22127907'
        
        # 查询持仓
        print("📈 当前持仓:")
        positions = ib.positions(account)
        if positions:
            for pos in positions:
                print(f"   {pos.contract.symbol}: {pos.position} 股 @ ${pos.avgCost:.2f}")
        else:
            print("   无持仓")
        
        # 查询订单
        print("\n📝 当前订单:")
        trades = ib.trades()
        if trades:
            for trade in trades:
                print(f"   订单ID: {trade.order.orderId}")
                print(f"   {trade.contract.symbol} | {trade.order.action} {trade.order.totalQuantity}股")
                print(f"   状态: {trade.orderStatus.status}")
                print(f"   已成交: {trade.orderStatus.filled} / {trade.order.totalQuantity}")
                print()
        else:
            print("   无活跃订单")
        
        # 账户摘要
        print("💰 账户摘要:")
        summary = ib.accountSummary(account)
        for item in summary:
            if item.tag in ['NetLiquidation', 'AvailableFunds', 'BuyingPower', 'CashBalance']:
                print(f"   {item.tag}: {item.value} {item.currency}")
        
    except Exception as e:
        print(f"错误: {e}")
    finally:
        ib.disconnect()

if __name__ == '__main__':
    main()
