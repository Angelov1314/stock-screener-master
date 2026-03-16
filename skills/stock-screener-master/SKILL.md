---
name: stock-screener-master
description: Multi-indicator stock screening and analysis tool combining fundamental analysis, technical analysis, sentiment analysis, 8 investor master scoring systems, and comprehensive rating. Use when users need to analyze stocks, screen investment opportunities, evaluate stock fundamentals and technicals, or get buy/hold/sell recommendations with target prices.
---

# Stock Screener Master

A comprehensive multi-indicator stock screening and analysis tool that combines:

1. **Fundamental Analysis** - PE, PS, PB, ROE, margins, growth rates
2. **Technical Analysis** - Trend, RSI, moving averages, support/resistance
3. **Sentiment Analysis** - Tavily news sentiment + Fear & Greed Index
4. **8 Investor Masters Scoring** - Buffett, Lynch, Graham, Dalio, Munger, Greenblatt, Templeton, Soros
5. **Piotroski F-Score** - Financial health assessment
6. **Comprehensive Rating** - Weighted scoring system with buy/hold/sell recommendations

## Quick Start

```bash
# Basic analysis
python scripts/stock_screener.py AAPL

# Save as JSON
python scripts/stock_screener.py TSLA --json --output tsla_report.json

# Multiple stocks
for symbol in AAPL MSFT GOOGL; do
  python scripts/stock_screener.py $symbol --json --output ${symbol}_report.json
done
```

## Features

### 1. Fundamental Analysis

**Valuation Metrics:**
- PE Ratio (Trailing & Forward)
- Price-to-Sales (PS)
- Price-to-Book (PB)

**Profitability:**
- Gross Margin
- Operating Margin
- Profit Margin
- ROE (Return on Equity)

**Growth:**
- Revenue Growth (YoY)
- Earnings Growth (YoY)

**Financial Health:**
- Current Ratio
- Debt-to-Equity

### 2. Technical Analysis

- **Trend Score** (0-6): Based on price vs moving averages
- **RSI (14)**: Overbought/Oversold indicator
- **Moving Averages**: 50-day and 200-day
- **Trend Rating**: Strong / Moderate / Weak

### 3. Sentiment Analysis

**Tavily News Sentiment:**
- Scrapes latest news headlines
- NLP analysis (positive/negative keyword counting)
- Score: 0-100 (0=extremely negative, 100=extremely positive)

**Fear & Greed Index:**
- CNN's market sentiment indicator
- 0-100 scale (0=Extreme Fear, 100=Extreme Greed)

### 4. 8 Investor Masters Scoring

| Master | Focus | Criteria |
|--------|-------|----------|
| **Buffett** | Moat & Quality | ROE, Margins, Growth, FCF |
| **Lynch** | PEG Ratio | PE / Growth Rate |
| **Graham** | Value | PE<15, PB<1.5, Current Ratio>2 |
| **Dalio** | All-Weather | Growth stability |
| **Munger** | Risk Management | Debt levels, Profitability |
| **Greenblatt** | Magic Formula | ROE + Profit Margin |
| **Templeton** | Contrarian | PE levels |
| **Soros** | Trend & Momentum | Growth rates |

### 5. Piotroski F-Score

9-point financial strength scoring system:
- Profitability (3 points)
- Leverage/Liquidity (3 points)
- Operating Efficiency (3 points)

### 6. Comprehensive Rating

**Scoring Weights:**
- Fundamentals: 30%
- Technical: 20%
- Sentiment: 15%
- Master Scores: 20%
- F-Score: 5%
- Growth: 10%

**Rating Scale:**
- 80-100: Strong Buy
- 65-79: Buy
- 50-64: Hold
- 35-49: Reduce
- 0-34: Sell

## Setup

### Requirements

```bash
pip install yfinance pandas numpy requests python-dotenv
```

### Environment Variables

Create `.env` file:
```
TAVILY_API_KEY=your_tavily_api_key_here
```

Get Tavily API key at: https://tavily.com (free tier available)

## Usage Examples

### Single Stock Analysis

```bash
python scripts/stock_screener.py FLYW
```

Output:
```
======================================================================
🎯 FLYW - 多指标股票筛选报告
======================================================================

📊 基本信息
----------------------------------------------------------------------
  公司名称: Flywire Corporation
  行业: Software - Infrastructure
  当前价格: $13.15
  市值: $1.61B
  52周区间: $8.20 - $15.25

💰 基本面分析
----------------------------------------------------------------------
  估值:
    • PE (TTM): 119.5
    • Forward PE: 10.9
    • PS: 2.58
  盈利:
    • 毛利率: 61.4%
    • ROE: 1.6%
  增长:
    • 营收增长: 34.0%
    • 盈利增长: XX%

📈 技术面分析
----------------------------------------------------------------------
    • RSI (14): 69.8
    • 趋势评分: 5/6 (Strong)
    • 50日均线: 上方
    • 200日均线: 上方

📰 情绪分析
----------------------------------------------------------------------
    • 新闻情绪: 100.0/100
    • Fear & Greed: 15/100 (Extreme Fear)

👑 投资大师评分
----------------------------------------------------------------------
    • Buffett: 6/10
    • Lynch: 2/10
    • Graham: 4/10
    • ...
    • 平均分: 5.5/10

🏆 综合评分
======================================================================
    • Piotroski F-Score: 6/9
    • 综合评分: 100.0/100
    • 投资评级: Strong Buy
    • 目标价: $16.00 (+21.7%)
```

### Batch Screening

```bash
#!/bin/bash
SYMBOLS="AAPL MSFT GOOGL AMZN TSLA NVDA"

for symbol in $SYMBOLS; do
  echo "Analyzing $symbol..."
  python scripts/stock_screener.py $symbol --json --output reports/${symbol}.json
done

# Generate comparison table
python scripts/compare_stocks.py reports/*.json
```

### Python API

```python
from stock_screener import StockScreener

# Analyze single stock
screener = StockScreener("AAPL")
report = screener.generate_report()

# Access specific metrics
print(f"Score: {report['total_score']}")
print(f"Rating: {report['rating']}")
print(f"Target: ${report['target_price']}")

# Access fundamentals
print(f"PE: {report['fundamentals']['valuation']['pe_trailing']}")
print(f"Growth: {report['fundamentals']['growth']['revenue_growth']}")

# Access master scores
for master, score in report['master_scores'].items():
    print(f"{master}: {score}")
```

## Data Sources

- **Yahoo Finance (yfinance)**: Stock prices, fundamentals, technicals
- **Tavily API**: News sentiment analysis
- **Alternative.me API**: Fear & Greed Index

## Limitations

- Requires internet connection
- Tavily API key needed for sentiment analysis (optional)
- Analysis based on publicly available data
- Past performance doesn't guarantee future results
- Not financial advice

## Output Format

### JSON Structure

```json
{
  "symbol": "AAPL",
  "basic": {
    "name": "Apple Inc.",
    "sector": "Technology",
    "current_price": 175.50,
    "market_cap": 2800000000000
  },
  "fundamentals": {
    "valuation": {...},
    "profitability": {...},
    "growth": {...},
    "financial_health": {...}
  },
  "technical": {...},
  "sentiment": {...},
  "fear_greed": {...},
  "master_scores": {...},
  "f_score": 7,
  "total_score": 85.5,
  "rating": "Strong Buy",
  "target_price": 200.00,
  "upside": 14.0,
  "analysis_date": "2025-03-11 12:00"
}
```

## Customization

### Adjust Scoring Weights

Edit `calculate_comprehensive_score()` method in `stock_screener.py`:

```python
total = (
    fundamental_score * 35 +  # Increase fundamental weight
    technical_score * 15 +     # Decrease technical weight
    sentiment_score * 15 +
    masters['average'] * 20 +
    f_score * 5 +
    growth_score * 10
)
```

### Add Custom Metrics

```python
def analyze_custom_metric(self):
    """Add your own analysis logic"""
    info = self.info
    
    # Example: Custom growth score
    revenue_3y = [...]  # Get 3-year revenue data
    growth_trend = calculate_trend(revenue_3y)
    
    return {
        'growth_trend': growth_trend,
        'custom_score': min(growth_trend * 10, 100)
    }
```

## Best Practices

1. **Use with multiple stocks**: Screen 10-20 stocks and pick top 3-5
2. **Combine with qualitative analysis**: Don't rely solely on scores
3. **Check recent news**: Scores change with new developments
4. **Verify data**: Double-check key metrics before investing
5. **Diversify**: Don't put all money in one stock even with high score

## Disclaimer

This tool is for **educational and research purposes only**. It does not constitute financial advice. Always do your own research and consult with a qualified financial advisor before making investment decisions.

## License

MIT License - Feel free to modify and distribute.

## Contributing

To add new features:
1. Fork the repository
2. Create a feature branch
3. Add your improvements
4. Submit a pull request

Ideas for contributions:
- Add more technical indicators (MACD, Bollinger Bands, etc.)
- Implement sector comparison
- Add historical score tracking
- Create visualization dashboard
- Add more master scoring systems
