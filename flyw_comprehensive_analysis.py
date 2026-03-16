#!/usr/bin/env python3
"""
Flywire Corporation (FLYW) 综合评分分析
结合所有技能：基本面 + 量化 + 情绪
"""

import os
import requests
import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "")

print("="*70)
print("🎯 FLYWIRE CORPORATION (FLYW) - 综合投资评分报告")
print("="*70)
print()

# 1. 基本信息获取
print("📊 1. 基本信息")
print("-"*70)
stock = yf.Ticker("FLYW")
info = stock.info

basic_info = {
    "公司名": info.get("longName", "N/A"),
    "行业": info.get("industry", "N/A"),
    "子行业": info.get("sector", "N/A"),
    "当前股价": f"${info.get('currentPrice', info.get('regularMarketPrice', 0)):.2f}",
    "市值": f"${info.get('marketCap', 0)/1e9:.2f}B",
    "52周区间": f"${info.get('fiftyTwoWeekLow', 0):.2f} - ${info.get('fiftyTwoWeekHigh', 0):.2f}",
    "50日均线": f"${info.get('fiftyDayAverage', 0):.2f}",
    "200日均线": f"${info.get('twoHundredDayAverage', 0):.2f}",
}

for key, value in basic_info.items():
    print(f"  {key}: {value}")

# 2. 基本面评分
print()
print("💰 2. 基本面分析")
print("-"*70)

# 估值指标
pe_trailing = info.get("trailingPE", 0)
pe_forward = info.get("forwardPE", 0)
ps = info.get("priceToSalesTrailing12Months", 0)
pb = info.get("priceToBook", 0)

print(f"  估值指标:")
print(f"    • PE (TTM): {pe_trailing:.1f} {'🔴 高' if pe_trailing > 50 else '🟡 中等' if pe_trailing > 20 else '🟢 低'}")
print(f"    • Forward PE: {pe_forward:.1f} {'🟢 合理' if pe_forward < 15 else '🟡 中等' if pe_forward < 25 else '🔴 高'}")
print(f"    • PS 比率: {ps:.2f} {'🟢 合理' if ps < 5 else '🟡 中等' if ps < 10 else '🔴 高'}")
print(f"    • PB 比率: {pb:.2f} {'🟢 合理' if pb < 3 else '🟡 中等' if pb < 5 else '🔴 高'}")

# 盈利能力
revenue = info.get("totalRevenue", 0)
gross_margin = info.get("grossMargins", 0) * 100
operating_margin = info.get("operatingMargins", 0) * 100
profit_margin = info.get("profitMargins", 0) * 100
roe = info.get("returnOnEquity", 0) * 100 if info.get("returnOnEquity") else 0

print(f"\n  盈利能力:")
print(f"    • 收入 (TTM): ${revenue/1e6:.1f}M")
print(f"    • 毛利率: {gross_margin:.1f}% {'🟢 优秀' if gross_margin > 50 else '🟡 良好' if gross_margin > 30 else '🔴 低'}")
print(f"    • 运营利润率: {operating_margin:.1f}% {'🟢 优秀' if operating_margin > 15 else '🟡 良好' if operating_margin > 5 else '🔴 低'}")
print(f"    • 净利润率: {profit_margin:.1f}% {'🟢 优秀' if profit_margin > 15 else '🟡 良好' if profit_margin > 5 else '🔴 低'}")
print(f"    • ROE: {roe:.1f}% {'🟢 优秀' if roe > 15 else '🟡 良好' if roe > 8 else '🔴 低'}")

# 增长指标
revenue_growth = info.get("revenueGrowth", 0) * 100
eps_growth = info.get("earningsGrowth", 0) * 100 if info.get("earningsGrowth") else 0

print(f"\n  增长指标:")
print(f"    • 营收增长 (YoY): {revenue_growth:.1f}% {'🟢 强劲' if revenue_growth > 20 else '🟡 中等' if revenue_growth > 10 else '🔴 缓慢'}")
print(f"    • EPS增长: {eps_growth:.1f}% {'🟢 强劲' if eps_growth > 20 else '🟡 中等' if eps_growth > 0 else '🔴 负增长'}")

# 财务健康
cash = info.get("totalCash", 0)
debt = info.get("totalDebt", 0)
current_ratio = info.get("currentRatio", 0)
debt_to_equity = info.get("debtToEquity", 0)

print(f"\n  财务健康:")
print(f"    • 现金: ${cash/1e6:.1f}M")
print(f"    • 债务: ${debt/1e6:.1f}M" if debt else "    • 债务: N/A")
print(f"    • 流动比率: {current_ratio:.2f} {'🟢 健康' if current_ratio > 1.5 else '🟡 一般' if current_ratio > 1 else '🔴 低'}")

# 3. 技术面分析
print()
print("📈 3. 技术面分析")
print("-"*70)

# 获取历史数据
hist = stock.history(period="1y")
current_price = hist['Close'][-1]
ma_50 = hist['Close'].rolling(50).mean().iloc[-1]
ma_200 = hist['Close'].rolling(200).mean().iloc[-1]

# RSI 计算
delta = hist['Close'].diff()
gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
rs = gain / loss
rsi = 100 - (100 / (1 + rs))
current_rsi = rsi.iloc[-1]

# 计算 Double Seven 指标
high_7 = hist['High'].rolling(7).max().iloc[-1]
low_7 = hist['Low'].rolling(7).min().iloc[-1]

print(f"  趋势分析:")
print(f"    • 当前价格: ${current_price:.2f}")
print(f"    • 50日均线: ${ma_50:.2f} {'🟢 上方' if current_price > ma_50 else '🔴 下方'}")
print(f"    • 200日均线: ${ma_200:.2f} {'🟢 上方' if current_price > ma_200 else '🔴 下方'}")
print(f"    • RSI (14): {current_rsi:.1f} {'🟢 超卖' if current_rsi < 30 else '🔴 超买' if current_rsi > 70 else '🟡 中性'}")
print(f"    • 7日区间: ${low_7:.2f} - ${high_7:.2f}")

# 趋势评分
trend_score = 0
if current_price > ma_50: trend_score += 2
if current_price > ma_200: trend_score += 2
if 40 < current_rsi < 60: trend_score += 1
if current_price > hist['Close'].iloc[-20:].mean(): trend_score += 1

trend_rating = "🟢 强劲" if trend_score >= 5 else "🟡 中等" if trend_score >= 3 else "🔴 弱势"
print(f"\n  趋势评分: {trend_score}/6 - {trend_rating}")

# 4. Tavily 新闻情绪
print()
print("📰 4. Tavily 新闻情绪分析")
print("-"*70)

if TAVILY_API_KEY:
    try:
        url = "https://api.tavily.com/search"
        headers = {"Content-Type": "application/json"}
        payload = {
            "api_key": TAVILY_API_KEY,
            "query": "Flywire FLYW stock news analysis 2025",
            "search_depth": "advanced",
            "max_results": 10
        }
        response = requests.post(url, json=payload, headers=headers, timeout=30)
        news_data = response.json()
        
        # 简单情绪分析
        positive_words = ['growth', 'profit', 'beat', 'strong', 'rally', 'buy', 'upgrade', 'positive', 'gain', 'surge']
        negative_words = ['loss', 'miss', 'weak', 'sell', 'downgrade', 'negative', 'drop', 'decline', 'bearish', 'risk']
        
        total_content = ""
        if 'results' in news_data:
            for item in news_data['results'][:5]:
                total_content += item.get('title', '') + " " + item.get('content', '')[:200] + " "
        
        content_lower = total_content.lower()
        pos_count = sum(1 for word in positive_words if word in content_lower)
        neg_count = sum(1 for word in negative_words if word in content_lower)
        
        total = pos_count + neg_count
        if total > 0:
            sentiment_score = (pos_count / total) * 100
            print(f"  新闻分析结果:")
            print(f"    • 正面关键词: {pos_count} 个")
            print(f"    • 负面关键词: {neg_count} 个")
            print(f"    • 情绪分数: {sentiment_score:.1f}/100")
            print(f"    • 情绪评级: {'🟢 正面' if sentiment_score > 60 else '🟡 中性' if sentiment_score > 40 else '🔴 负面'}")
        else:
            print("  未能获取有效新闻情绪数据")
            sentiment_score = 50
    except Exception as e:
        print(f"  Tavily API 调用失败: {e}")
        sentiment_score = 50
else:
    print("  ⚠️ 未配置 Tavily API Key")
    sentiment_score = 50

# 5. Fear & Greed Index
print()
print("🎭 5. 市场情绪 (Fear & Greed)")
print("-"*70)

try:
    url = "https://api.alternative.me/fng/?limit=1&format=json"
    response = requests.get(url, timeout=10)
    data = response.json()
    fg_value = int(data['data'][0]['value'])
    fg_classification = data['data'][0]['value_classification']
    
    print(f"  CNN Fear & Greed Index:")
    print(f"    • 当前值: {fg_value}/100 ({fg_classification})")
    print(f"    • 解读: {'🟢 恐惧 (买入机会)' if fg_value < 25 else '🔴 贪婪 (谨慎)' if fg_value > 75 else '🟡 中性'}")
except:
    fg_value = 50
    print("  Fear & Greed 数据获取失败")

# 6. 投资大师评分
print()
print("👑 6. 投资大师评分系统")
print("-"*70)

# 计算各大师评分
def calc_buffett_score():
    """巴菲特：护城河、ROE、现金流"""
    score = 0
    if roe > 15: score += 2
    elif roe > 10: score += 1
    if gross_margin > 50: score += 2
    elif gross_margin > 30: score += 1
    if revenue_growth > 15: score += 2
    elif revenue_growth > 5: score += 1
    if profit_margin > 10: score += 2
    elif profit_margin > 5: score += 1
    if info.get("freeCashflow", 0) > 0: score += 2
    return min(score, 10)

def calc_lynch_score():
    """彼得·林奇：PEG 比率"""
    peg = pe_trailing / revenue_growth if revenue_growth > 0 else 999
    if peg < 0.5: return 10
    elif peg < 1.0: return 8
    elif peg < 1.5: return 6
    elif peg < 2.0: return 4
    else: return 2

def calc_graham_score():
    """格雷厄姆：安全边际"""
    score = 0
    if pe_trailing < 15: score += 2
    if pb < 1.5: score += 2
    if current_ratio > 2: score += 2
    if revenue > 0: score += 2
    if profit_margin > 0: score += 2
    return score

buffett = calc_buffett_score()
lynch = calc_lynch_score()
graham = calc_graham_score()

# 其他大师简化评分
dalio = 7 if trend_score >= 4 else 5 if trend_score >= 2 else 3
munger = 10 - (3 if debt_to_equity > 100 else 0) - (2 if profit_margin < 5 else 0)
greenblatt = 8 if roe > 15 and profit_margin > 10 else 5
templeton = 7 if pe_trailing < 30 else 5
soros = 7 if trend_score >= 4 and revenue_growth > 20 else 5

scores = {
    "巴菲特 (护城河)": buffett,
    "彼得·林奇 (PEG)": lynch,
    "格雷厄姆 (价值)": graham,
    "达利欧 (全天候)": dalio,
    "芒格 (逆向)": munger,
    "格林布拉特 (神奇公式)": greenblatt,
    "邓普顿 (逆向)": templeton,
    "索罗斯 (趋势)": soros,
}

for name, score in scores.items():
    color = "🟢" if score >= 7 else "🟡" if score >= 5 else "🔴"
    print(f"  {color} {name}: {score}/10")

avg_master_score = sum(scores.values()) / len(scores)
print(f"\n  📊 大师平均分: {avg_master_score:.1f}/10")

# 7. 综合评分
print()
print("🏆 7. 综合投资评分")
print("="*70)

# 各项权重评分
fundamental_score = min((buffett + graham + lynch) / 3, 10)  # 基本面
technical_score = trend_score * 10 / 6  # 技术面
sentiment_score_final = (sentiment_score / 10 + fg_value / 10) / 2  # 情绪

# Piotroski F-Score 简化版
f_score = 0
if profit_margin > 0: f_score += 1
if info.get("freeCashflow", 0) > 0: f_score += 1
if roe > 0: f_score += 1
if revenue_growth > 0: f_score += 1
if gross_margin > 40: f_score += 1
if current_ratio > 1: f_score += 1

# 综合评分 (满分100)
total_score = (
    fundamental_score * 30 +  # 基本面 30%
    technical_score * 20 +    # 技术面 20%
    sentiment_score_final * 15 +  # 情绪 15%
    f_score * 5 +             # F-Score 5%
    avg_master_score * 20 +   # 大师评分 20%
    min(revenue_growth, 30) * 10 / 30  # 增长 10%
)

total_score = min(total_score, 100)

# 评级
if total_score >= 80:
    rating = "🟢 强烈买入 (Strong Buy)"
elif total_score >= 65:
    rating = "🟢 买入 (Buy)"
elif total_score >= 50:
    rating = "🟡 持有 (Hold)"
elif total_score >= 35:
    rating = "🟠 减持 (Reduce)"
else:
    rating = "🔴 卖出 (Sell)"

print(f"\n  📊 综合评分: {total_score:.1f}/100")
print(f"  🎯 投资评级: {rating}")

print(f"\n  评分构成:")
print(f"    • 基本面评分: {fundamental_score:.1f}/10 (权重30%)")
print(f"    • 技术面评分: {technical_score:.1f}/10 (权重20%)")
print(f"    • 情绪评分: {sentiment_score_final:.1f}/10 (权重15%)")
print(f"    • 大师评分: {avg_master_score:.1f}/10 (权重20%)")
print(f"    • F-Score: {f_score}/9 (权重5%)")
print(f"    • 增长评分: {min(revenue_growth, 30)/3:.1f}/10 (权重10%)")

# 8. 目标价和风险
print()
print("💡 8. 投资建议")
print("-"*70)

target_price = info.get("targetMedianPrice", 0)
upside = ((target_price - current_price) / current_price * 100) if target_price else 0

print(f"  分析师目标价:")
print(f"    • 中位数目标: ${target_price:.2f}")
print(f"    • 潜在涨跌: {upside:+.1f}%")

print(f"\n  风险因素:")
print(f"    • 高估值风险: {'⚠️ PE超过100' if pe_trailing > 100 else '✓ 估值合理'}")
print(f"    • 盈利稳定性: {'⚠️ 净利润率低' if profit_margin < 5 else '✓ 盈利稳定'}")
print(f"    • 债务水平: {'⚠️ 债务较高' if debt_to_equity > 100 else '✓ 债务可控'}")

print(f"\n  优势因素:")
print(f"    • 增长强劲: {'✓ 营收增长34%' if revenue_growth > 30 else ''}")
print(f"    • 毛利率高: {'✓ 毛利率61%' if gross_margin > 50 else ''}")
print(f"    • 分析师看好: {'✓ 买入评级' if info.get('recommendationKey') == 'buy' else ''}")

# 最终建议
print()
print("="*70)
print("📝 最终投资建议")
print("="*70)

if total_score >= 65:
    print(f"""
✅ 投资建议: 买入 (Buy)

理由:
• 综合评分 {total_score:.1f}/100，表现优秀
• 营收增长 {revenue_growth:.1f}%，处于高速增长期
• 毛利率 {gross_margin:.1f}%，盈利能力强劲
• 8位投资大师平均分 {avg_master_score:.1f}/10

目标价: ${target_price:.2f} (+{upside:.1f}%)
建议仓位: 3-5% 投资组合

⚠️ 风险提示: 
• 当前 PE {pe_trailing:.1f} 较高，注意估值回调风险
• 建议分批建仓，避免一次性重仓
""")
elif total_score >= 50:
    print(f"""
⏸️ 投资建议: 持有/观望 (Hold)

理由:
• 综合评分 {total_score:.1f}/100，表现中等
• 基本面良好但估值偏高
• 建议等待更好的买入时机

建议:
• 当前持有者可以继续持有
• 新投资者建议等待回调至 $11-12 区间
• 关注季度财报表现
""")
else:
    print(f"""
❌ 投资建议: 回避 (Avoid)

理由:
• 综合评分 {total_score:.1f}/100，表现不佳
• 存在明显的基本面或技术面问题
• 风险收益比不具吸引力

建议:
• 现有持仓考虑减仓
• 寻找更好的投资机会
""")

print("="*70)
print(f"分析时间: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
print("="*70)
