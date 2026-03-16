#!/usr/bin/env python3
"""
Connors Double Seven Strategy + News Sentiment + Batch Position Building
综合策略：双7策略 + 新闻情绪分析 + 分批建仓

原始策略（Larry Connors Double Seven）：
- 趋势：价格在 200日均线之上
- 买入：7日新低（7日内第一个最低点）
- 卖出：7日新高（7日内第一个最高点）

增强功能：
1. 新闻情绪分析（Tavily API）
2. 分批建仓（3批建仓，降低风险）
3. Fear & Greed 情绪指数
4. 动态仓位管理
"""

import os
import json
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd
import vectorbt as vbt
import yfinance as yf
import requests
from dotenv import find_dotenv, load_dotenv

# --- Config ---
script_dir = Path(__file__).resolve().parent
load_dotenv(find_dotenv(), override=False)

SYMBOL = "TSLA"  # 可改为 AAPL, NVDA, SPY 等
START_DATE = "2024-01-01"
END_DATE = "2025-03-11"
INIT_CASH = 100_000
FEES = 0.0001

# 分批建仓配置
BATCHES = 3  # 分3批建仓
BATCH_ALLOCATION = 0.30  # 每批 30% 资金（总计最多90%）

# Double Seven 参数
TREND_MA = 200  # 200日均线判断趋势
LOOKBACK = 7    # 7日新高/低

print(f"=== {SYMBOL} Double Seven + Sentiment + Batch Strategy ===")
print(f"Period: {START_DATE} to {END_DATE}")
print(f"Batch Trading: {BATCHES} batches, {BATCH_ALLOCATION*100:.0f}% each")
print()

# --- Fetch Stock Data ---
print("Fetching stock data...")
df = yf.download(SYMBOL, start=START_DATE, end=END_DATE, progress=False)

if df.empty:
    print("Error: No stock data fetched!")
    exit(1)

if isinstance(df.columns, pd.MultiIndex):
    df.columns = df.columns.get_level_values(0)

df = df.dropna()
close = df['Close']
high = df['High']
low = df['Low']

print(f"Loaded {len(close)} trading days")
print(f"Price range: ${close.min():.2f} - ${close.max():.2f}")
print()

# --- Technical Indicators ---
print("Calculating Double Seven indicators...")

# 200日均线（趋势判断）
ma_200 = close.rolling(window=TREND_MA).mean()

# 7日新高/低
high_7 = high.rolling(window=LOOKBACK).max()
low_7 = low.rolling(window=LOOKBACK).min()

# 前一日的新高/低（用于判断"第一个"）
high_7_prev = high.shift(1).rolling(window=LOOKBACK).max()
low_7_prev = low.shift(1).rolling(window=LOOKBACK).min()

# 趋势方向：价格在200日均线之上
trend_up = close > ma_200

print(f"200-day MA range: ${ma_200.dropna().min():.2f} - ${ma_200.dropna().max():.2f}")
print()

# --- Fetch Fear & Greed Index ---
print("Fetching Fear & Greed Index...")

def fetch_fear_greed_index():
    """Fetch Fear & Greed Index from alternative.me API"""
    try:
        url = "https://api.alternative.me/fng/?limit=365&format=json"
        response = requests.get(url, timeout=30)
        data = response.json()
        
        fg_data = []
        for item in data['data']:
            fg_data.append({
                'date': datetime.fromtimestamp(int(item['timestamp'])),
                'value': int(item['value']),
                'classification': item['value_classification']
            })
        
        fg_df = pd.DataFrame(fg_data)
        fg_df = fg_df.set_index('date').sort_index()
        return fg_df
    except Exception as e:
        print(f"Warning: Could not fetch Fear & Greed Index: {e}")
        return None

fg_df = fetch_fear_greed_index()

if fg_df is not None:
    print(f"Fear & Greed Index loaded: {len(fg_df)} days")
    print(f"Current: {fg_df['value'].iloc[-1]} ({fg_df['classification'].iloc[-1]})")
    print()
else:
    print("Using default neutral sentiment (50)")
    print()

# --- News Sentiment Function ---
def fetch_news_sentiment(symbol, date):
    """
    获取特定日期的新闻情绪
    实际使用时可以调用 Tavily API
    这里用模拟数据演示逻辑
    """
    # 在实际部署时，使用以下方式调用 Tavily:
    # from tavily import TavilyClient
    # client = TavilyClient(api_key=os.getenv("TAVILY_API_KEY"))
    # response = client.search(f"{symbol} stock news", days=7)
    # 然后做 NLP 情绪分析
    
    # 简化版：使用 Fear & Greed Index 作为代理
    if fg_df is not None:
        try:
            fg_value = fg_df.iloc[fg_df.index.get_indexer([date], method='nearest')[0]]['value']
            return fg_value
        except:
            return 50
    return 50

# --- Sentiment Scoring ---
def get_sentiment_score(date):
    """获取综合情绪分（0-100）"""
    fg_value = fetch_news_sentiment(SYMBOL, date)
    return fg_value

# --- Strategy Rules ---
print("Building Double Seven + Sentiment signals...")

# 初始化信号和仓位状态
entries = pd.Series(False, index=close.index)
exits = pd.Series(False, index=close.index)
position_active = False
batch_count = 0
entry_dates = []

for i in range(LOOKBACK + 1, len(close)):
    date = close.index[i]
    prev_date = close.index[i-1]
    
    price = close.loc[date]
    prev_price = close.loc[prev_date]
    prev_low = low.loc[prev_date]
    prev_high = high.loc[prev_date]
    
    trend = trend_up.loc[date] if date in trend_up.index else False
    
    # 获取情绪分
    sentiment = get_sentiment_score(date)
    
    # Double Seven 买入信号
    # 1. 价格在200日均线之上（趋势向上）
    # 2. 创7日新低（价格 <= 过去7日最低点）
    # 3. 前一日没有创7日新低（这是"第一个"7日新低）
    is_7day_low = prev_low <= low_7_prev.loc[prev_date] if prev_date in low_7_prev.index else False
    was_7day_low_prev = low.shift(1).loc[prev_date] <= low_7_prev.shift(1).loc[prev_date] if prev_date in low_7_prev.index else False
    
    double_seven_buy = trend and is_7day_low and not was_7day_low_prev
    
    # Double Seven 卖出信号
    # 1. 创7日新高
    # 2. 前一日没有创7日新高（这是"第一个"7日新高）
    is_7day_high = prev_high >= high_7_prev.loc[prev_date] if prev_date in high_7_prev.index else False
    was_7day_high_prev = high.shift(1).loc[prev_date] >= high_7_prev.shift(1).loc[prev_date] if prev_date in high_7_prev.index else False
    
    double_seven_sell = is_7day_high and not was_7day_high_prev
    
    # 情绪增强：极端恐惧时更积极买入，极端贪婪时更积极卖出
    fear_boost = sentiment < 25  # 极端恐惧，加仓信号
    greed_warning = sentiment > 75  # 极端贪婪，减仓信号
    
    # 分批建仓逻辑
    if not position_active:
        # 没有持仓，寻找买入机会
        if double_seven_buy or fear_boost:
            entries.iloc[i] = True
            position_active = True
            batch_count = 1
            entry_dates.append(date)
    else:
        # 已有持仓，考虑加仓或卖出
        if batch_count < BATCHES and fear_boost and (date - entry_dates[-1]).days > 5:
            # 极端恐惧且间隔5天以上，加仓
            entries.iloc[i] = True
            batch_count += 1
            entry_dates.append(date)
        
        if double_seven_sell or greed_warning:
            # 卖出信号，清仓
            exits.iloc[i] = True
            position_active = False
            batch_count = 0
            entry_dates = []

print(f"Buy signals: {entries.sum()}")
print(f"Sell signals: {exits.sum()}")
print(f"Batches used: {entries.sum()} entries / {BATCHES} max batches")
print()

# --- Backtest ---
print("Running backtest...")

# 使用分批仓位
size_per_trade = BATCH_ALLOCATION

pf = vbt.Portfolio.from_signals(
    close, entries, exits,
    init_cash=INIT_CASH,
    size=size_per_trade,
    size_type="percent",
    fees=FEES,
    direction="longonly",
    min_size=1,
    size_granularity=1,
    freq="1D",
    accumulate=True,  # 允许多次买入累积仓位
)

# --- Benchmark ---
pf_bench = vbt.Portfolio.from_holding(close, init_cash=INIT_CASH, freq="1D")

# --- Results ---
print("\n" + "="*60)
print("DOUBLE SEVEN + SENTIMENT + BATCH STRATEGY RESULTS")
print("="*60)

stats = pf.stats()
print(stats)

# --- Strategy vs Benchmark ---
print("\n" + "="*60)
print("STRATEGY vs BUY & HOLD COMPARISON")
print("="*60)

comparison = pd.DataFrame({
    "Double Seven+": [
        f"{pf.total_return() * 100:.2f}%",
        f"{pf.sharpe_ratio():.2f}",
        f"{pf.sortino_ratio():.2f}",
        f"{pf.max_drawdown() * 100:.2f}%",
        f"{pf.trades.win_rate() * 100:.1f}%" if pf.trades.count() > 0 else "N/A",
        f"{pf.trades.count()}",
        f"{pf.trades.profit_factor():.2f}" if pf.trades.count() > 0 else "N/A",
        f"{pf.annualized_return() * 100:.2f}%",
    ],
    "Buy & Hold": [
        f"{pf_bench.total_return() * 100:.2f}%",
        f"{pf_bench.sharpe_ratio():.2f}",
        f"{pf_bench.sortino_ratio():.2f}",
        f"{pf_bench.max_drawdown() * 100:.2f}%",
        "-",
        "-",
        "-",
        f"{pf_bench.annualized_return() * 100:.2f}%",
    ],
}, index=["Total Return", "Sharpe Ratio", "Sortino Ratio", "Max Drawdown",
          "Win Rate", "Total Trades", "Profit Factor", "Annualized Return"])

print(comparison.to_string())

# --- Strategy Analysis ---
print("\n" + "="*60)
print("STRATEGY ANALYSIS")
print("="*60)

strategy_return = pf.total_return() * 100
bench_return = pf_bench.total_return() * 100
max_dd = pf.max_drawdown() * 100

print(f"Strategy Logic:")
print(f"• Double Seven: Buy on {LOOKBACK}-day low above {TREND_MA}-day MA")
print(f"• Sell on {LOOKBACK}-day high")
print(f"• Batch Position: Max {BATCHES} batches, {BATCH_ALLOCATION*100:.0f}% each")
print(f"• Sentiment Boost: Buy more on extreme fear (<25)")
print(f"• Sentiment Warning: Sell on extreme greed (>75)")
print()

print(f"Performance:")
print(f"* Total Return: Strategy {strategy_return:.2f}% vs Buy & Hold {bench_return:.2f}%")
if strategy_return > bench_return:
    print(f"  -> Strategy OUTPERFORMED by +{strategy_return - bench_return:.2f}%")
else:
    print(f"  -> Strategy underperformed by {strategy_return - bench_return:.2f}%")

print(f"* Max Drawdown: {max_dd:.2f}%")
print(f"  -> Worst temporary loss on ${INIT_CASH:,} = ${abs(max_dd/100 * INIT_CASH):,.0f}")

# --- Export ---
if pf.trades.count() > 0:
    trades_file = script_dir / f"{SYMBOL}_double7_sentiment_trades.csv"
    pf.trades.records_readable.to_csv(trades_file, index=False)
    print(f"\nTrades exported to: {trades_file}")

print("\n" + "="*60)
print("BACKTEST COMPLETE")
print("="*60)
