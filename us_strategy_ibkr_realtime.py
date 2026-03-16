#!/usr/bin/env python3
"""
美股量化选股策略 - IBKR实时数据版 + Tavily舆情 + Fear&Greed指数
改编自A股9分策略，使用IBKR实时数据而非yfinance
"""

import os
import sys
import requests
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from ib_insync import IB, Stock, util

# ============== IBKR配置 ==============
TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 100  # 策略专用ID

# ============== 策略参数 ==============
MIN_MARKET_CAP = 1_000_000_000      # 最小市值 10亿美元
MIN_AVG_VOLUME = 1_000_000          # 最小日均成交量 100万股
HISTORY_DAYS = 80                   # 获取多少天历史数据计算MA60


class USStockStrategyIBKR:
    """美股量化策略 - IBKR实时数据版"""
    
    def __init__(self):
        self.ib = IB()
        self.fear_greed_data = None
        self.market_sentiment = None
        self.connected = False
        
    def connect(self):
        """连接IBKR"""
        try:
            print("🔌 连接IBKR TWS...")
            self.ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID, timeout=10)
            self.connected = True
            print(f"✅ 已连接 | 服务器版本: {self.ib.client.serverVersion()}\n")
            return True
        except Exception as e:
            print(f"❌ 连接失败: {e}")
            print("请确保TWS已启动并登录")
            return False
    
    def disconnect(self):
        """断开连接"""
        if self.connected and self.ib.isConnected():
            self.ib.disconnect()
            print("👋 已断开IBKR")
    
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
            }
            
            # 市场情绪判断
            if latest >= 75:
                self.market_sentiment = 'extreme_greed'
            elif latest >= 55:
                self.market_sentiment = 'greed'
            elif latest >= 45:
                self.market_sentiment = 'neutral'
            elif latest >= 25:
                self.market_sentiment = 'fear'
            else:
                self.market_sentiment = 'extreme_fear'
                
            return self.fear_greed_data
            
        except Exception as e:
            print(f"⚠️ Fear&Greed获取失败: {e}")
            return None
    
    # ========== 2. Tavily 舆情分析 ==========
    def fetch_news_sentiment(self, symbol):
        """使用Tavily获取股票舆情 - 调用本地skill"""
        try:
            # 读取TAVILY_API_KEY
            tavily_key = os.getenv('TAVILY_API_KEY', '')
            if not tavily_key:
                # 尝试从config读取
                import subprocess
                result = subprocess.run(
                    ['grep', '-r', 'TAVILY_API_KEY', '~/.openclaw/config*'],
                    capture_output=True, text=True
                )
                if 'TAVILY' in result.stdout:
                    print(f"   Tavily key found in config")
            
            if not tavily_key:
                return {'score': 0.5, 'articles': 0, 'summary': '未配置TAVILY_API_KEY'}
            
            url = "https://api.tavily.com/search"
            headers = {"Authorization": f"Bearer {tavily_key}"}
            
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
            
            # 情感分析
            positive_keywords = ['buy', 'upgrade', 'bullish', 'beat', 'growth', 'strong', 'outperform', 'buying']
            negative_keywords = ['sell', 'downgrade', 'bearish', 'miss', 'drop', 'weak', 'underperform', 'selling']
            
            total_mentions = 0
            positive_count = 0
            negative_count = 0
            headlines = []
            
            for result in results.get('results', [])[:5]:  # 只取前5条
                content = (result.get('title', '') + ' ' + result.get('content', '')).lower()
                total_mentions += 1
                headlines.append(result.get('title', '')[:60])
                
                pos_found = any(word in content for word in positive_keywords)
                neg_found = any(word in content for word in negative_keywords)
                
                if pos_found and not neg_found:
                    positive_count += 1
                elif neg_found and not pos_found:
                    negative_count += 1
            
            # 计算情感分数
            if total_mentions > 0:
                sentiment_score = 0.5 + (positive_count - negative_count) / total_mentions * 0.5
                sentiment_score = max(0, min(1, sentiment_score))
            else:
                sentiment_score = 0.5
            
            return {
                'score': sentiment_score,
                'articles': total_mentions,
                'positive': positive_count,
                'negative': negative_count,
                'headlines': headlines
            }
            
        except Exception as e:
            print(f"⚠️ Tavily舆情获取失败: {e}")
            return {'score': 0.5, 'articles': 0, 'headlines': []}
    
    # ========== 3. IBKR实时数据获取 ==========
    def fetch_ibkr_data(self, symbol):
        """从IBKR获取实时行情和历史数据"""
        try:
            # 创建合约
            contract = Stock(symbol, 'SMART', 'USD')
            qualified = self.ib.qualifyContracts(contract)
            if not qualified:
                print(f"❌ {symbol} 合约验证失败")
                return None
            
            # 获取实时报价
            ticker = self.ib.reqMktData(contract, '', False, False)
            self.ib.sleep(2)
            
            current_price = ticker.last or ticker.close or ticker.ask
            if not current_price:
                print(f"⚠️ {symbol} 无法获取当前价格")
                return None
            
            bid = ticker.bid
            ask = ticker.ask
            volume = ticker.volume
            
            # 获取历史数据计算均线 (80天，足够MA60)
            print(f"   获取历史数据...")
            bars = self.ib.reqHistoricalData(
                contract,
                endDateTime='',
                durationStr=f'{HISTORY_DAYS} D',
                barSizeSetting='1 day',
                whatToShow='TRADES',
                useRTH=True
            )
            
            if not bars or len(bars) < 60:
                print(f"⚠️ {symbol} 历史数据不足 ({len(bars) if bars else 0}天)")
                return None
            
            # 转换为DataFrame计算指标
            df = util.df(bars)
            df['close'] = df['close'].astype(float)
            df['volume'] = df['volume'].astype(float)
            
            # 计算均线
            df['MA5'] = df['close'].rolling(5).mean()
            df['MA10'] = df['close'].rolling(10).mean()
            df['MA20'] = df['close'].rolling(20).mean()
            df['MA60'] = df['close'].rolling(60).mean()
            
            # 计算MACD
            exp1 = df['close'].ewm(span=12, adjust=False).mean()
            exp2 = df['close'].ewm(span=26, adjust=False).mean()
            df['MACD'] = exp1 - exp2
            df['Signal'] = df['MACD'].ewm(span=9, adjust=False).mean()
            
            # 计算RSI
            delta = df['close'].diff()
            gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
            loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
            rs = gain / loss
            df['RSI'] = 100 - (100 / (1 + rs))
            
            # 成交量均线
            df['Volume_MA20'] = df['volume'].rolling(20).mean()
            
            # 最新数据
            latest = df.iloc[-1]
            prev = df.iloc[-2]
            prev2 = df.iloc[-3] if len(df) > 2 else prev
            
            # 计算日涨跌
            daily_change = (current_price - df['close'].iloc[-2]) / df['close'].iloc[-2] * 100
            
            # 获取账户中的市值信息 (从positions获取，如果没有则为0)
            market_cap = 0  # IBKR不直接提供市值，需要从其他来源
            avg_volume = df['volume'].tail(20).mean()
            
            self.ib.cancelMktData(contract)
            
            return {
                'symbol': symbol,
                'price': current_price,
                'bid': bid,
                'ask': ask,
                'market_cap': market_cap,  # 需要从外部API获取
                'avg_volume': avg_volume,
                'volume': volume,
                'ma5': latest['MA5'],
                'ma10': latest['MA10'],
                'ma20': latest['MA20'],
                'ma60': latest['MA60'],
                'macd': latest['MACD'],
                'macd_signal': latest['Signal'],
                'rsi': latest['RSI'],
                'volume_ma20': latest['Volume_MA20'],
                'daily_change': daily_change,
                'prev_macd': prev['MACD'],
                'prev_signal': prev['Signal'],
                'data_time': ticker.time
            }
            
        except Exception as e:
            print(f"❌ {symbol} 数据获取失败: {e}")
            import traceback
            traceback.print_exc()
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
            details.append("⚠️ MACD在信号线上方 (+0.5)")
        
        # 4. RSI 40-70 (1分)
        rsi = data['rsi']
        if 40 <= rsi <= 70:
            score += 1
            details.append(f"✅ RSI健康 {rsi:.1f} (+1)")
        elif 30 <= rsi < 40:
            score += 0.5
            details.append(f"⚠️ RSI偏低 {rsi:.1f} (+0.5)")
        
        # 5. 流动性检查 - 日均成交量 (1分)
        if data['avg_volume'] >= MIN_AVG_VOLUME:
            score += 1
            details.append(f"✅ 流动性充足 {data['avg_volume']/1e6:.1f}M/日 (+1)")
        
        # 6. 成交量放大 (1分)
        if data['volume'] and data['volume'] > data['volume_ma20'] * 1.2:
            score += 1
            details.append(f"✅ 成交量放大 {data['volume']/data['volume_ma20']:.1f}x (+1)")
        
        # 7. 今日涨幅>0.5% (0.5分)
        if data['daily_change'] > 0.5:
            score += 0.5
            details.append(f"✅ 日涨{data['daily_change']:.1f}% (+0.5)")
        
        # 8. 价格在MA60之上 (1分)
        if data['price'] > data['ma60']:
            score += 1
            details.append("✅ 价格>MA60 (+1)")
        
        # === 情绪面评分（4分）===
        
        # 9. Tavily舆情 (2分)
        sentiment = news_sentiment.get('score', 0.5)
        if sentiment >= 0.7:
            score += 2
            details.append(f"✅ 舆情积极 {sentiment:.0%} (+2)")
        elif sentiment >= 0.5:
            score += 1
            details.append(f"⚠️ 舆情中性 {sentiment:.0%} (+1)")
        elif sentiment < 0.3:
            details.append(f"❌ 舆情负面 {sentiment:.0%} (+0)")
        
        # 10. Fear&Greed市场时机 (2分)
        if self.fear_greed_data:
            fg_score = self.fear_greed_data['score']
            if fg_score <= 30:  # 极恐惧
                score += 2
                details.append(f"✅ 市场极度恐惧 {fg_score} (+2)")
            elif fg_score <= 45:  # 恐惧
                score += 1
                details.append(f"✅ 市场恐惧 {fg_score} (+1)")
            elif fg_score >= 75:  # 极贪婪
                score -= 1
                details.append(f"⚠️ 市场极度贪婪 {fg_score} (-1)")
        
        return score, details
    
    # ========== 5. 执行分析 ==========
    def analyze_stock(self, symbol):
        """分析单只股票"""
        print(f"\n{'='*60}")
        print(f"📊 分析股票: {symbol}")
        print('='*60)
        
        # 获取IBKR数据
        print("🔍 获取IBKR实时数据...")
        tech_data = self.fetch_ibkr_data(symbol)
        if not tech_data:
            print(f"❌ 无法获取 {symbol} 数据")
            return None
        
        # 获取舆情
        print("📰 获取Tavily舆情...")
        news_data = self.fetch_news_sentiment(symbol)
        
        # 计算评分
        score, details = self.calculate_score(tech_data, news_data)
        
        # 输出结果
        print(f"\n💰 当前价格: ${tech_data['price']:.2f} (Bid: ${tech_data['bid']}, Ask: ${tech_data['ask']})")
        print(f"📈 日涨跌: {tech_data['daily_change']:.2f}%")
        print(f"⏱️  数据时间: {tech_data['data_time']}")
        print(f"📰 舆情: {news_data['score']:.0%} (基于{news_data['articles']}篇新闻)")
        
        if news_data.get('headlines'):
            print(f"    headlines: {news_data['headlines'][0]}...")
        
        if self.fear_greed_data:
            print(f"😨 Fear&Greed: {self.fear_greed_data['score']} ({self.fear_greed_data['rating']})")
        
        print(f"\n📝 评分详情:")
        for d in details:
            print(f"   {d}")
        
        print(f"\n{'='*60}")
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
        print('='*60)
        
        return {
            'symbol': symbol,
            'score': score,
            'rating': rating,
            'price': tech_data['price'],
            'daily_change': tech_data['daily_change'],
            'rsi': tech_data['rsi'],
            'details': details
        }


def main():
    """主函数"""
    strategy = USStockStrategyIBKR()
    
    # 连接IBKR
    if not strategy.connect():
        return
    
    try:
        # 获取市场情绪
        print("🔍 获取Fear&Greed指数...")
        fg = strategy.fetch_fear_greed_index()
        if fg:
            print(f"📊 当前市场情绪: {fg['score']} - {fg['rating']}")
            print(f"💡 市场状态: {strategy.market_sentiment}\n")
        
        # 分析股票列表
        symbols = ['AAPL', 'AMD', 'NVDA', 'TSLA', 'MSFT', 'GOOGL', 'META', 'AMZN']
        
        results = []
        for symbol in symbols:
            result = strategy.analyze_stock(symbol)
            if result:
                results.append(result)
            print()  # 空行分隔
        
        # 排序输出
        print(f"{'='*70}")
        print("📋 综合排名 (实时数据 from IBKR):")
        print('='*70)
        
        results.sort(key=lambda x: x['score'], reverse=True)
        print(f"{'排名':<4} {'代码':<8} {'评分':<6} {'价格':<10} {'日涨跌':<8} {'RSI':<6} {'评级'}")
        print('-'*70)
        
        for i, r in enumerate(results, 1):
            print(f"{i:<4} {r['symbol']:<8} {r['score']:<6.1f} ${r['price']:<9.2f} "
                  f"{r['daily_change']:<7.1f}% {r['rsi']:<5.1f} {r['rating']}")
        
        print('='*70)
        
        # 输出最佳推荐
        if results and results[0]['score'] >= 7:
            best = results[0]
            print(f"\n🎯 今日推荐: {best['symbol']} ({best['rating']})")
            print(f"   评分: {best['score']}/12 | 价格: ${best['price']:.2f}")
        
    finally:
        strategy.disconnect()


if __name__ == '__main__':
    main()
