# Examples of using stock-screener-master skill

## Example 1: Basic Analysis

```bash
python scripts/stock_screener.py AAPL
```

## Example 2: Save as JSON

```bash
python scripts/stock_screener.py TSLA --json --output report.json
```

## Example 3: Compare Multiple Stocks

```bash
# Create comparison directory
mkdir -p comparisons

# Analyze multiple stocks
for symbol in AAPL MSFT GOOGL AMZN NVDA; do
    python scripts/stock_screener.py $symbol --json --output comparisons/${symbol}.json
    echo "Analyzed $symbol"
done

# Generate summary
echo "Summary of Analysis:"
echo "==================="
for file in comparisons/*.json; do
    symbol=$(basename $file .json)
    score=$(python3 -c "import json; data=json.load(open('$file')); print(f\"{data['total_score']:.1f}\")")
    rating=$(python3 -c "import json; data=json.load(open('$file')); print(data['rating'])")
    echo "$symbol: Score=$score, Rating=$rating"
done
```

## Example 4: Python API Usage

```python
from scripts.stock_screener import StockScreener

# Single stock analysis
screener = StockScreener("FLYW")
report = screener.generate_report()

print(f"Symbol: {report['symbol']}")
print(f"Score: {report['total_score']}/100")
print(f"Rating: {report['rating']}")
print(f"Target: ${report['target_price']:.2f}")

# Access master scores
print("\nMaster Scores:")
for master, score in report['master_scores'].items():
    if master != 'average':
        print(f"  {master}: {score}/10")
```

## Example 5: Screening Top Candidates

```python
import json
from pathlib import Path

watchlist = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "TSLA", "META", "NFLX"]
results = []

for symbol in watchlist:
    try:
        screener = StockScreener(symbol)
        report = screener.generate_report()
        results.append({
            'symbol': symbol,
            'score': report['total_score'],
            'rating': report['rating'],
            'target': report['target_price'],
            'upside': report['upside']
        })
    except Exception as e:
        print(f"Error analyzing {symbol}: {e}")

# Sort by score
top_picks = sorted(results, key=lambda x: x['score'], reverse=True)[:5]

print("\nTop 5 Stock Picks:")
print("=" * 60)
for i, stock in enumerate(top_picks, 1):
    print(f"{i}. {stock['symbol']}")
    print(f"   Score: {stock['score']:.1f}/100")
    print(f"   Rating: {stock['rating']}")
    print(f"   Target: ${stock['target']:.2f} ({stock['upside']:+.1f}%)")
    print()
```

## Example 6: Custom Weight Configuration

```python
# Modify weights for your preference
def calculate_custom_score(report):
    '''Custom scoring with higher weight on growth'''
    
    fundamental = (report['master_scores']['Buffett'] + 
                   report['master_scores']['Graham']) / 2
    technical = report['technical']['trend_score'] * 10 / 6 if report['technical'] else 5
    sentiment = report['sentiment']['score'] / 10
    growth = min(report['fundamentals']['growth']['revenue_growth'] / 3, 10)
    
    # Custom weights: Growth-focused
    total = (
        fundamental * 20 +   # Lower fundamental weight
        technical * 20 +
        sentiment * 10 +
        growth * 40 +        # Higher growth weight
        report['f_score'] * 10
    )
    
    return min(total, 100)

# Usage
screener = StockScreener("TSLA")
report = screener.generate_report()
custom_score = calculate_custom_score(report)
print(f"Custom Growth Score: {custom_score:.1f}/100")
```

## Example 7: Daily Screening Routine

```bash
#!/bin/bash
# daily_screen.sh - Run daily stock screening

DATE=$(date +%Y-%m-%d)
OUTPUT_DIR="screening_results/$DATE"
mkdir -p $OUTPUT_DIR

# Watchlist
WATCHLIST="AAPL MSFT GOOGL AMZN NVDA TSLA META NFLX AMD CRM PLTR"

echo "Starting Daily Stock Screening - $DATE"
echo "=========================================="

for symbol in $WATCHLIST; do
    echo "Analyzing $symbol..."
    python scripts/stock_screener.py $symbol --json --output "$OUTPUT_DIR/${symbol}.json" 2>/dev/null
    sleep 1  # Rate limiting
done

# Generate top picks report
echo ""
echo "Generating Top Picks Report..."
python3 << EOF
import json
import glob
from pathlib import Path

results = []
for file in glob.glob("$OUTPUT_DIR/*.json"):
    with open(file) as f:
        data = json.load(f)
        results.append({
            'symbol': data['symbol'],
            'score': data['total_score'],
            'rating': data['rating'],
            'target': data['target_price'],
            'current': data['basic']['current_price']
        })

# Sort by score
top_picks = sorted(results, key=lambda x: x['score'], reverse=True)

print("\n📊 Daily Screening Results - $DATE")
print("=" * 70)
print(f"{'Rank':<6} {'Symbol':<8} {'Score':<8} {'Rating':<12} {'Upside':<10}")
print("-" * 70)

for i, stock in enumerate(top_picks[:10], 1):
    upside = (stock['target'] - stock['current']) / stock['current'] * 100
    print(f"{i:<6} {stock['symbol']:<8} {stock['score']:<8.1f} {stock['rating']:<12} {upside:+.1f}%")

print("=" * 70)
EOF

echo ""
echo "Results saved to: $OUTPUT_DIR"
```

## Example 8: Integration with Trading Strategy

```python
from stock_screener import StockScreener

def trading_strategy(symbol, entry_threshold=70, exit_threshold=50):
    '''
    Simple trading strategy based on screener scores
    - Buy when score > entry_threshold
    - Sell when score < exit_threshold
    '''
    
    screener = StockScreener(symbol)
    report = screener.generate_report()
    
    score = report['total_score']
    current_price = report['basic']['current_price']
    target = report['target_price']
    
    signal = None
    
    if score >= entry_threshold:
        signal = 'BUY'
        reason = f"High score {score:.1f} indicates strong fundamentals and technicals"
    elif score <= exit_threshold:
        signal = 'SELL'
        reason = f"Low score {score:.1f} indicates weak outlook"
    else:
        signal = 'HOLD'
        reason = f"Neutral score {score:.1f}, maintain position"
    
    return {
        'symbol': symbol,
        'signal': signal,
        'score': score,
        'current_price': current_price,
        'target_price': target,
        'reason': reason
    }

# Usage
result = trading_strategy("AAPL", entry_threshold=75, exit_threshold=45)
print(f"Signal: {result['signal']}")
print(f"Reason: {result['reason']}")
```

## Tips for Best Results

1. **Combine with manual research**: Use screener to identify candidates, then do deep dive
2. **Check multiple timeframes**: Run analysis weekly to track score changes
3. **Diversify**: Don't rely on single metric - consider all aspects
4. **Verify data**: Double-check unusual metrics before trading
5. **Paper trade first**: Test strategy with virtual money before real trading
