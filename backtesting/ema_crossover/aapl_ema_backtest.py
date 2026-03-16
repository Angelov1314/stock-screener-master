#!/usr/bin/env python3
"""
AAPL EMA Crossover Backtest - US Stocks
Using yfinance + vectorbt
"""

import os
from datetime import datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd
import vectorbt as vbt
import yfinance as yf
from dotenv import find_dotenv, load_dotenv

# --- Config ---
script_dir = Path(__file__).resolve().parent
load_dotenv(find_dotenv(), override=False)

SYMBOL = "AAPL"
START_DATE = "2024-01-01"
END_DATE = "2025-03-11"
INIT_CASH = 100_000
FEES = 0.0001           # US equity ~0.01%
FAST_EMA = 10
SLOW_EMA = 30
ALLOCATION = 0.95       # 95% allocation

print(f"=== AAPL EMA Crossover Backtest ===")
print(f"Period: {START_DATE} to {END_DATE}")
print(f"Fast EMA: {FAST_EMA}, Slow EMA: {SLOW_EMA}")
print()

# --- Fetch Data from Yahoo Finance ---
print("Fetching data from Yahoo Finance...")
df = yf.download(SYMBOL, start=START_DATE, end=END_DATE, progress=False)

if df.empty:
    print("Error: No data fetched!")
    exit(1)

# Handle multi-index columns from yfinance
if isinstance(df.columns, pd.MultiIndex):
    df.columns = df.columns.get_level_values(0)

df = df.dropna()
close = df['Close']

print(f"Loaded {len(close)} trading days")
print(f"Price range: ${close.min():.2f} - ${close.max():.2f}")
print()

# --- Strategy: EMA Crossover ---
print("Calculating indicators...")
ema_fast = close.ewm(span=FAST_EMA, adjust=False).mean()
ema_slow = close.ewm(span=SLOW_EMA, adjust=False).mean()

# Generate signals
buy_raw = (ema_fast > ema_slow) & (ema_fast.shift(1) <= ema_slow.shift(1))
sell_raw = (ema_fast < ema_slow) & (ema_fast.shift(1) >= ema_slow.shift(1))

# Clean signals (exrem equivalent)
entries = buy_raw & ~buy_raw.cumsum().duplicated()
exits = sell_raw & ~sell_raw.cumsum().duplicated()

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

# --- Benchmark (Buy & Hold) ---
pf_bench = vbt.Portfolio.from_holding(close, init_cash=INIT_CASH, freq="1D")

# --- Results ---
print("\n" + "="*50)
print("BACKTEST RESULTS")
print("="*50)

stats = pf.stats()
print(stats)

# --- Strategy vs Benchmark ---
print("\n" + "="*50)
print("STRATEGY vs BUY & HOLD COMPARISON")
print("="*50)

comparison = pd.DataFrame({
    "Strategy": [
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

# --- Explanation ---
print("\n" + "="*50)
print("INTERPRETATION")
print("="*50)

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

print(f"* Sharpe Ratio: {pf.sharpe_ratio():.2f}")
if pf.sharpe_ratio() > 1:
    print("  -> Good risk-adjusted returns")
elif pf.sharpe_ratio() > 0:
    print("  -> Positive but below optimal risk-adjusted returns")
else:
    print("  -> Negative risk-adjusted returns")

# --- Export Trades ---
if pf.trades.count() > 0:
    trades_file = script_dir / f"{SYMBOL}_trades.csv"
    pf.trades.records_readable.to_csv(trades_file, index=False)
    print(f"\nTrades exported to: {trades_file}")

print("\n" + "="*50)
print("BACKTEST COMPLETE")
print("="*50)
