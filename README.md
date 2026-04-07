# Stock Screener & Analysis Tool

A multi-indicator stock screening and analysis system built for the OpenClaw AI agent platform. Combines fundamental analysis, technical analysis, and sentiment scoring — including an 8-guru investment framework — to produce comprehensive stock reports.

## Features

- **Multi-Dimensional Scoring**
  - Fundamental score (financials, profitability, growth)
  - Technical score (moving averages, RSI, MACD, Bollinger Bands)
  - Sentiment score (analyst consensus, momentum)
  - 8-Guru framework: Buffett, Munger, Lynch, Dalio, Fisher, Graham, Greenblatt, Marks

- **Piotroski F-Score** calculation for financial health screening

- **Automated Report Generation** — produces Markdown reports with target price analysis and buy/sell recommendations

- **Sprite Processing Utility** (`alpha_segment.py`) — extracts individual animation frames from sprite strip sheets using alpha-channel connected components (used for game asset processing in companion projects)

## Sample Output

See `FLYW_Stock_Analysis_Report.md` for a full example report on Flywire Corporation (FLYW), including:
- Valuation metrics (P/E, P/S, P/B, EV/EBITDA)
- Technical analysis with support/resistance levels
- Weighted target price from multiple valuation methods
- Investment recommendation with bull/bear case

## Usage

This tool is designed to run as an OpenClaw AI agent. Place the agent workspace files (`SOUL.md`, `USER.md`, `AGENTS.md`, `TOOLS.md`) in the working directory and invoke through the OpenClaw harness.

For the sprite segmentation utility:

```bash
python alpha_segment.py <input_dir> <output_dir>
```

Example:
```bash
python alpha_segment.py cow_rows cow_sprites_alpha
```

## Tech Stack

- **Language:** Python 3
- **Image Processing:** Pillow, NumPy, SciPy (connected components)
- **Data:** yfinance, pandas
- **Platform:** OpenClaw AI Agent Framework
