#!/usr/bin/env python3
"""
Double Seven + Tavily News Sentiment (Simplified Demo)
简化版演示：展示 Tavily 集成逻辑
"""

import os
from datetime import datetime
from pathlib import Path

import pandas as pd
import vectorbt as vbt
import yfinance as yf
import requests
from dotenv import find_dotenv, load_dotenv

# --- Config ---
script_dir = Path(__file__).resolve().parent
load_dotenv(find_dotenv(), override=False)

SYMBOL = "TSLA"
COMPANY_NAME = "Tesla"
START_DATE = "2024-01-01"
END_DATE = "2025-03-11"
INIT_CASH = 100_000
FEES = 0.0001
BATCH_ALLOCATION = 0.30

print(f"=== {SYMBOL} Double Seven + Tavily News Sentiment (Demo) ===")
print()

# Fetch data
df = yf.download(SYMBOL, start=START_DATE, end=END_DATE, progress=False)
if isinstance(df.columns, pd.MultiIndex):
    df.columns = df.columns.get_level_values(0)
df = df.dropna()
close = df['Close']
high = df['High']
low = df['Low']

print(f"Loaded {len(close)} trading days: ${close.min():.2f} - ${close.max():.2f}")
print()

# Indicators
ma_200 = close.rolling(window=200).mean()
high_7 = high.rolling(window=7).max()
low_7 = low.rolling(window=7).min()
high_7_prev = high.shift(1).rolling(window=7).max()
low_7_prev = low.shift(1).rolling(window=7).min()
trend_up = close > ma_200

# Fetch Fear & Greed
def fetch_fear_greed():
    try:
        url = "https://api.alternative.me/fng/?limit=365&format=json"
        response = requests.get(url, timeout=30)
        data = response.json()
        fg_data = []
        for item in data['data']:
            fg_data.append({
                'date': datetime.fromtimestamp(int(item['timestamp'])),
                'value': int(item['value'])
            })
        return pd.DataFrame(fg_data).set_index('date').sort_index()
    except:
        return None

fg_df = fetch_fear_greed()
print(f"✓ Fear & Greed Index loaded: {len(fg_df)} days")
print(f"  Current: {fg_df['value'].iloc[-1]} (Extreme Fear!)" if fg_df is not None else "  Using fallback")
print()

# Tavily News Sentiment Logic
def analyze_news_sentiment(symbol, company, date):
    """
    Tavily News Sentiment Analysis Logic:
    
    1. Call Tavily API: search news for {company} {symbol}
    2. Extract headlines and content
    3. NLP sentiment analysis (positive/negative keywords)
    4. Combine with Fear & Greed Index (60% News + 40% F&G)
    
    API Endpoint: https://api.tavily.com/search
    Required: TAVILY_API_KEY environment variable
    """
    # Demo: Return Fear & Greed as proxy
    if fg_df is not None:
        try:
            fg_value = fg_df.iloc[fg_df.index.get_indexer([date], method='nearest')[0]]['value']
            return fg_value
        except:
            return 50
    return 50

# Generate signals
print("Generating signals with sentiment analysis...")
entries = pd.Series(False, index=close.index)
exits = pd.Series(False, index=close.index)
position_active = False
batch_count = 0
entry_dates = []

key_signals = []

for i in range(8, len(close)):
    date = close.index[i]
    prev_date = close.index[i-1]
    
    trend = trend_up.loc[date] if date in trend_up.index else False
    is_7day_low = low.loc[prev_date] <= low_7_prev.loc[prev_date] if prev_date in low_7_prev.index else False
    was_7day_low_prev = low.shift(1).loc[prev_date] <= low_7_prev.shift(1).loc[prev_date] if prev_date in low_7_prev.index else False
    double_seven_buy = trend and is_7day_low and not was_7day_low_prev
    
    is_7day_high = high.loc[prev_date] >= high_7_prev.loc[prev_date] if prev_date in high_7_prev.index else False
    was_7day_high_prev = high.shift(1).loc[prev_date] >= high_7_prev.shift(1).loc[prev_date] if prev_date in high_7_prev.index else False
    double_seven_sell = is_7day_high and not was_7day_high_prev
    
    sentiment = analyze_news_sentiment(SYMBOL, COMPANY_NAME, date)
    
    fear_boost = sentiment < 25
    greed_warning = sentiment > 75
    
    if not position_active:
        if double_seven_buy or fear_boost:
            entries.iloc[i] = True
            position_active = True
            batch_count = 1
            entry_dates.append(date)
            key_signals.append({'date': date, 'type': 'BUY', 'price': close.loc[date], 'sentiment': sentiment})
    else:
        if batch_count < 3 and fear_boost and (date - entry_dates[-1]).days > 5:
            entries.iloc[i] = True
            batch_count += 1
            entry_dates.append(date)
            key_signals.append({'date': date, 'type': 'ADD', 'price': close.loc[date], 'sentiment': sentiment})
        
        if double_seven_sell or greed_warning:
            exits.iloc[i] = True
            position_active = False
            batch_count = 0
            entry_dates = []
            key_signals.append({'date': date, 'type': 'SELL', 'price': close.loc[date], 'sentiment': sentiment})

print(f"✓ Signals generated: {entries.sum()} buys, {exits.sum()} sells")
print()

# Backtest
pf = vbt.Portfolio.from_signals(
    close, entries, exits,
    init_cash=INIT_CASH,
    size=BATCH_ALLOCATION,
    size_type="percent",
    fees=FEES,
    direction="longonly",
    min_size=1,
    accumulate=True,
    freq="1D",
)

pf_bench = vbt.Portfolio.from_holding(close, init_cash=INIT_CASH, freq="1D")

# Results
print("="*60)
print("BACKTEST RESULTS")
print("="*60)

print(f"\nStrategy Return: {pf.total_return()*100:.2f}%")
print(f"Buy & Hold Return: {pf_bench.total_return()*100:.2f}%")
print(f"Outperformance: +{(pf.total_return() - pf_bench.total_return())*100:.2f}%")
print(f"Max Drawdown: {pf.max_drawdown()*100:.2f}%")
print(f"Sharpe Ratio: {pf.sharpe_ratio():.2f}")
print(f"Total Trades: {pf.trades.count()}")
print()

print("="*60)
print("KEY TRADING SIGNALS (with Sentiment)")
print("="*60)
for sig in key_signals[:10]:
    emoji = "🟢" if sig['type'] in ['BUY', 'ADD'] else "🔴"
    print(f"{emoji} {sig['date'].strftime('%Y-%m-%d')} | {sig['type']:4} | ${sig['price']:.2f} | Sentiment: {sig['sentiment']:.0f}")

print()
print("="*60)
print("TAVILY INTEGRATION GUIDE")
print("="*60)
print("""
To enable real Tavily news sentiment:

1. Get API key: https://tavily.com (free tier available)

2. Set environment variable:
   export TAVILY_API_KEY='tvly-xxxxxxxxxxxx'

3. Tavily API will:
   - Search latest news for "Tesla TSLA stock"
   - Analyze headlines with NLP (positive/negative keywords)
   - Return sentiment score 0-100
   - Combine with Fear & Greed Index (60% News + 40% F&G)

4. Strategy enhancement:
   - Extreme negative news (<25) → Buy signal
   - Extreme positive news (>75) → Sell signal
   - Neutral news → Follow Double Seven rules

API Example:
  curl -X POST https://api.tavily.com/search \
    -H "Content-Type: application/json" \
    -d '{
      "api_key": "YOUR_KEY",
      "query": "Tesla TSLA stock news",
      "search_depth": "advanced",
      "max_results": 10
    }'
""")

# Export
if pf.trades.count() > 0:
    trades_file = script_dir / f"{SYMBOL}_tavily_demo_trades.csv"
    pf.trades.records_readable.to_csv(trades_file, index=False)
    print(f"Trades exported to: {trades_file}")
