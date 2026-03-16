#!/usr/bin/env python3
"""
美股量化策略 - 简化版（分析3只股票）
"""

import os
import requests
from datetime import datetime
from ib_insync import IB, Stock, util

TWS_HOST = '127.0.0.1'
TWS_PORT = 7496
CLIENT_ID = 101

def get_fear_greed():
    """获取恐惧贪婪指数"""
    try:
        url = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata"
        headers = {'User-Agent': 'Mozilla/5.0'}
        resp = requests.get(url, headers=headers, timeout=10)
        data = resp.json()
        score = data['fear_and_greed']['score']
        rating = data['fear_and_greed']['rating']
        return score, rating
    except:
        return None, None

def get_tavily_sentiment(symbol):
    """获取舆情"""
    try:
        key = os.getenv('TAVILY_API_KEY', '')
        if not key:
            return 0.5, 0
        
        url = "https://api.tavily.com/search"
        headers = {"Authorization": f"Bearer {key}"}
        body = {
            "query": f"{symbol} stock",
            "time_range": "last_24h",
            "search_depth": 2
        }
        resp = requests.post(url, headers=headers, json=body, timeout=10)
        results = resp.json()
        
        pos_words = ['buy', 'upgrade', 'bullish', 'beat', 'growth', 'strong']
        neg_words = ['sell', 'downgrade', 'bearish', 'miss', 'drop', 'weak']
        
        total, pos, neg = 0, 0, 0
        for r in results.get('results', [])[:3]:
            text = (r.get('title','') + ' ' + r.get('content','')).lower()
            total += 1
            if any(w in text for w in pos_words): pos += 1
            if any(w in text for w in neg_words): neg += 1
        
        score = 0.5 + (pos - neg) / max(total, 1) * 0.5
        return max(0, min(1, score)), total
    except:
        return 0.5, 0

def analyze_stock(ib, symbol, fg_score):
    """分析单只股票"""
    print(f"\n{'='*50}")
    print(f"📊 {symbol}")
    print('='*50)
    
    # 获取合约
    contract = Stock(symbol, 'SMART', 'USD')
    if not ib.qualifyContracts(contract):
        print(f"❌ 合约失败")
        return None
    
    # 实时报价
    ticker = ib.reqMktData(contract, '', False, False)
    ib.sleep(2)
    
    price = ticker.last or ticker.close
    if not price:
        print(f"⚠️ 无价格数据")
        return None
    
    print(f"💰 价格: ${price:.2f} (Bid: ${ticker.bid}, Ask: ${ticker.ask})")
    print(f"⏱️  时间: {ticker.time}")
    
    # 历史数据
    print("📈 获取历史数据...")
    bars = ib.reqHistoricalData(
        contract, endDateTime='', durationStr='80 D',
        barSizeSetting='1 day', whatToShow='TRADES', useRTH=True
    )
    
    if not bars or len(bars) < 60:
        print(f"⚠️ 历史数据不足: {len(bars) if bars else 0}天")
        ib.cancelMktData(contract)
        return None
    
    # 计算指标
    df = util.df(bars)
    df['close'] = df['close'].astype(float)
    
    # 均线
    ma5 = df['close'].tail(5).mean()
    ma10 = df['close'].tail(10).mean()
    ma20 = df['close'].tail(20).mean()
    ma60 = df['close'].tail(60).mean()
    
    # MACD
    exp1 = df['close'].ewm(span=12, adjust=False).mean()
    exp2 = df['close'].ewm(span=26, adjust=False).mean()
    macd = (exp1 - exp2).iloc[-1]
    signal = (exp1 - exp2).ewm(span=9, adjust=False).mean().iloc[-1]
    prev_macd = (exp1 - exp2).iloc[-2]
    prev_signal = (exp1 - exp2).ewm(span=9, adjust=False).mean().iloc[-2]
    
    # RSI
    delta = df['close'].diff()
    gain = delta.where(delta > 0, 0).rolling(14).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(14).mean()
    rs = gain / loss
    rsi = (100 - (100 / (1 + rs))).iloc[-1]
    
    # 日涨跌
    daily_change = (price - df['close'].iloc[-2]) / df['close'].iloc[-2] * 100
    
    # 成交量
    avg_volume = df['volume'].tail(20).mean()
    
    ib.cancelMktData(contract)
    
    # 舆情
    print("📰 获取舆情...")
    sentiment, articles = get_tavily_sentiment(symbol)
    print(f"   舆情分数: {sentiment:.0%} (基于{articles}篇)")
    
    # 评分
    score = 0
    details = []
    
    if price > ma5:
        score += 1
        details.append("✅ 价格>MA5 (+1)")
    
    if ma5 > ma10 > ma20:
        score += 1.5
        details.append("✅ MA多头排列 (+1.5)")
    
    if prev_macd < prev_signal and macd > signal:
        score += 1
        details.append("✅ MACD金叉 (+1)")
    elif macd > signal:
        score += 0.5
        details.append("⚠️ MACD>信号线 (+0.5)")
    
    if 40 <= rsi <= 70:
        score += 1
        details.append(f"✅ RSI健康 {rsi:.1f} (+1)")
    
    if avg_volume >= 1_000_000:
        score += 1
        details.append(f"✅ 流动性充足 ({avg_volume/1e6:.1f}M) (+1)")
    
    if daily_change > 0.5:
        score += 0.5
        details.append(f"✅ 日涨{daily_change:.1f}% (+0.5)")
    
    if price > ma60:
        score += 1
        details.append("✅ 价格>MA60 (+1)")
    
    # 舆情
    if sentiment >= 0.7:
        score += 2
        details.append(f"✅ 舆情积极 (+2)")
    elif sentiment >= 0.5:
        score += 1
        details.append(f"⚠️ 舆情中性 (+1)")
    
    # Fear&Greed
    if fg_score and fg_score <= 30:
        score += 2
        details.append(f"✅ 市场极度恐惧 {fg_score} (+2)")
    elif fg_score and fg_score <= 45:
        score += 1
        details.append(f"✅ 市场恐惧 {fg_score} (+1)")
    elif fg_score and fg_score >= 75:
        score -= 1
        details.append(f"⚠️ 市场贪婪 {fg_score} (-1)")
    
    # 输出
    print(f"\n📊 指标:")
    print(f"   MA5: ${ma5:.2f}, MA10: ${ma10:.2f}, MA20: ${ma20:.2f}, MA60: ${ma60:.2f}")
    print(f"   MACD: {macd:.3f}, Signal: {signal:.3f}")
    print(f"   RSI: {rsi:.1f}")
    print(f"   日涨跌: {daily_change:.2f}%")
    
    print(f"\n📝 评分:")
    for d in details:
        print(f"   {d}")
    
    # 评级
    if score >= 9:
        rating = "⭐⭐⭐ 强烈买入"
    elif score >= 7:
        rating = "⭐⭐ 买入"
    elif score >= 5:
        rating = "⭐ 关注"
    else:
        rating = "❌ 观望"
    
    print(f"\n🏆 总分: {score}/12 | {rating}")
    
    return {
        'symbol': symbol,
        'score': score,
        'rating': rating,
        'price': price,
        'change': daily_change,
        'rsi': rsi
    }

def main():
    print("🔌 连接IBKR...")
    ib = IB()
    try:
        ib.connect(TWS_HOST, TWS_PORT, clientId=CLIENT_ID, timeout=10)
        print(f"✅ 已连接\n")
        
        # Fear&Greed
        fg_score, fg_rating = get_fear_greed()
        if fg_score:
            print(f"😨 Fear&Greed: {fg_score} ({fg_rating})\n")
        
        # 分析3只股票
        symbols = ['AAPL', 'NVDA', 'AMD']
        results = []
        
        for sym in symbols:
            result = analyze_stock(ib, sym, fg_score)
            if result:
                results.append(result)
        
        # 排名
        print(f"\n{'='*50}")
        print("📋 排名:")
        print('='*50)
        results.sort(key=lambda x: x['score'], reverse=True)
        for i, r in enumerate(results, 1):
            print(f"{i}. {r['symbol']:6} {r['score']:5.1f}分  ${r['price']:.2f}  {r['rating']}")
        
        if results and results[0]['score'] >= 7:
            print(f"\n🎯 推荐: {results[0]['symbol']}")
        
    except Exception as e:
        print(f"❌ 错误: {e}")
        import traceback
        traceback.print_exc()
    finally:
        ib.disconnect()
        print("\n👋 完成")

if __name__ == '__main__':
    main()
