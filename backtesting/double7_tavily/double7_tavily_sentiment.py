#!/usr/bin/env python3
"""
Connors Double Seven Strategy + Tavily News Sentiment + Batch Position Building
综合策略：双7策略 + Tavily新闻情绪分析 + 分批建仓
"""

import os
import json
import re
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
COMPANY_NAME = "Tesla"  # 用于新闻搜索
START_DATE = "2024-01-01"
END_DATE = "2025-03-11"
INIT_CASH = 100_000
FEES = 0.0001

# Tavily API Key (需要设置环境变量)
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "")

# 分批建仓配置
BATCHES = 3
BATCH_ALLOCATION = 0.30

# Double Seven 参数
TREND_MA = 200
LOOKBACK = 7

# 情绪关键词（简单NLP分析）
POSITIVE_WORDS = ['profit', 'growth', 'beat', 'surge', 'rally', 'boom', 'strong', 'gain', 'up', 'rise', 'bull', 'outperform', 'exceed', 'record', 'soar', 'jump', 'rally', 'momentum']
NEGATIVE_WORDS = ['loss', 'miss', 'fall', 'crash', 'decline', 'bear', 'weak', 'down', 'drop', 'sell', 'short', 'underperform', 'disappoint', 'warning', 'concern', 'fear', 'worry', 'risk', 'trouble']

print(f"=== {SYMBOL} Double Seven + Tavily News Sentiment ===")
print(f"Period: {START_DATE} to {END_DATE}")
print(f"Tavily API: {'✓ Configured' if TAVILY_API_KEY else '✗ Not configured (using fallback)'}")
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
ma_200 = close.rolling(window=TREND_MA).mean()
high_7 = high.rolling(window=LOOKBACK).max()
low_7 = low.rolling(window=LOOKBACK).min()
high_7_prev = high.shift(1).rolling(window=LOOKBACK).max()
low_7_prev = low.shift(1).rolling(window=LOOKBACK).min()
trend_up = close > ma_200

print(f"200-day MA calculated")
print()

# --- Fetch Fear & Greed Index ---
print("Fetching Fear & Greed Index...")

def fetch_fear_greed_index():
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
else:
    print("Using default neutral sentiment")
    print()

# --- Tavily News Sentiment Function ---
def fetch_tavily_sentiment(symbol, company_name, date):
    """
    使用 Tavily API 获取新闻并分析情绪
    返回情绪分 0-100 (0=极度负面, 50=中性, 100=极度正面)
    """
    if not TAVILY_API_KEY:
        # Fallback: 使用 Fear & Greed Index
        if fg_df is not None:
            try:
                fg_value = fg_df.iloc[fg_df.index.get_indexer([date], method='nearest')[0]]['value']
                return fg_value, "Fear&Greed_Fallback"
            except:
                return 50, "Neutral_Fallback"
        return 50, "Neutral_Fallback"
    
    try:
        # Tavily API endpoint
        url = "https://api.tavily.com/search"
        
        # 搜索过去7天的新闻
        search_date = date.strftime("%Y-%m-%d")
        query = f"{company_name} {symbol} stock news sentiment {search_date}"
        
        headers = {
            "Content-Type": "application/json"
        }
        
        payload = {
            "api_key": TAVILY_API_KEY,
            "query": query,
            "search_depth": "basic",
            "include_answer": True,
            "max_results": 5
        }
        
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        result = response.json()
        
        # 分析新闻内容情绪
        all_content = ""
        if 'results' in result:
            for item in result['results']:
                all_content += item.get('title', '') + " " + item.get('content', '') + " "
        
        if 'answer' in result:
            all_content += result['answer']
        
        # 简单NLP情绪分析
        content_lower = all_content.lower()
        
        pos_count = sum(1 for word in POSITIVE_WORDS if word in content_lower)
        neg_count = sum(1 for word in NEGATIVE_WORDS if word in content_lower)
        
        total = pos_count + neg_count
        if total == 0:
            sentiment_score = 50  # 中性
        else:
            # 转换为 0-100 分
            sentiment_score = (pos_count / total) * 100
        
        # 结合 Fear & Greed Index 做加权
        if fg_df is not None:
            try:
                fg_value = fg_df.iloc[fg_df.index.get_indexer([date], method='nearest')[0]]['value']
                # Tavily 60% + Fear&Greed 40%
                final_score = sentiment_score * 0.6 + fg_value * 0.4
            except:
                final_score = sentiment_score
        else:
            final_score = sentiment_score
        
        return final_score, f"Tavily_News({pos_count}pos/{neg_count}neg)"
        
    except Exception as e:
        print(f"Tavily API error: {e}")
        # Fallback
        if fg_df is not None:
            try:
                fg_value = fg_df.iloc[fg_df.index.get_indexer([date], method='nearest')[0]]['value']
                return fg_value, "Fear&Greed_Fallback"
            except:
                return 50, "Neutral_Fallback"
        return 50, "Neutral_Fallback"

# 缓存新闻情绪数据（避免重复调用API）
sentiment_cache = {}

def get_cached_sentiment(symbol, company_name, date):
    """获取缓存的情绪数据"""
    date_key = date.strftime("%Y-%m-%d")
    if date_key not in sentiment_cache:
        sentiment_cache[date_key] = fetch_tavily_sentiment(symbol, company_name, date)
    return sentiment_cache[date_key]

# --- Strategy Rules ---
print("Building Double Seven + Tavily Sentiment signals...")

entries = pd.Series(False, index=close.index)
exits = pd.Series(False, index=close.index)
sentiment_history = []
position_active = False
batch_count = 0
entry_dates = []

# 只在关键日期获取新闻情绪（减少API调用）
key_dates = []
for i in range(LOOKBACK + 1, len(close)):
    date = close.index[i]
    prev_date = close.index[i-1]
    
    trend = trend_up.loc[date] if date in trend_up.index else False
    is_7day_low = low.loc[prev_date] <= low_7_prev.loc[prev_date] if prev_date in low_7_prev.index else False
    is_7day_high = high.loc[prev_date] >= high_7_prev.loc[prev_date] if prev_date in high_7_prev.index else False
    
    # 只在可能出现信号的日子获取情绪
    if trend and is_7day_low:
        key_dates.append(date)
    if is_7day_high:
        key_dates.append(date)

# 去重并排序
key_dates = sorted(list(set(key_dates)))
print(f"Key dates for sentiment analysis: {len(key_dates)} dates")

# 预获取关键日期的情绪数据
print("Fetching news sentiment for key dates...")
for date in key_dates[:10]:  # 限制API调用次数（演示用）
    sentiment, source = get_cached_sentiment(SYMBOL, COMPANY_NAME, date)
    sentiment_history.append({
        'date': date,
        'sentiment': sentiment,
        'source': source
    })
    print(f"  {date.strftime('%Y-%m-%d')}: Sentiment={sentiment:.1f} ({source})")

sentiment_df = pd.DataFrame(sentiment_history).set_index('date')

# 生成交易信号
for i in range(LOOKBACK + 1, len(close)):
    date = close.index[i]
    prev_date = close.index[i-1]
    
    price = close.loc[date]
    prev_low = low.loc[prev_date]
    prev_high = high.loc[prev_date]
    
    trend = trend_up.loc[date] if date in trend_up.index else False
    
    # Double Seven 信号
    is_7day_low = prev_low <= low_7_prev.loc[prev_date] if prev_date in low_7_prev.index else False
    was_7day_low_prev = low.shift(1).loc[prev_date] <= low_7_prev.shift(1).loc[prev_date] if prev_date in low_7_prev.index else False
    double_seven_buy = trend and is_7day_low and not was_7day_low_prev
    
    is_7day_high = prev_high >= high_7_prev.loc[prev_date] if prev_date in high_7_prev.index else False
    was_7day_high_prev = high.shift(1).loc[prev_date] >= high_7_prev.shift(1).loc[prev_date] if prev_date in high_7_prev.index else False
    double_seven_sell = is_7day_high and not was_7day_high_prev
    
    # 获取情绪数据
    sentiment = 50
    if date in sentiment_df.index:
        sentiment = sentiment_df.loc[date, 'sentiment']
    elif fg_df is not None:
        try:
            sentiment = fg_df.iloc[fg_df.index.get_indexer([date], method='nearest')[0]]['value']
        except:
            pass
    
    # 情绪增强
    fear_boost = sentiment < 25  # 极端恐惧
    greed_warning = sentiment > 75  # 极端贪婪
    
    # 分批建仓逻辑
    if not position_active:
        if double_seven_buy or fear_boost:
            entries.iloc[i] = True
            position_active = True
            batch_count = 1
            entry_dates.append(date)
    else:
        if batch_count < BATCHES and fear_boost and (date - entry_dates[-1]).days > 5:
            entries.iloc[i] = True
            batch_count += 1
            entry_dates.append(date)
        
        if double_seven_sell or greed_warning:
            exits.iloc[i] = True
            position_active = False
            batch_count = 0
            entry_dates = []

print(f"\nBuy signals: {entries.sum()}")
print(f"Sell signals: {exits.sum()}")
print()

# --- Backtest ---
print("Running backtest...")

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
    accumulate=True,
)

pf_bench = vbt.Portfolio.from_holding(close, init_cash=INIT_CASH, freq="1D")

# --- Results ---
print("\n" + "="*60)
print("DOUBLE SEVEN + TAVILY NEWS SENTIMENT RESULTS")
print("="*60)

stats = pf.stats()
print(stats)

print("\n" + "="*60)
print("STRATEGY vs BUY & HOLD COMPARISON")
print("="*60)

comparison = pd.DataFrame({
    "Double Seven+Tavily": [
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

print("\n" + "="*60)
print("STRATEGY ANALYSIS")
print("="*60)

strategy_return = pf.total_return() * 100
bench_return = pf_bench.total_return() * 100
max_dd = pf.max_drawdown() * 100

print(f"Strategy Logic:")
print(f"• Double Seven: Buy on {LOOKBACK}-day low above {TREND_MA}-day MA")
print(f"• Tavily News: Real-time sentiment analysis from news headlines")
print(f"• NLP Keywords: {len(POSITIVE_WORDS)} positive / {len(NEGATIVE_WORDS)} negative words")
print(f"• Batch Position: Max {BATCHES} batches, {BATCH_ALLOCATION*100:.0f}% each")
print(f"• Sentiment Weight: Tavily 60% + Fear&Greed 40%")
print()

print(f"Performance:")
print(f"* Total Return: Strategy {strategy_return:.2f}% vs Buy & Hold {bench_return:.2f}%")
if strategy_return > bench_return:
    print(f"  -> Strategy OUTPERFORMED by +{strategy_return - bench_return:.2f}%")
else:
    print(f"  -> Strategy underperformed by {strategy_return - bench_return:.2f}%")

print(f"* Max Drawdown: {max_dd:.2f}%")

if sentiment_history:
    print(f"\nSentiment Analysis Sample:")
    for s in sentiment_history[:5]:
        print(f"  {s['date'].strftime('%Y-%m-%d')}: {s['sentiment']:.1f} ({s['source']})")

# --- Export ---
if pf.trades.count() > 0:
    trades_file = script_dir / f"{SYMBOL}_double7_tavily_trades.csv"
    pf.trades.records_readable.to_csv(trades_file, index=False)
    print(f"\nTrades exported to: {trades_file}")

print("\n" + "="*60)
print("BACKTEST COMPLETE")
print("="*60)

print("\n💡 To use real Tavily API:")
print("   export TAVILY_API_KEY='your_api_key'")
print("   Get your API key at: https://tavily.com")
