#!/usr/bin/env python3
"""
Sentiment-Based Trading Strategy for US Stocks
Combines: Technical Indicators + Fear & Greed Index + News Sentiment
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

SYMBOL = "TSLA"  # Can be changed to AAPL, NVDA, etc.
START_DATE = "2024-01-01"
END_DATE = "2025-03-11"
INIT_CASH = 100_000
FEES = 0.0001
ALLOCATION = 0.95

print(f"=== {SYMBOL} Sentiment-Based Strategy ===")
print(f"Period: {START_DATE} to {END_DATE}")
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

print(f"Loaded {len(close)} trading days")
print(f"Price range: ${close.min():.2f} - ${close.max():.2f}")
print()

# --- Technical Indicators ---
print("Calculating technical indicators...")

# EMA
ema_fast = close.ewm(span=10, adjust=False).mean()
ema_slow = close.ewm(span=30, adjust=False).mean()

# RSI
delta = close.diff()
gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
rs = gain / loss
rsi = 100 - (100 / (1 + rs))

# MACD
ema_12 = close.ewm(span=12, adjust=False).mean()
ema_26 = close.ewm(span=26, adjust=False).mean()
macd = ema_12 - ema_26
macd_signal = macd.ewm(span=9, adjust=False).mean()

print("Technical indicators calculated.")
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
    print(f"Fear & Greed Index: {len(fg_df)} days")
    print(f"Current: {fg_df['value'].iloc[-1]} ({fg_df['classification'].iloc[-1]})")
    print()
else:
    print("Using default neutral sentiment (50)")
    print()

# --- Sentiment Scoring System ---
print("Building sentiment scoring system...")

def calculate_sentiment_score(date_idx):
    """
    Calculate composite sentiment score (0-100)
    0 = Extreme Fear, 100 = Extreme Greed
    """
    scores = []
    
    # 1. Fear & Greed Index (40% weight)
    if fg_df is not None:
        # Find closest date
        fg_value = fg_df.iloc[fg_df.index.get_indexer([date_idx], method='nearest')[0]]['value']
        scores.append(('Fear&Greed', fg_value, 0.4))
    
    # 2. RSI-based sentiment (30% weight)
    rsi_value = rsi.loc[date_idx] if date_idx in rsi.index else 50
    if pd.notna(rsi_value):
        # Convert RSI to 0-100 sentiment (RSI 30 = 0, RSI 70 = 100)
        rsi_sentiment = max(0, min(100, (rsi_value - 30) / 40 * 100))
        scores.append(('RSI', rsi_sentiment, 0.3))
    
    # 3. Price vs EMA sentiment (30% weight)
    if date_idx in close.index and date_idx in ema_slow.index:
        price = close.loc[date_idx]
        ema = ema_slow.loc[date_idx]
        if pd.notna(price) and pd.notna(ema):
            # Price above EMA = bullish (50-100), below = bearish (0-50)
            deviation = (price - ema) / ema * 100
            ema_sentiment = max(0, min(100, 50 + deviation * 5))
            scores.append(('Price/EMA', ema_sentiment, 0.3))
    
    # Calculate weighted average
    if scores:
        total_weight = sum(s[2] for s in scores)
        weighted_sum = sum(s[1] * s[2] for s in scores)
        final_score = weighted_sum / total_weight if total_weight > 0 else 50
        
        return final_score, scores
    
    return 50, []

# Calculate sentiment for each day
sentiment_scores = []
for date in close.index:
    score, components = calculate_sentiment_score(date)
    sentiment_scores.append(score)

sentiment_series = pd.Series(sentiment_scores, index=close.index)

print(f"Sentiment score range: {sentiment_series.min():.1f} - {sentiment_series.max():.1f}")
print(f"Average: {sentiment_series.mean():.1f}")
print()

# --- Strategy Rules ---
print("Applying sentiment-based strategy...")

# Strategy: Contrarian approach
# Extreme Fear (< 25) -> Buy signal (market oversold)
# Extreme Greed (> 75) -> Sell signal (market overbought)
# Neutral zone -> Follow trend (EMA crossover)

def generate_signals():
    """Generate buy/sell signals based on sentiment"""
    entries = pd.Series(False, index=close.index)
    exits = pd.Series(False, index=close.index)
    
    for i in range(1, len(close)):
        date = close.index[i]
        prev_date = close.index[i-1]
        
        sentiment = sentiment_series.loc[date]
        prev_sentiment = sentiment_series.loc[prev_date]
        
        # Technical trend
        trend_bullish = ema_fast.loc[date] > ema_slow.loc[date]
        
        # Buy Conditions:
        # 1. Extreme Fear (contrarian buy) OR
        # 2. Sentiment improving from fear zone + trend bullish
        if sentiment < 25:
            entries.iloc[i] = True  # Extreme fear - buy
        elif prev_sentiment < 40 and sentiment > prev_sentiment and trend_bullish:
            entries.iloc[i] = True  # Recovering from fear + trend up
        
        # Sell Conditions:
        # 1. Extreme Greed (contrarian sell) OR
        # 2. Sentiment deteriorating + trend bearish
        if sentiment > 75:
            exits.iloc[i] = True  # Extreme greed - sell
        elif prev_sentiment > 60 and sentiment < prev_sentiment and not trend_bullish:
            exits.iloc[i] = True  # Declining from greed + trend down
    
    return entries, exits

entries, exits = generate_signals()

print(f"Buy signals: {entries.sum()}")
print(f"Sell signals: {exits.sum()}")
print()

# --- Backtest ---
print("Running backtest...")

pf = vbt.Portfolio.from_signals(
    close, entries, exits,
    init_cash=INIT_CASH,
    size=ALLOCATION,
    size_type="percent",
    fees=FEES,
    direction="longonly",
    min_size=1,
    size_granularity=1,
    freq="1D",
)

# --- Benchmark ---
pf_bench = vbt.Portfolio.from_holding(close, init_cash=INIT_CASH, freq="1D")

# --- Results ---
print("\n" + "="*60)
print("SENTIMENT STRATEGY RESULTS")
print("="*60)

stats = pf.stats()
print(stats)

# --- Strategy vs Benchmark ---
print("\n" + "="*60)
print("STRATEGY vs BUY & HOLD COMPARISON")
print("="*60)

comparison = pd.DataFrame({
    "Sentiment Strategy": [
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

# --- Sentiment Analysis ---
print("\n" + "="*60)
print("SENTIMENT ANALYSIS")
print("="*60)

strategy_return = pf.total_return() * 100
bench_return = pf_bench.total_return() * 100
max_dd = pf.max_drawdown() * 100

print(f"* Total Return: Strategy {strategy_return:.2f}% vs Buy & Hold {bench_return:.2f}%")
if strategy_return > bench_return:
    print(f"  -> Strategy OUTPERFORMED by +{strategy_return - bench_return:.2f}%")
else:
    print(f"  -> Strategy underperformed by {strategy_return - bench_return:.2f}%")

print(f"* Max Drawdown: {max_dd:.2f}%")
print(f"  -> Worst temporary loss on ${INIT_CASH:,} = ${abs(max_dd/100 * INIT_CASH):,.0f}")

print(f"* Sentiment Range: {sentiment_series.min():.0f} - {sentiment_series.max():.0f}")
print(f"  -> < 25: Extreme Fear (Buy opportunities)")
print(f"  -> > 75: Extreme Greed (Sell opportunities)")

# Count extreme signals
extreme_fear_days = (sentiment_series < 25).sum()
extreme_greed_days = (sentiment_series > 75).sum()
print(f"* Extreme Fear days: {extreme_fear_days}")
print(f"* Extreme Greed days: {extreme_greed_days}")

# --- Export ---
if pf.trades.count() > 0:
    trades_file = script_dir / f"{SYMBOL}_sentiment_trades.csv"
    pf.trades.records_readable.to_csv(trades_file, index=False)
    print(f"\nTrades exported to: {trades_file}")

# Export sentiment data
sentiment_df = pd.DataFrame({
    'Close': close,
    'Sentiment': sentiment_series,
    'RSI': rsi,
    'EMA_Fast': ema_fast,
    'EMA_Slow': ema_slow,
    'Buy_Signal': entries,
    'Sell_Signal': exits
})
sentiment_file = script_dir / f"{SYMBOL}_sentiment_data.csv"
sentiment_df.to_csv(sentiment_file)
print(f"Sentiment data exported to: {sentiment_file}")

print("\n" + "="*60)
print("BACKTEST COMPLETE")
print("="*60)

print("\n💡 Strategy Logic:")
print("- Buy when: Extreme Fear (<25) OR recovering from fear + uptrend")
print("- Sell when: Extreme Greed (>75) OR declining from greed + downtrend")
print("- Combines: Fear&Greed Index + RSI + Price/EMA Trend")
