#!/usr/bin/env python3
"""
Binance ETH 买卖测试脚本
- 买入 10 USDT 的 ETH
- 等待成交
- 卖出全部 ETH
"""

import os
import time
import ccxt

def main():
    # 从环境变量读取 API Key
    api_key = os.getenv('BINANCE_API_KEY')
    api_secret = os.getenv('BINANCE_SECRET_KEY')
    
    if not api_key or not api_secret:
        print("❌ 错误: 请设置环境变量 BINANCE_API_KEY 和 BINANCE_SECRET_KEY")
        return
    
    # 初始化 Binance（现货）
    exchange = ccxt.binance({
        'apiKey': api_key,
        'secret': api_secret,
        'enableRateLimit': True,
        'options': {
            'defaultType': 'spot',  # 现货
        }
    })
    
    symbol = 'ETH/USDT'
    buy_amount_usdt = 7.5  # 买入 7.5 USDT
    
    try:
        # 测试连接
        print("🔄 测试 API 连接...")
        balance = exchange.fetch_balance()
        usdt_balance = balance['USDT']['free']
        print(f"✅ 连接成功! 当前 USDT 余额: {usdt_balance}")
        
        if usdt_balance < buy_amount_usdt:
            print(f"❌ USDT 余额不足，需要至少 {buy_amount_usdt} USDT")
            return
        
        # 获取当前价格
        ticker = exchange.fetch_ticker(symbol)
        current_price = ticker['last']
        print(f"📊 当前 ETH 价格: {current_price} USDT")
        
        # 计算买入数量（保留 6 位小数）
        eth_amount = round(buy_amount_usdt / current_price, 6)
        print(f"🛒 准备买入: {eth_amount} ETH (约 {buy_amount_usdt} USDT)")
        
        # 下单买入（市价单）
        print("⏳ 正在下单买入...")
        buy_order = exchange.create_market_buy_order(symbol, eth_amount)
        print(f"✅ 买入成功! 订单 ID: {buy_order['id']}")
        print(f"   成交价格: {buy_order['average']} USDT")
        print(f"   成交数量: {buy_order['filled']} ETH")
        print(f"   实际花费: {buy_order['cost']} USDT")
        
        # 等待 2 秒确保成交
        time.sleep(2)
        
        # 查询新的 ETH 余额
        balance = exchange.fetch_balance()
        eth_balance = balance['ETH']['free']
        print(f"💰 当前 ETH 余额: {eth_balance}")
        
        if eth_balance > 0:
            # 卖出全部 ETH
            print(f"⏳ 正在卖出 {eth_balance} ETH...")
            sell_order = exchange.create_market_sell_order(symbol, eth_balance)
            print(f"✅ 卖出成功! 订单 ID: {sell_order['id']}")
            print(f"   成交价格: {sell_order['average']} USDT")
            print(f"   成交数量: {sell_order['filled']} ETH")
            print(f"   实际获得: {sell_order['cost']} USDT")
            
            # 计算盈亏
            pnl = float(sell_order['cost']) - float(buy_order['cost'])
            pnl_percent = (pnl / float(buy_order['cost'])) * 100
            print(f"\n📈 测试完成!")
            print(f"   买入成本: {buy_order['cost']} USDT")
            print(f"   卖出收入: {sell_order['cost']} USDT")
            print(f"   盈亏: {pnl:.4f} USDT ({pnl_percent:+.2f}%)")
        else:
            print("⚠️ ETH 余额为 0，无法卖出")
        
        # 最终余额
        balance = exchange.fetch_balance()
        print(f"\n💳 最终 USDT 余额: {balance['USDT']['free']}")
        
    except ccxt.AuthenticationError:
        print("❌ API Key 认证失败，请检查 BINANCE_API_KEY 和 BINANCE_SECRET_KEY")
    except ccxt.InsufficientFunds:
        print("❌ 资金不足")
    except ccxt.NetworkError as e:
        print(f"❌ 网络错误: {e}")
    except Exception as e:
        print(f"❌ 错误: {type(e).__name__}: {e}")

if __name__ == "__main__":
    main()
