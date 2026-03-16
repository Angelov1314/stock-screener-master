# Stock Screener Master

Multi-indicator stock screening and analysis tool for OpenClaw.

## Quick Start

```bash
# Analyze a stock
python scripts/stock_screener.py AAPL

# Save as JSON
python scripts/stock_screener.py TSLA --json --output report.json
```

## Features

- ✅ Fundamental Analysis (PE, PS, ROE, Margins, Growth)
- ✅ Technical Analysis (Trend, RSI, Moving Averages)
- ✅ Sentiment Analysis (Tavily News + Fear & Greed)
- ✅ 8 Investor Masters Scoring
- ✅ Piotroski F-Score
- ✅ Comprehensive Rating (0-100)
- ✅ Buy/Hold/Sell Recommendations

## Setup

```bash
pip install yfinance pandas numpy requests python-dotenv
```

Optional: Set Tavily API key in `.env` file for news sentiment analysis.

## Usage

See `references/EXAMPLES.md` for detailed usage examples.

## License

MIT
