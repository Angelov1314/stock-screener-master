#!/usr/bin/env python3
"""
美股量化选股策略 + Tavily舆情 + Fear&Greed指数
改编自A股9分策略，适配美股市场特点
"""

import os
import requests
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# ============== 配置 ==============
TAVILY_API_KEY = os.getenv('TAVILY_API_KEY', '')
MIN_MARKET_CAP = 1_000_000_000  # 最小市值 10亿美元
MIN_AVG_VOLUME = 1_000_000      # 最小日均成交量 100万股

class USStockStrategy:
    """美股量化策略评分系统"""
    
    def __init__(self):
        self.fear_greed_data = None
        self.market_sentiment = None
        
    # ========== 1. Fear & Greed 指数 ==========
    def fetch_fear_greed_index(self):
        """获取CNN恐惧贪婪指数"""
        try:
            url = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata"
            headers = {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
            }
            resp = requests.get(url, headers=headers, timeout=10)
            data = resp.json()
            
            latest = data['fear_and_greed']['score']
            rating = data['fear_and_greed']['rating']
            
            self.fear_greed_data = {
                'score': latest,
                'rating': rating,
                'previous_close': data['fear_and_greed']['previous_close'],
                'timestamp': data['fear_and_greed']['timestamp']
            }
            
            # 市场情绪判断
            if latest >= 75:
                self.market_sentiment = 'extreme_greed'  # 极贪婪 - 谨慎
            elif latest >= 55:
                self.market_sentiment = 'greed'  # 贪婪
            elif latest >= 45:
                self.market_sentiment = 'neutral'  # 中性
            elif latest >= 25:
                self.market_sentiment = 'fear'  # 恐惧 - 机会
            else:
                self.market_sentiment = 'extreme_fear'  # 极恐惧 - 买入机会
                
            return self.fear_greed_data
            
        except Exception as e:
            print(f"⚠️ Fear&Greed获取失败: {e}")
            return None
    
    # ========== 2. Tavily 舆情分析 ==========
    def fetch_news_sentiment(self, symbol):
        """使用Tavily获取股票舆情"""
        if not TAVILY_API_KEY:
            return {'score': 0.5, 'summary': '未配置TAVILY_API_KEY'}
        
        try:
            url = "https://api.tavily.com/search"
            headers = {"Authorization": f"Bearer {TAVILY_API_KEY}"}
            
            # 查询股票相关新闻
            query = f"{symbol} stock news analysis"
            body = {
                "query": query,
                "time_range": "last_24h",
                "search_depth": 3,
                "include_domains": [
                    "bloomberg.com", "reuters.com", "cnbc.com", 
                    "marketwatch.com", "seekingalpha.com", "finance.yahoo.com"
                ]
            }
            
            resp = requests.post(url, headers=headers, json=body, timeout=15)
            results = resp.json()
            
            # 简单情感分析（基于关键词）
            positive_keywords = ['buy', 'upgrade', 'bullish', 'beat', 'growth', 'strong', 'outperform']
            negative_keywords = ['sell', 'downgrade', 'bearish', 'miss', 'drop', 'weak', 'underperform']
            
            total_mentions = 0
            positive_count = 0
            negative_count = 0
            
            for result in results.get('results', []):
                content = (result.get('title', '') + ' ' + result.get('content', '')).lower()
                total_mentions += 1
                
                for word in positive_keywords:
                    if word in content:
                        positive_count += 1
                        break
                for word in negative_keywords:
                    if word in content:
                        negative_count += 1
                        break
            
            # 计算情感分数 0-1
            if total_mentions > 0:
                sentiment_score = (positive_count - negative_count) / total_mentions + 0.5
                sentiment_score = max(0, min(1, sentiment_score))  # 限制在0-1
            else:
                sentiment_score = 0.5
            
            return {
                'score': sentiment_score,
                'articles': total_mentions,
                'positive': positive_count,
                'negative': negative_count
            }
            
        except Exception as e:
            print(f"⚠️ Tavily舆情获取失败: {e}")
            return {'score': 0.5, 'articles': 0}
    
    # ========== 3. 技术分析指标 ==========
    def fetch_technical_data(self, symbol):
        """获取股票技术指标"""
        try:
            ticker = yf.Ticker(symbol)
            
            # 获取3个月数据（足够计算MA60）
            hist = ticker.history(period='3mo')
            if hist.empty or len(hist) < 60:
                return None
            
            info = ticker.info
            
            # 基本信息
            current_price = hist['Close'][-1]
            market_cap = info.get('marketCap', 0)
            avg_volume = hist['Volume'].mean()
            
            # 均线计算
            hist['MA5'] = hist['Close'].rolling(5).mean()
            hist['MA10'] = hist['Close'].rolling(10).mean()
            hist['MA20'] = hist['Close'].rolling(20).mean()
            hist['MA60'] = hist['Close'].rolling(60).mean()
            
            # MACD
            exp1 = hist['Close'].ewm(span=12, adjust=False).mean()
            exp2 = hist['Close'].ewm(span=26, adjust=False).mean()
            hist['MACD'] = exp1 - exp2
            hist['Signal'] = hist['MACD'].ewm(span=9, adjust=False).mean()
            
            # RSI
            delta = hist['Close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
            rs = gain / loss
            hist['RSI'] = 100 - (100 / (1 + rs))
            
            # 成交量变化
            hist['Volume_MA20'] = hist['Volume'].rolling(20).mean()
            
            latest = hist.iloc[-1]
            prev = hist.iloc[-2]
            
            return {
                'symbol': symbol,
                'price': current_price,
                'market_cap': market_cap,
                'avg_volume': avg_volume,
                'ma5': latest['MA5'],
                'ma10': latest['MA10'],
                'ma20': latest['MA20'],
                'ma60': latest['MA60'],
                'macd': latest['MACD'],
                'macd_signal': latest['Signal'],
                'rsi': latest['RSI'],
                'volume': latest['Volume'],
                'volume_ma20': latest['Volume_MA20'],
                'daily_change': (current_price - hist['Close'][-2]) / hist['Close'][-2] * 100,
                'prev_macd': prev['MACD'],
                'prev_signal': prev['Signal']
            }
            
        except Exception as e:
            print(f"⚠️ {symbol} 数据获取失败: {e}")
            return None
    
    # ========== 4. 评分系统 ==========
    def calculate_score(self, data, news_sentiment):
        """计算综合评分（满分12分）"""
        score = 0
        details = []
        
        if not data:
            return 0, []
        
        # === 技术面评分（8分）===
        
        # 1. 价格在5日均线之上 (1分)
        if data['price'] > data['ma5']:
            score += 1
            details.append("✅ 价格>MA5 (+1)")
        
        # 2. 均线多头排列 MA5>MA10>MA20 (1.5分)
        if data['ma5'] > data['ma10'] > data['ma20']:
            score += 1.5
            details.append("✅ MA多头排列 (+1.5)")
        
        # 3. MACD金叉 (1分)
        macd_cross = data['prev_macd'] < data['prev_signal'] and data['macd'] > data['macd_signal']
        if macd_cross:
            score += 1
            details.append("✅ MACD金叉 (+1)")
        elif data['macd'] > data['macd_signal']:
            score += 0.5
            details.append("⚠️ MACD在信号线上方但非金叉 (+0.5)")
        
        # 4. RSI 40-70（美股用更宽范围）(1分)
        rsi = data['rsi']
        if 40 <= rsi <= 70:
            score += 1
            details.append(f"✅ RSI健康 {rsi:.1f} (+1)")
        elif 30 <= rsi < 40:
            score += 0.5
            details.append(f"⚠️ RSI偏低 {rsi:.1f} (+0.5)")
        
        # 5. 市值>10亿（美股流动性）(1分)
        if data['market_cap'] >= MIN_MARKET_CAP:
            score += 1
            details.append(f"✅ 市值充足 ${data['market_cap']/1e9:.1f}B (+1)")
        
        # 6. 日均成交量>100万股 (1分)
        if data['avg_volume'] >= MIN_AVG_VOLUME:
            score += 1
            details.append(f"✅ 流动性充足 {data['avg_volume']/1e6:.1f}M股/日 (+1)")
        
        # 7. 今日涨幅>0.5%（美股波动较小）(0.5分)
        if data['daily_change'] > 0.5:
            score += 0.5
            details.append(f"✅ 日涨{data['daily_change']:.1f}% (+0.5)")
        
        # 8. 成交量放大 (>20日均量20%) (1分)
        if data['volume'] > data['volume_ma20'] * 1.2:
            score += 1
            details.append(f"✅ 成交量放大 {data['volume']/data['volume_ma20']:.1f}x (+1)")
        
        # 9. 价格在MA60之上 (1分)
        if data['price'] > data['ma60']:
            score += 1
            details.append("✅ 价格>MA60 (+1)")
        
        # === 情绪面评分（4分）===
        
        # 10. Tavily舆情 (2分)
        sentiment = news_sentiment.get('score', 0.5)
        if sentiment >= 0.7:
            score += 2
            details.append(f"✅ 舆情积极 {sentiment:.0%} (+2)")
        elif sentiment >= 0.5:
            score += 1
            details.append(f"⚠️ 舆情中性 {sentiment:.0%} (+1)")
        elif sentiment < 0.3:
            details.append(f"❌ 舆情负面 {sentiment:.0%} (+0)")
        
        # 11. Fear&Greed市场时机 (2分)
        if self.fear_greed_data:
            fg_score = self.fear_greed_data['score']
            if fg_score <= 30:  # 极恐惧 - 买入好时机
                score += 2
                details.append(f"✅ 市场极度恐惧 {fg_score} (+2)")
            elif fg_score <= 45:  # 恐惧
                score += 1
                details.append(f"✅ 市场恐惧 {fg_score} (+1)")
            elif fg_score >= 75:  # 极贪婪 - 谨慎
                score -= 1
                details.append(f"⚠️ 市场极度贪婪 {fg_score} (-1)")
        
        return score, details
    
    # ========== 5. 执行分析 ==========
    def analyze_stock(self, symbol):
        """分析单只股票"""
        print(f"\n{'='*50}")
        print(f"📊 分析股票: {symbol}")
        print('='*50)
        
        # 获取数据
        tech_data = self.fetch_technical_data(symbol)
        if not tech_data:
            print(f"❌ 无法获取 {symbol} 数据")
            return None
        
        news_data = self.fetch_news_sentiment(symbol)
        
        # 计算评分
        score, details = self.calculate_score(tech_data, news_data)
        
        # 输出结果
        print(f"\n💰 当前价格: ${tech_data['price']:.2f}")
        print(f"📈 日涨跌: {tech_data['daily_change']:.2f}%")
        print(f"📊 市值: ${tech_data['market_cap']/1e9:.2f}B")
        print(f"📰 舆情: {news_data['score']:.0%} (基于{news_data['articles']}篇新闻)")
        
        if self.fear_greed_data:
            print(f"😨 Fear&Greed: {self.fear_greed_data['score']} ({self.fear_greed_data['rating']})")
        
        print(f"\n📝 评分详情:")
        for d in details:
            print(f"   {d}")
        
        print(f"\n{'='*50}")
        print(f"🏆 总分: {score}/12")
        
        # 评级
        if score >= 9:
            rating = "⭐⭐⭐ 强烈买入"
        elif score >= 7:
            rating = "⭐⭐ 买入"
        elif score >= 5:
            rating = "⭐ 关注"
        else:
            rating = "❌ 观望"
        
        print(f"📋 评级: {rating}")
        print('='*50)
        
        return {
            'symbol': symbol,
            'score': score,
            'rating': rating,
            'price': tech_data['price'],
            'details': details
        }


def main():
    """主函数"""
    strategy = USStockStrategy()
    
    # 获取市场整体情绪
    print("🔍 获取Fear&Greed指数...")
    fg = strategy.fetch_fear_greed_index()
    if fg:
        print(f"📊 当前市场情绪: {fg['score']} - {fg['rating']}")
        print(f"💡 建议: {strategy.market_sentiment}")
    
    # 分析股票列表
    symbols = ['AAPL', 'AMD', 'NVDA', 'TSLA', 'MSFT', 'GOOGL']
    
    results = []
    for symbol in symbols:
        result = strategy.analyze_stock(symbol)
        if result:
            results.append(result)
    
    # 排序输出
    print(f"\n{'='*60}")
    print("📋 综合排名:")
    print('='*60)
    
    results.sort(key=lambda x: x['score'], reverse=True)
    for i, r in enumerate(results, 1):
        print(f"{i}. {r['symbol']:6} | {r['score']:5.1f}分 | ${r['price']:8.2f} | {r['rating']}")
    
    print('='*60)


if __name__ == '__main__':
    main()
