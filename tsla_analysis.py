#!/usr/bin/env python3
"""
Tesla (TSLA) 完整股票分析报告
包含：数据获取、技术分析、策略回测、新闻整合
"""

import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json

# ============ 1. 数据获取 ============
print("="*60)
print("📊 TESLA (TSLA) 股票分析报告")
print("="*60)

# 获取过去6个月数据
end_date = datetime.now()
start_date = end_date - timedelta(days=180)

ticker = yf.Ticker("TSLA")
df = ticker.history(start=start_date, end=end_date)

print(f"\n📈 数据概况")
print(f"   数据区间: {df.index[0].strftime('%Y-%m-%d')} 至 {df.index[-1].strftime('%Y-%m-%d')}")
print(f"   交易日数: {len(df)}")
print(f"\n   价格统计:")
print(f"   • 最新收盘价: ${df['Close'].iloc[-1]:.2f}")
print(f"   • 6个月最高: ${df['High'].max():.2f}")
print(f"   • 6个月最低: ${df['Low'].min():.2f}")
print(f"   • 平均成交量: {df['Volume'].mean()/1e6:.2f}M")

# ============ 2. 技术指标计算 ============
print(f"\n{'='*60}")
print("📐 技术指标分析")
print("="*60)

# 移动平均线
df['MA5'] = df['Close'].rolling(window=5).mean()
df['MA10'] = df['Close'].rolling(window=10).mean()
df['MA20'] = df['Close'].rolling(window=20).mean()
df['MA60'] = df['Close'].rolling(window=60).mean()

# RSI计算
def calculate_rsi(prices, period=14):
    delta = prices.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss
    return 100 - (100 / (1 + rs))

df['RSI'] = calculate_rsi(df['Close'])

# MACD计算
exp1 = df['Close'].ewm(span=12, adjust=False).mean()
exp2 = df['Close'].ewm(span=26, adjust=False).mean()
df['MACD'] = exp1 - exp2
df['MACD_Signal'] = df['MACD'].ewm(span=9, adjust=False).mean()
df['MACD_Hist'] = df['MACD'] - df['MACD_Signal']

# 布林带
df['BB_Middle'] = df['Close'].rolling(window=20).mean()
df['BB_Std'] = df['Close'].rolling(window=20).std()
df['BB_Upper'] = df['BB_Middle'] + (df['BB_Std'] * 2)
df['BB_Lower'] = df['BB_Middle'] - (df['BB_Std'] * 2)

# 输出最新指标
latest = df.iloc[-1]
print(f"\n   最新技术指标 ({df.index[-1].strftime('%Y-%m-%d')}):")
print(f"   ┌─────────────────────────────────────────┐")
print(f"   │ 移动平均线 (MA)                        │")
print(f"   │   MA5:  ${latest['MA5']:.2f}                    │")
print(f"   │   MA10: ${latest['MA10']:.2f}                    │")
print(f"   │   MA20: ${latest['MA20']:.2f}                    │")
print(f"   │   MA60: ${latest['MA60']:.2f}                    │")
print(f"   ├─────────────────────────────────────────┤")
print(f"   │ RSI (14): {latest['RSI']:.2f}                        │")
print(f"   │   状态: {'超买 (>70)' if latest['RSI'] > 70 else '超卖 (<30)' if latest['RSI'] < 30 else '中性'}                  │")
print(f"   ├─────────────────────────────────────────┤")
print(f"   │ MACD                                   │")
print(f"   │   MACD线: {latest['MACD']:.3f}                     │")
print(f"   │   信号线: {latest['MACD_Signal']:.3f}                     │")
print(f"   │   柱状图: {latest['MACD_Hist']:.3f} ({'看多' if latest['MACD_Hist'] > 0 else '看空'})          │")
print(f"   ├─────────────────────────────────────────┤")
print(f"   │ 布林带                                 │")
print(f"   │   上轨: ${latest['BB_Upper']:.2f}                    │")
print(f"   │   中轨: ${latest['BB_Middle']:.2f}                    │")
print(f"   │   下轨: ${latest['BB_Lower']:.2f}                    │")
print(f"   └─────────────────────────────────────────┘")

# ============ 3. 策略设计：双均线交叉策略 ============
print(f"\n{'='*60}")
print("🎯 交易策略设计：双均线交叉策略")
print("="*60)

print("""
   策略规则:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   买入信号: MA5 上穿 MA20 (金叉)
   卖出信号: MA5 下穿 MA20 (死叉)
   
   仓位管理: 全仓买入/卖出
   止损设置: 买入后价格下跌8%止损
""")

# 计算买卖信号
df['Signal'] = 0
df['Position'] = 0

# 金叉：MA5 > MA20 且 前一天 MA5 <= MA20
df['Signal'] = np.where(
    (df['MA5'] > df['MA20']) & (df['MA5'].shift(1) <= df['MA20'].shift(1)), 1,
    np.where(
        (df['MA5'] < df['MA20']) & (df['MA5'].shift(1) >= df['MA20'].shift(1)), -1, 0
    )
)

# ============ 4. 策略回测 ============
print(f"\n{'='*60}")
print("📊 策略回测结果")
print("="*60)

# 初始化回测参数
initial_capital = 100000  # 初始资金 $100,000
position = 0  # 持仓数量
cash = initial_capital
trades = []  # 交易记录
portfolio_values = []  # 每日组合价值

buy_price = None
stop_loss = 0.08  # 8% 止损

for i in range(len(df)):
    date = df.index[i]
    price = df['Close'].iloc[i]
    signal = df['Signal'].iloc[i]
    
    # 检查止损
    if position > 0 and buy_price:
        if price < buy_price * (1 - stop_loss):
            # 止损卖出
            cash = position * price
            trades.append({
                'date': date,
                'action': 'STOP_LOSS',
                'price': price,
                'shares': position,
                'value': cash
            })
            position = 0
            buy_price = None
    
    # 处理信号
    if signal == 1 and cash > 0:  # 买入信号
        position = int(cash / price)
        buy_price = price
        cost = position * price
        cash = cash - cost
        trades.append({
            'date': date,
            'action': 'BUY',
            'price': price,
            'shares': position,
            'value': cost
        })
    
    elif signal == -1 and position > 0:  # 卖出信号
        cash = position * price
        trades.append({
            'date': date,
            'action': 'SELL',
            'price': price,
            'shares': position,
            'value': cash
        })
        position = 0
        buy_price = None
    
    # 记录组合价值
    portfolio_value = cash + position * price
    portfolio_values.append({
        'date': date,
        'value': portfolio_value,
        'price': price
    })

# 最终平仓
if position > 0:
    final_price = df['Close'].iloc[-1]
    cash = position * final_price
    trades.append({
        'date': df.index[-1],
        'action': 'FINAL_SELL',
        'price': final_price,
        'shares': position,
        'value': cash
    })
    position = 0

# 计算回测指标
final_value = cash
strategy_return = (final_value - initial_capital) / initial_capital * 100

# 买入持有回报
buy_hold_return = (df['Close'].iloc[-1] - df['Close'].iloc[0]) / df['Close'].iloc[0] * 100

# 计算最大回撤
portfolio_df = pd.DataFrame(portfolio_values)
portfolio_df['cummax'] = portfolio_df['value'].cummax()
portfolio_df['drawdown'] = (portfolio_df['value'] - portfolio_df['cummax']) / portfolio_df['cummax']
max_drawdown = portfolio_df['drawdown'].min() * 100

# 夏普比率 (简化计算，假设无风险利率0%)
portfolio_df['daily_return'] = portfolio_df['value'].pct_change()
sharpe_ratio = portfolio_df['daily_return'].mean() / portfolio_df['daily_return'].std() * np.sqrt(252)

# 交易统计
buy_trades = [t for t in trades if t['action'] == 'BUY']
sell_trades = [t for t in trades if t['action'] in ['SELL', 'STOP_LOSS', 'FINAL_SELL']]

print(f"\n   📈 回测业绩对比")
print(f"   ┌─────────────────────────────────────────┐")
print(f"   │ 指标              策略        买入持有   │")
print(f"   ├─────────────────────────────────────────┤")
print(f"   │ 初始资金          ${initial_capital:>10,.0f}  ${initial_capital:>10,.0f}  │")
print(f"   │ 最终资金          ${final_value:>10,.0f}  ${initial_capital*(1+buy_hold_return/100):>10,.0f}  │")
print(f"   │ 总收益率          {strategy_return:>10.2f}%  {buy_hold_return:>10.2f}%  │")
print(f"   │ 最大回撤          {max_drawdown:>10.2f}%           │")
print(f"   │ 夏普比率          {sharpe_ratio:>10.2f}            │")
print(f"   └─────────────────────────────────────────┘")

print(f"\n   📋 交易记录 ({len(buy_trades)} 次买入, {len(sell_trades)} 次卖出):")
for trade in trades:
    emoji = "🟢" if trade['action'] == 'BUY' else "🔴" if trade['action'] == 'SELL' else "🟡"
    print(f"   {emoji} {trade['date'].strftime('%Y-%m-%d')} | {trade['action']:12} | ${trade['price']:.2f} | 股数: {trade['shares']}")

# 胜率统计
if len(sell_trades) > 0:
    winning_trades = 0
    for i, sell in enumerate(sell_trades):
        if i < len(buy_trades):
            if sell['price'] > buy_trades[i]['price']:
                winning_trades += 1
    win_rate = winning_trades / len(sell_trades) * 100
    print(f"\n   🎯 策略胜率: {win_rate:.1f}% ({winning_trades}/{len(sell_trades)})")

# ============ 5. 技术分析总结 ============
print(f"\n{'='*60}")
print("📐 技术面综合评估")
print("="*60)

# 趋势判断
current_price = latest['Close']
trend_score = 0
trend_signals = []

# MA判断
if current_price > latest['MA5'] > latest['MA20'] > latest['MA60']:
    trend_score += 2
    trend_signals.append("多头排列 (MA5>MA20>MA60)")
elif current_price > latest['MA20']:
    trend_score += 1
    trend_signals.append("价格在MA20上方")
else:
    trend_signals.append("价格在MA20下方")

# RSI判断
if 30 < latest['RSI'] < 70:
    trend_score += 1
    trend_signals.append(f"RSI中性 ({latest['RSI']:.1f})")
elif latest['RSI'] >= 70:
    trend_signals.append(f"RSI超买 ({latest['RSI']:.1f}) ⚠️")
else:
    trend_signals.append(f"RSI超卖 ({latest['RSI']:.1f}) 💡")

# MACD判断
if latest['MACD_Hist'] > 0 and latest['MACD'] > latest['MACD_Signal']:
    trend_score += 1
    trend_signals.append("MACD看多 (柱状图>0)")
elif latest['MACD_Hist'] > latest['MACD_Hist'].shift(1):
    trend_signals.append("MACD柱状图扩大")
else:
    trend_signals.append("MACD看空信号")

# 布林带判断
if current_price > latest['BB_Upper']:
    trend_signals.append("价格突破布林带上轨 ⚠️")
elif current_price < latest['BB_Lower']:
    trend_signals.append("价格跌破布林带下轨 💡")
else:
    trend_signals.append("价格在布林带中轨附近")

print(f"\n   技术评分: {trend_score}/4")
print(f"\n   技术信号:")
for sig in trend_signals:
    print(f"   • {sig}")

# 综合技术评级
if trend_score >= 3:
    tech_rating = "🟢 偏多"
elif trend_score <= 1:
    tech_rating = "🔴 偏空"
else:
    tech_rating = "🟡 中性"

print(f"\n   技术评级: {tech_rating}")

# 保存数据供后续使用
df.to_csv('/Users/jerry/.openclaw/workspace/tsla_data.csv')
portfolio_df.to_csv('/Users/jerry/.openclaw/workspace/tsla_portfolio.csv')

print(f"\n{'='*60}")
print("✅ 数据已保存至 tsla_data.csv 和 tsla_portfolio.csv")
print("="*60)
