# Stock Screener & Quant Analysis Workspace

A personal quantitative analysis working directory used with Claude Code agents. Contains stock screening scripts, backtesting tools, IBKR trade execution scripts, and miscellaneous utilities accumulated over time. This is not a packaged tool — it is a live agent workspace.

## What's Here

### Stock Analysis & Screening

| Script | Purpose |
|---|---|
| `flyw_comprehensive_analysis.py` | Multi-dimensional scoring for FLYW: fundamentals, technicals, sentiment, 8-guru framework, Piotroski F-Score |
| `us_stock_strategy.py` | US equity quant screening strategy with Fear & Greed index and Tavily sentiment scoring |
| `backtest_1year.py` | Simple 1-year backtest engine using yfinance historical data |
| `backtesting/double7_sentiment/` | Double-7 strategy with sentiment overlay |
| `backtesting/ema_crossover/` | EMA crossover backtest on AAPL |
| `projects/binance-grid-bot/` | Binance grid trading bot (crypto) |

### Agent Configuration Files

| File | Purpose |
|---|---|
| `SOUL.md` | Agent persona and reasoning style |
| `USER.md` | User preferences and context |
| `AGENTS.md` | Multi-agent coordination spec |
| `TOOLS.md` | Available tool definitions |

### Sample Output

`FLYW_Stock_Analysis_Report.md` — Full example report on Flywire Corporation (FLYW) with valuation metrics, technical analysis, weighted target price, and investment recommendation.

---

## ⚠️ IBKR Live Trading Scripts — Real Money, Use With Caution

The following scripts connect directly to Interactive Brokers TWS and **place real orders against a live brokerage account**. They are included as historical records of executed trades and diagnostic sessions.

**Do not run these unless you fully understand what they do and have verified your TWS configuration.**

| Script | What It Does |
|---|---|
| `ibkr_buy_amd.py` | Places a market order to buy 1 share of AMD |
| `ibkr_buy_amd_limit.py` | Places a limit order to buy AMD |
| `ibkr_check_status.py` | Checks open orders and positions |
| `ibkr_check_delay.py` | Diagnoses data feed delay |
| `ibkr_diagnose.py` | Connection diagnostics |
| `ibkr_test_connection.py` / `ibkr_simple_test.py` / `ibkr_test_v2.py` / `ibkr_final_test.py` | Connection and API tests |

**Requirements for IBKR scripts:** TWS or IB Gateway running locally on port 7496, `ib_insync` installed, and a funded IBKR account.

---

## Installation

No `requirements.txt` is included. Install dependencies as needed per script:

```bash
# Core analysis
pip install yfinance pandas numpy requests

# Sentiment / web search
pip install tavily-python

# IBKR execution scripts
pip install ib_insync

# Crypto grid bot
pip install ccxt python-binance
```

## Notes

- This repo also contains unrelated sprite/image processing utilities (`alpha_segment.py`, `crop_rows.py`, etc.) carried over from a companion game asset project — these are not part of the stock analysis toolset.
- The `skills/` and `godot-farm/` directories contain reusable agent skills and game asset generation scripts unrelated to stock analysis.
