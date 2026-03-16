#!/usr/bin/env python3
"""
IBKR 下单脚本 - 买入 AMD 1股
账户: U22127907
"""

from ib_insync import IB, Stock, MarketOrder

TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 10  # 用不同的ID避免冲突

def main():
    ib = IB()
    
    try:
        print("🔌 连接 TWS...")
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID, timeout=10)
        print("✅ 连接成功\n")
        
        # 设置账户
        account = 'U22127907'
        
        # 创建 AMD 合约
        amd = Stock('AMD', 'SMART', 'USD')
        ib.qualifyContracts(amd)
        print(f"📋 合约: {amd.symbol} @ {amd.exchange} (ID: {amd.conId})")
        
        # 获取当前价格
        ticker = ib.reqMktData(amd)
        ib.sleep(2)
        
        current_price = ticker.last or ticker.ask
        print(f"💰 当前价格: ${current_price}")
        print(f"   买价: ${ticker.bid}")
        print(f"   卖价: ${ticker.ask}")
        
        # 创建市价单
        quantity = 1
        order = MarketOrder('BUY', quantity)
        order.account = account  # 指定账户
        
        print(f"\n📝 订单详情:")
        print(f"   操作: 买入 (BUY)")
        print(f"   股票: AMD")
        print(f"   数量: {quantity} 股")
        print(f"   账户: {account}")
        print(f"   订单类型: 市价单 (Market)")
        print(f"   预计金额: ${current_price * quantity:.2f} USD\n")
        
        # 提示确认
        print("⚠️  确认下单？在 TWS 中确认或修改")
        print("   如果 TWS 设置了自动确认，将直接执行\n")
        
        # 下单
        print("🚀 提交订单...")
        trade = ib.placeOrder(amd, order)
        
        print(f"✅ 订单已提交!")
        print(f"   订单ID: {trade.order.orderId}")
        print(f"   状态: {trade.orderStatus.status}")
        
        # 等待几秒看状态更新
        ib.sleep(3)
        
        # 更新状态
        ib.reqExecutions()
        print(f"\n📊 最新状态: {trade.orderStatus.status}")
        print(f"   已成交: {trade.orderStatus.filled} 股")
        print(f"   剩余: {trade.orderStatus.remaining} 股")
        print(f"   成交均价: ${trade.orderStatus.avgFillPrice}" if trade.orderStatus.avgFillPrice else "   等待成交...")
        
        # 检查持仓
        positions = ib.positions(account)
        amd_position = [p for p in positions if p.contract.symbol == 'AMD']
        if amd_position:
            pos = amd_position[0]
            print(f"\n📈 AMD 持仓: {pos.position} 股 @ ${pos.avgCost:.2f}")
        else:
            print("\n📈 AMD 持仓: 无")
        
        print("\n✅ 完成!")
        
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
