#!/usr/bin/env python3
"""
美股量化策略 - 1年回测
使用yfinance获取历史数据，模拟策略交易
"""

import yfinance as yf
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import warnings
warnings.filterwarnings('ignore')

# ============== 回测配置 ==============
INITIAL_CAPITAL = 100000  # 初始资金 $100,000
POSITION_SIZE = 0.2       # 单次仓位 20%
MAX_POSITIONS = 5         # 最大持仓数
COMMISSION = 0.001        # 手续费 0.1%

# 策略参数
MIN_AVG_VOLUME = 1_000_000
RSI_BUY_MIN = 40
RSI_BUY_MAX = 70

class BacktestEngine:
    """回测引擎"""
    
    def __init__(self, symbols, start_date, end_date):
        self.symbols = symbols
        self.start_date = start_date
        self.end_date = end_date
        self.data = {}
        self.portfolio = {
            'cash': INITIAL_CAPITAL,
            'positions': {},  # {symbol: {'shares': x, 'cost': y, 'entry_date': z}}
            'history': []     # 交易记录
        }
        self.daily_values = []  # 每日净值记录
        
    def fetch_data(self):
        """获取所有股票历史数据"""
        print("📥 下载历史数据...")
        for symbol in self.symbols:
            try:
                ticker = yf.Ticker(symbol)
                # 多获取60天用于计算均线
                start = (datetime.strptime(self.start_date, '%Y-%m-%d') - timedelta(days=80)).strftime('%Y-%m-%d')
                df = ticker.history(start=start, end=self.end_date)
                if len(df) > 60:
                    self.data[symbol] = self.calculate_indicators(df)
                    print(f"   ✅ {symbol}: {len(df)}天数据")
                else:
                    print(f"   ⚠️ {symbol}: 数据不足")
            except Exception as e:
                print(f"   ❌ {symbol}: {e}")
        
        print(f"✅ 成功加载 {len(self.data)} 只股票\n")
    
    def calculate_indicators(self, df):
        """计算技术指标"""
        df = df.copy()
        
        # 均线
        df['MA5'] = df['Close'].rolling(5).mean()
        df['MA10'] = df['Close'].rolling(10).mean()
        df['MA20'] = df['Close'].rolling(20).mean()
        df['MA60'] = df['Close'].rolling(60).mean()
        
        # MACD
        exp1 = df['Close'].ewm(span=12, adjust=False).mean()
        exp2 = df['Close'].ewm(span=26, adjust=False).mean()
        df['MACD'] = exp1 - exp2
        df['MACD_Signal'] = df['MACD'].ewm(span=9, adjust=False).mean()
        
        # RSI
        delta = df['Close'].diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=14).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=14).mean()
        rs = gain / loss
        df['RSI'] = 100 - (100 / (1 + rs))
        
        # 成交量均线
        df['Volume_MA20'] = df['Volume'].rolling(20).mean()
        
        # 日涨跌
        df['Daily_Return'] = df['Close'].pct_change() * 100
        
        return df
    
    def calculate_score(self, df, idx):
        """计算某一天的技术评分"""
        if idx < 60:  # 需要足够历史数据
            return 0
        
        row = df.iloc[idx]
        prev = df.iloc[idx-1]
        
        score = 0
        
        # 1. 价格 > MA5 (1分)
        if row['Close'] > row['MA5']:
            score += 1
        
        # 2. MA多头排列 (1.5分)
        if row['MA5'] > row['MA10'] > row['MA20']:
            score += 1.5
        
        # 3. MACD金叉或上方 (1分)
        macd_cross = (prev['MACD'] < prev['MACD_Signal']) and (row['MACD'] > row['MACD_Signal'])
        if macd_cross:
            score += 1
        elif row['MACD'] > row['MACD_Signal']:
            score += 0.5
        
        # 4. RSI健康 (1分)
        if RSI_BUY_MIN <= row['RSI'] <= RSI_BUY_MAX:
            score += 1
        
        # 5. 流动性充足 (1分)
        if row['Volume_MA20'] >= MIN_AVG_VOLUME:
            score += 1
        
        # 6. 日涨跌>0.5% (0.5分)
        if row['Daily_Return'] > 0.5:
            score += 0.5
        
        # 7. 成交量放大 (1分)
        if row['Volume'] > row['Volume_MA20'] * 1.2:
            score += 1
        
        # 8. 价格 > MA60 (1分)
        if row['Close'] > row['MA60']:
            score += 1
        
        return score
    
    def get_buy_signals(self, date):
        """获取某一天的买入信号"""
        signals = []
        
        for symbol, df in self.data.items():
            # 找到对应的日期索引
            if date not in df.index:
                continue
            
            idx = df.index.get_loc(date)
            if idx < 60:
                continue
            
            score = self.calculate_score(df, idx)
            
            if score >= 7:  # 买入阈值
                signals.append({
                    'symbol': symbol,
                    'score': score,
                    'price': df.loc[date, 'Close'],
                    'rsi': df.loc[date, 'RSI']
                })
        
        # 按评分排序
        signals.sort(key=lambda x: x['score'], reverse=True)
        return signals
    
    def get_sell_signals(self, date):
        """获取卖出信号（简化版：跌破MA20或止损）"""
        sells = []
        
        for symbol, position in list(self.portfolio['positions'].items()):
            if symbol not in self.data:
                continue
            
            df = self.data[symbol]
            if date not in df.index:
                continue
            
            idx = df.index.get_loc(date)
            row = df.iloc[idx]
            
            # 卖出条件：
            # 1. 价格跌破MA20
            # 2. RSI > 75（超买）
            # 3. 亏损超过8%止损
            
            current_price = row['Close']
            cost_price = position['cost']
            pnl_pct = (current_price - cost_price) / cost_price
            
            sell_reason = None
            if current_price < row['MA20']:
                sell_reason = "跌破MA20"
            elif row['RSI'] > 75:
                sell_reason = "RSI超买"
            elif pnl_pct < -0.08:
                sell_reason = "止损-8%"
            
            if sell_reason:
                sells.append({
                    'symbol': symbol,
                    'reason': sell_reason,
                    'price': current_price,
                    'pnl_pct': pnl_pct
                })
        
        return sells
    
    def execute_buy(self, symbol, price, date):
        """执行买入"""
        position_value = self.portfolio['cash'] * POSITION_SIZE
        shares = int(position_value / price)
        
        if shares < 1:
            return False
        
        cost = shares * price * (1 + COMMISSION)
        
        if cost > self.portfolio['cash']:
            return False
        
        self.portfolio['cash'] -= cost
        self.portfolio['positions'][symbol] = {
            'shares': shares,
            'cost': price,
            'entry_date': date
        }
        
        self.portfolio['history'].append({
            'date': date,
            'action': 'BUY',
            'symbol': symbol,
            'shares': shares,
            'price': price,
            'value': shares * price
        })
        
        return True
    
    def execute_sell(self, symbol, price, date, reason):
        """执行卖出"""
        position = self.portfolio['positions'][symbol]
        shares = position['shares']
        cost_price = position['cost']
        
        proceeds = shares * price * (1 - COMMISSION)
        pnl = shares * (price - cost_price)
        pnl_pct = (price - cost_price) / cost_price
        
        self.portfolio['cash'] += proceeds
        del self.portfolio['positions'][symbol]
        
        self.portfolio['history'].append({
            'date': date,
            'action': 'SELL',
            'symbol': symbol,
            'shares': shares,
            'price': price,
            'value': shares * price,
            'pnl': pnl,
            'pnl_pct': pnl_pct,
            'reason': reason
        })
    
    def calculate_portfolio_value(self, date):
        """计算组合总价值"""
        total = self.portfolio['cash']
        
        for symbol, position in self.portfolio['positions'].items():
            if symbol in self.data and date in self.data[symbol].index:
                price = self.data[symbol].loc[date, 'Close']
                total += position['shares'] * price
        
        return total
    
    def run(self):
        """运行回测"""
        print("="*60)
        print("🚀 开始回测")
        print(f"📅 回测区间: {self.start_date} ~ {self.end_date}")
        print(f"💰 初始资金: ${INITIAL_CAPITAL:,}")
        print(f"📊 股票池: {', '.join(self.symbols)}")
        print("="*60 + "\n")
        
        # 获取交易日列表
        all_dates = set()
        for df in self.data.values():
            mask = (df.index >= self.start_date) & (df.index <= self.end_date)
            all_dates.update(df[mask].index)
        
        trading_days = sorted(list(all_dates))
        print(f"📅 共 {len(trading_days)} 个交易日\n")
        
        # 逐日回测
        for i, date in enumerate(trading_days):
            if i % 50 == 0:
                print(f"   进度: {date.strftime('%Y-%m-%d')} ({i}/{len(trading_days)})")
            
            # 1. 先处理卖出
            sells = self.get_sell_signals(date)
            for sell in sells:
                self.execute_sell(sell['symbol'], sell['price'], date, sell['reason'])
            
            # 2. 再处理买入（如果有空位）
            current_positions = len(self.portfolio['positions'])
            if current_positions < MAX_POSITIONS and self.portfolio['cash'] > 10000:
                buys = self.get_buy_signals(date)
                for buy in buys[:MAX_POSITIONS - current_positions]:
                    if buy['symbol'] not in self.portfolio['positions']:
                        self.execute_buy(buy['symbol'], buy['price'], date)
            
            # 3. 记录净值
            portfolio_value = self.calculate_portfolio_value(date)
            self.daily_values.append({
                'date': date,
                'value': portfolio_value,
                'cash': self.portfolio['cash'],
                'positions': len(self.portfolio['positions'])
            })
        
        print("\n✅ 回测完成\n")
    
    def report(self):
        """生成回测报告"""
        df_values = pd.DataFrame(self.daily_values)
        df_values.set_index('date', inplace=True)
        
        # 基础指标
        final_value = df_values['value'].iloc[-1]
        total_return = (final_value - INITIAL_CAPITAL) / INITIAL_CAPITAL * 100
        
        # 计算日收益率
        df_values['daily_return'] = df_values['value'].pct_change()
        
        # 年化收益率
        days = len(df_values)
        annual_return = ((final_value / INITIAL_CAPITAL) ** (252 / days) - 1) * 100
        
        # 最大回撤
        df_values['cummax'] = df_values['value'].cummax()
        df_values['drawdown'] = (df_values['value'] - df_values['cummax']) / df_values['cummax']
        max_drawdown = df_values['drawdown'].min() * 100
        
        # 波动率
        volatility = df_values['daily_return'].std() * np.sqrt(252) * 100
        
        # 夏普比率 (假设无风险利率2%)
        sharpe = (annual_return - 2) / volatility if volatility > 0 else 0
        
        # 交易统计
        trades = self.portfolio['history']
        buy_trades = [t for t in trades if t['action'] == 'BUY']
        sell_trades = [t for t in trades if t['action'] == 'SELL']
        
        winning_trades = [t for t in sell_trades if t.get('pnl', 0) > 0]
        win_rate = len(winning_trades) / len(sell_trades) * 100 if sell_trades else 0
        
        avg_profit = np.mean([t['pnl_pct'] for t in sell_trades if t.get('pnl_pct')]) * 100 if sell_trades else 0
        
        # 输出报告
        print("="*60)
        print("📊 回测报告")
        print("="*60)
        print(f"\n💰 收益指标:")
        print(f"   初始资金:     ${INITIAL_CAPITAL:>12,}")
        print(f"   最终资金:     ${final_value:>12,.2f}")
        print(f"   总收益率:     {total_return:>12.2f}%")
        print(f"   年化收益率:   {annual_return:>12.2f}%")
        print(f"   最大回撤:     {max_drawdown:>12.2f}%")
        print(f"   年化波动率:   {volatility:>12.2f}%")
        print(f"   夏普比率:     {sharpe:>12.2f}")
        
        print(f"\n📈 交易统计:")
        print(f"   买入次数:     {len(buy_trades):>12}")
        print(f"   卖出次数:     {len(sell_trades):>12}")
        print(f"   胜率:         {win_rate:>12.1f}%")
        print(f"   平均盈亏:     {avg_profit:>12.2f}%")
        
        # 最近交易
        print(f"\n📝 最近10笔交易:")
        for t in sell_trades[-10:]:
            emoji = "✅" if t.get('pnl', 0) > 0 else "❌"
            print(f"   {t['date'].strftime('%Y-%m-%d')} {emoji} {t['symbol']:6} "
                  f"{t['pnl_pct']*100:+.2f}% ({t['reason']})")
        
        # 持仓收益对比
        print(f"\n📊 对比买入持有SPY:")
        spy = yf.Ticker("SPY")
        spy_data = spy.history(start=self.start_date, end=self.end_date)
        spy_return = (spy_data['Close'].iloc[-1] / spy_data['Close'].iloc[0] - 1) * 100
        print(f"   策略收益: {total_return:.2f}%")
        print(f"   SPY收益:  {spy_return:.2f}%")
        print(f"   超额收益: {total_return - spy_return:+.2f}%")
        
        print("="*60)
        
        return {
            'total_return': total_return,
            'annual_return': annual_return,
            'max_drawdown': max_drawdown,
            'sharpe': sharpe,
            'win_rate': win_rate
        }


def main():
    # 回测参数
    symbols = ['AAPL', 'MSFT', 'GOOGL', 'AMZN', 'NVDA', 'TSLA', 'META', 'AMD', 'NFLX', 'CRM']
    
    # 回测区间：过去一年
    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d')
    
    # 创建回测引擎
    engine = BacktestEngine(symbols, start_date, end_date)
    
    # 获取数据
    engine.fetch_data()
    
    # 运行回测
    engine.run()
    
    # 生成报告
    results = engine.report()
    
    # 保存结果
    print("\n💾 保存回测数据...")
    df_values = pd.DataFrame(engine.daily_values)
    df_values.to_csv('/Users/jerry/.openclaw/workspace/backtest_results.csv', index=False)
    print("✅ 已保存到 backtest_results.csv")


if __name__ == '__main__':
    main()
