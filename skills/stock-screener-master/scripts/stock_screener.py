#!/usr/bin/env python3
"""
Stock Screener Master - Multi-Indicator Stock Analysis Tool
多指标股票筛选分析工具

Features:
- 基本面分析 (PE, PS, ROE, Margins, Growth)
- 技术面分析 (Trend, RSI, Moving Averages)
- 情绪分析 (Tavily News + Fear & Greed)
- 8 Investor Masters Scoring
- Piotroski F-Score
- Comprehensive Rating System
"""

import os
import sys
import argparse
import json
import requests
from datetime import datetime, timedelta
from pathlib import Path

import pandas as pd
import numpy as np
import yfinance as yf
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "")

# Positive/Negative keywords for sentiment analysis
POSITIVE_WORDS = [
    'profit', 'growth', 'beat', 'surge', 'rally', 'boom', 'strong', 'gain', 'up', 'rise',
    'bull', 'outperform', 'exceed', 'record', 'soar', 'jump', 'momentum', 'upgrade',
    'positive', 'solid', 'robust', 'excellent', 'outstanding', 'breakthrough'
]

NEGATIVE_WORDS = [
    'loss', 'miss', 'fall', 'crash', 'decline', 'bear', 'weak', 'down', 'drop', 'sell',
    'short', 'underperform', 'disappoint', 'warning', 'concern', 'fear', 'worry', 'risk',
    'trouble', 'downgrade', 'negative', 'poor', 'struggle', 'challenge', 'headwind'
]


class StockScreener:
    """Multi-indicator stock screener and analyzer"""
    
    def __init__(self, symbol):
        self.symbol = symbol.upper()
        self.stock = yf.Ticker(symbol)
        self.info = self.stock.info
        self.hist = self.stock.history(period="1y")
        
    def get_basic_info(self):
        """Get basic stock information"""
        return {
            'symbol': self.symbol,
            'name': self.info.get('longName', 'N/A'),
            'sector': self.info.get('sector', 'N/A'),
            'industry': self.info.get('industry', 'N/A'),
            'market_cap': self.info.get('marketCap', 0),
            'current_price': self.info.get('currentPrice', self.info.get('regularMarketPrice', 0)),
            'fifty_two_week_low': self.info.get('fiftyTwoWeekLow', 0),
            'fifty_two_week_high': self.info.get('fiftyTwoWeekHigh', 0),
        }
    
    def analyze_fundamentals(self):
        """Analyze fundamental metrics"""
        info = self.info
        
        # Valuation metrics
        pe_trailing = info.get('trailingPE', 0)
        pe_forward = info.get('forwardPE', 0)
        ps = info.get('priceToSalesTrailing12Months', 0)
        pb = info.get('priceToBook', 0)
        
        # Profitability
        gross_margin = info.get('grossMargins', 0) * 100 if info.get('grossMargins') else 0
        operating_margin = info.get('operatingMargins', 0) * 100 if info.get('operatingMargins') else 0
        profit_margin = info.get('profitMargins', 0) * 100 if info.get('profitMargins') else 0
        roe = info.get('returnOnEquity', 0) * 100 if info.get('returnOnEquity') else 0
        
        # Growth
        revenue_growth = info.get('revenueGrowth', 0) * 100 if info.get('revenueGrowth') else 0
        earnings_growth = info.get('earningsGrowth', 0) * 100 if info.get('earningsGrowth') else 0
        
        # Financial health
        current_ratio = info.get('currentRatio', 0)
        debt_to_equity = info.get('debtToEquity', 0)
        
        return {
            'valuation': {
                'pe_trailing': pe_trailing,
                'pe_forward': pe_forward,
                'ps': ps,
                'pb': pb,
            },
            'profitability': {
                'gross_margin': gross_margin,
                'operating_margin': operating_margin,
                'profit_margin': profit_margin,
                'roe': roe,
            },
            'growth': {
                'revenue_growth': revenue_growth,
                'earnings_growth': earnings_growth,
            },
            'financial_health': {
                'current_ratio': current_ratio,
                'debt_to_equity': debt_to_equity,
            }
        }
    
    def analyze_technical(self):
        """Analyze technical indicators"""
        hist = self.hist
        if hist.empty:
            return None
            
        close = hist['Close']
        current_price = close.iloc[-1]
        
        # Moving averages
        ma_50 = close.rolling(50).mean().iloc[-1]
        ma_200 = close.rolling(200).mean().iloc[-1]
        
        # RSI
        delta = close.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        current_rsi = rsi.iloc[-1]
        
        # Trend score
        trend_score = 0
        if current_price > ma_50: trend_score += 2
        if current_price > ma_200: trend_score += 2
        if 40 < current_rsi < 70: trend_score += 1
        if current_price > close.iloc[-20:].mean(): trend_score += 1
        
        return {
            'current_price': current_price,
            'ma_50': ma_50,
            'ma_200': ma_200,
            'rsi': current_rsi,
            'above_ma_50': current_price > ma_50,
            'above_ma_200': current_price > ma_200,
            'trend_score': trend_score,
            'trend_rating': 'Strong' if trend_score >= 5 else 'Moderate' if trend_score >= 3 else 'Weak'
        }
    
    def fetch_tavily_sentiment(self):
        """Fetch news sentiment from Tavily"""
        if not TAVILY_API_KEY:
            return {'score': 50, 'source': 'Fallback', 'pos': 0, 'neg': 0}
        
        try:
            url = "https://api.tavily.com/search"
            headers = {"Content-Type": "application/json"}
            payload = {
                "api_key": TAVILY_API_KEY,
                "query": f"{self.symbol} {self.info.get('longName', '')} stock news",
                "search_depth": "basic",
                "max_results": 10
            }
            
            response = requests.post(url, json=payload, headers=headers, timeout=30)
            result = response.json()
            
            # Analyze sentiment
            all_content = ""
            if 'results' in result:
                for item in result['results'][:5]:
                    all_content += item.get('title', '') + " " + item.get('content', '')[:300] + " "
            
            content_lower = all_content.lower()
            pos_count = sum(1 for word in POSITIVE_WORDS if word in content_lower)
            neg_count = sum(1 for word in NEGATIVE_WORDS if word in content_lower)
            
            total = pos_count + neg_count
            if total == 0:
                return {'score': 50, 'source': 'Tavily', 'pos': 0, 'neg': 0}
            
            score = (pos_count / total) * 100
            return {
                'score': score,
                'source': 'Tavily',
                'pos': pos_count,
                'neg': neg_count
            }
            
        except Exception as e:
            print(f"Tavily API error: {e}")
            return {'score': 50, 'source': 'Error', 'pos': 0, 'neg': 0}
    
    def fetch_fear_greed(self):
        """Fetch CNN Fear & Greed Index"""
        try:
            url = "https://api.alternative.me/fng/?limit=1&format=json"
            response = requests.get(url, timeout=10)
            data = response.json()
            value = int(data['data'][0]['value'])
            classification = data['data'][0]['value_classification']
            return {'value': value, 'classification': classification}
        except:
            return {'value': 50, 'classification': 'Neutral'}
    
    def calculate_master_scores(self, fundamentals):
        """Calculate 8 investor master scores"""
        info = self.info
        fv = fundamentals
        
        # Buffett Score (Moat, ROE, Margins)
        buffett = 0
        if fv['profitability']['roe'] > 15: buffett += 2
        elif fv['profitability']['roe'] > 10: buffett += 1
        if fv['profitability']['gross_margin'] > 50: buffett += 2
        elif fv['profitability']['gross_margin'] > 30: buffett += 1
        if fv['growth']['revenue_growth'] > 15: buffett += 2
        elif fv['growth']['revenue_growth'] > 5: buffett += 1
        if fv['profitability']['profit_margin'] > 10: buffett += 2
        elif fv['profitability']['profit_margin'] > 5: buffett += 1
        if info.get('freeCashflow', 0) > 0: buffett += 2
        buffett = min(buffett, 10)
        
        # Peter Lynch Score (PEG)
        peg = fv['valuation']['pe_trailing'] / fv['growth']['revenue_growth'] if fv['growth']['revenue_growth'] > 0 else 999
        if peg < 0.5: lynch = 10
        elif peg < 1.0: lynch = 8
        elif peg < 1.5: lynch = 6
        elif peg < 2.0: lynch = 4
        else: lynch = 2
        
        # Graham Score (Value)
        graham = 0
        if fv['valuation']['pe_trailing'] < 15: graham += 2
        if fv['valuation']['pb'] < 1.5: graham += 2
        if fv['financial_health']['current_ratio'] > 2: graham += 2
        if info.get('totalRevenue', 0) > 0: graham += 2
        if fv['profitability']['profit_margin'] > 0: graham += 2
        
        # Others (simplified)
        dalio = 7 if fv['growth']['revenue_growth'] > 10 else 5
        munger = 10 - (3 if fv['financial_health']['debt_to_equity'] > 100 else 0) - (2 if fv['profitability']['profit_margin'] < 5 else 0)
        greenblatt = 8 if fv['profitability']['roe'] > 15 and fv['profitability']['profit_margin'] > 10 else 5
        templeton = 7 if fv['valuation']['pe_trailing'] < 30 else 5
        soros = 7 if fv['growth']['revenue_growth'] > 20 else 5
        
        return {
            'Buffett': buffett,
            'Lynch': lynch,
            'Graham': graham,
            'Dalio': dalio,
            'Munger': munger,
            'Greenblatt': greenblatt,
            'Templeton': templeton,
            'Soros': soros,
            'average': sum([buffett, lynch, graham, dalio, munger, greenblatt, templeton, soros]) / 8
        }
    
    def calculate_f_score(self, fundamentals):
        """Calculate Piotroski F-Score"""
        fv = fundamentals
        score = 0
        
        if fv['profitability']['profit_margin'] > 0: score += 1
        if self.info.get('freeCashflow', 0) > 0: score += 1
        if fv['profitability']['roe'] > 0: score += 1
        if fv['growth']['revenue_growth'] > 0: score += 1
        if fv['profitability']['gross_margin'] > 40: score += 1
        if fv['financial_health']['current_ratio'] > 1: score += 1
        
        return score
    
    def calculate_comprehensive_score(self, fundamentals, technical, sentiment, fg, masters, f_score):
        """Calculate comprehensive investment score"""
        fv = fundamentals
        
        # Fundamental score (0-10)
        fundamental_score = min((masters['Buffett'] + masters['Graham'] + masters['Lynch']) / 3, 10)
        
        # Technical score (0-10)
        technical_score = technical['trend_score'] * 10 / 6 if technical else 5
        
        # Sentiment score (0-10)
        sentiment_score = (sentiment['score'] / 10 + fg['value'] / 10) / 2
        
        # Growth score (0-10)
        growth_score = min(fv['growth']['revenue_growth'] / 3, 10)
        
        # Final weighted score (0-100)
        total = (
            fundamental_score * 30 +  # 30% fundamentals
            technical_score * 20 +     # 20% technical
            sentiment_score * 15 +     # 15% sentiment
            masters['average'] * 20 +  # 20% master scores
            f_score * 5 +              # 5% F-Score
            growth_score * 10          # 10% growth
        )
        
        return min(total, 100)
    
    def generate_report(self):
        """Generate comprehensive analysis report"""
        # Gather all data
        basic = self.get_basic_info()
        fundamentals = self.analyze_fundamentals()
        technical = self.analyze_technical()
        sentiment = self.fetch_tavily_sentiment()
        fg = self.fetch_fear_greed()
        masters = self.calculate_master_scores(fundamentals)
        f_score = self.calculate_f_score(fundamentals)
        total_score = self.calculate_comprehensive_score(fundamentals, technical, sentiment, fg, masters, f_score)
        
        # Determine rating
        if total_score >= 80: rating = "Strong Buy"
        elif total_score >= 65: rating = "Buy"
        elif total_score >= 50: rating = "Hold"
        elif total_score >= 35: rating = "Reduce"
        else: rating = "Sell"
        
        # Target price
        target = self.info.get('targetMedianPrice', basic['current_price'] * 1.1)
        upside = (target - basic['current_price']) / basic['current_price'] * 100
        
        report = {
            'symbol': self.symbol,
            'basic': basic,
            'fundamentals': fundamentals,
            'technical': technical,
            'sentiment': sentiment,
            'fear_greed': fg,
            'master_scores': masters,
            'f_score': f_score,
            'total_score': total_score,
            'rating': rating,
            'target_price': target,
            'upside': upside,
            'analysis_date': datetime.now().strftime('%Y-%m-%d %H:%M')
        }
        
        return report
    
    def print_report(self, report):
        """Print formatted report"""
        print("=" * 70)
        print(f"🎯 {report['symbol']} - 多指标股票筛选报告")
        print("=" * 70)
        
        # Basic info
        print(f"\n📊 基本信息")
        print("-" * 70)
        b = report['basic']
        print(f"  公司名称: {b['name']}")
        print(f"  行业: {b['industry']}")
        print(f"  当前价格: ${b['current_price']:.2f}")
        print(f"  市值: ${b['market_cap']/1e9:.2f}B" if b['market_cap'] else "  市值: N/A")
        print(f"  52周区间: ${b['fifty_two_week_low']:.2f} - ${b['fifty_two_week_high']:.2f}")
        
        # Fundamentals
        print(f"\n💰 基本面分析")
        print("-" * 70)
        f = report['fundamentals']
        print(f"  估值:")
        print(f"    • PE (TTM): {f['valuation']['pe_trailing']:.1f}")
        print(f"    • Forward PE: {f['valuation']['pe_forward']:.1f}")
        print(f"    • PS: {f['valuation']['ps']:.2f}")
        print(f"  盈利:")
        print(f"    • 毛利率: {f['profitability']['gross_margin']:.1f}%")
        print(f"    • ROE: {f['profitability']['roe']:.1f}%")
        print(f"  增长:")
        print(f"    • 营收增长: {f['growth']['revenue_growth']:.1f}%")
        print(f"    • 盈利增长: {f['growth']['earnings_growth']:.1f}%")
        
        # Technical
        if report['technical']:
            print(f"\n📈 技术面分析")
            print("-" * 70)
            t = report['technical']
            print(f"    • RSI (14): {t['rsi']:.1f}")
            print(f"    • 趋势评分: {t['trend_score']}/6 ({t['trend_rating']})")
            print(f"    • 50日均线: {'上方' if t['above_ma_50'] else '下方'}")
            print(f"    • 200日均线: {'上方' if t['above_ma_200'] else '下方'}")
        
        # Sentiment
        print(f"\n📰 情绪分析")
        print("-" * 70)
        print(f"    • 新闻情绪: {report['sentiment']['score']:.1f}/100")
        print(f"    • Fear & Greed: {report['fear_greed']['value']}/100 ({report['fear_greed']['classification']})")
        
        # Master scores
        print(f"\n👑 投资大师评分")
        print("-" * 70)
        m = report['master_scores']
        for name, score in m.items():
            if name != 'average':
                print(f"    • {name}: {score}/10")
        print(f"    • 平均分: {m['average']:.1f}/10")
        
        # Final score
        print(f"\n🏆 综合评分")
        print("=" * 70)
        print(f"    • Piotroski F-Score: {report['f_score']}/9")
        print(f"    • 综合评分: {report['total_score']:.1f}/100")
        print(f"    • 投资评级: {report['rating']}")
        print(f"    • 目标价: ${report['target_price']:.2f} ({report['upside']:+.1f}%)")
        
        print(f"\n分析时间: {report['analysis_date']}")
        print("=" * 70)


def main():
    parser = argparse.ArgumentParser(description='Multi-Indicator Stock Screener')
    parser.add_argument('symbol', help='Stock symbol (e.g., AAPL, TSLA)')
    parser.add_argument('--json', action='store_true', help='Output as JSON')
    parser.add_argument('--output', '-o', help='Output file path')
    
    args = parser.parse_args()
    
    print(f"\nAnalyzing {args.symbol}...")
    print("This may take a moment...\n")
    
    screener = StockScreener(args.symbol)
    report = screener.generate_report()
    
    if args.json:
        output = json.dumps(report, indent=2, default=str)
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output)
            print(f"Report saved to {args.output}")
        else:
            print(output)
    else:
        screener.print_report(report)
        
        if args.output:
            with open(args.output, 'w') as f:
                json.dump(report, f, indent=2, default=str)
            print(f"\nJSON report saved to {args.output}")


if __name__ == '__main__':
    main()
