#!/usr/bin/env python3
"""
vectorbt EMA 交叉策略回测脚本 - 修复版
专注于美股交易，非交互式图表
"""

import argparse
import yfinance as yf
import vectorbt as vbt
import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')  # 使用非交互式后端
import matplotlib.pyplot as plt
from datetime import datetime
import os

def fetch_data(symbol, start_date, end_date):
    """使用 yfinance 获取美股数据"""
    print(f"📊 正在获取 {symbol} 数据 ({start_date} 至 {end_date})...")
    
    ticker = yf.Ticker(symbol)
    data = ticker.history(start=start_date, end=end_date)
    
    if data.empty:
        raise ValueError(f"无法获取 {symbol} 的数据")
    
    # 确保索引有频率（日线数据）
    data.index = pd.date_range(start=data.index[0], periods=len(data), freq='D')
    data.index = data.index.tz_localize(None)
    
    print(f"✅ 获取到 {len(data)} 条数据")
    print(f"   价格区间: ${data['Close'].min():.2f} - ${data['Close'].max():.2f}")
    return data

def run_ema_backtest(data, symbol, fast_ema=12, slow_ema=26):
    """运行 EMA 交叉策略回测"""
    print(f"\n🔄 运行 EMA 交叉策略回测...")
    print(f"   快线 EMA: {fast_ema}")
    print(f"   慢线 EMA: {slow_ema}")
    
    # 计算 EMA
    fast = vbt.MA.run(data['Close'], window=fast_ema, ewm=True)
    slow = vbt.MA.run(data['Close'], window=slow_ema, ewm=True)
    
    # 生成交易信号
    entries = fast.ma_crossed_above(slow)
    exits = fast.ma_crossed_below(slow)
    
    # 运行回测
    portfolio = vbt.Portfolio.from_signals(
        close=data['Close'],
        entries=entries,
        exits=exits,
        init_cash=10000,
        fees=0.001,  # 0.1% 手续费
        slippage=0.001,  # 0.1% 滑点
        freq='1d',  # 日线数据
    )
    
    return portfolio, entries, exits

def generate_report(portfolio, symbol, output_dir):
    """生成回测报告"""
    print(f"\n📈 回测结果 ({symbol})")
    print("=" * 50)
    
    # 基本统计
    stats = portfolio.stats()
    print(stats)
    
    # 总收益率
    total_return = portfolio.total_return()
    print(f"\n💰 总收益率: {total_return:.2%}")
    
    # 年化收益率 (手动计算)
    days = (portfolio.wrapper.index[-1] - portfolio.wrapper.index[0]).days
    years = days / 365
    if years > 0:
        annual_return = (1 + total_return) ** (1 / years) - 1
    else:
        annual_return = 0
    print(f"📊 年化收益率: {annual_return:.2%}")
    
    # 最大回撤
    max_drawdown = portfolio.max_drawdown()
    print(f"📉 最大回撤: {max_drawdown:.2%}")
    
    # 交易次数
    trades = portfolio.trades
    print(f"🔄 总交易次数: {len(trades)}")
    
    if len(trades) > 0:
        win_rate = trades.win_rate()
        print(f"🎯 胜率: {win_rate:.2%}")
    
    # 保存报告
    report_path = os.path.join(output_dir, f"backtest_report_{symbol}.txt")
    with open(report_path, 'w') as f:
        f.write(f"回测报告 - {symbol}\n")
        f.write("=" * 50 + "\n\n")
        f.write(f"总收益率: {total_return:.2%}\n")
        f.write(f"年化收益率: {annual_return:.2%}\n")
        f.write(f"最大回撤: {max_drawdown:.2%}\n")
        f.write(f"总交易次数: {len(trades)}\n")
        if len(trades) > 0:
            f.write(f"胜率: {win_rate:.2%}\n")
        f.write("\n" + "=" * 50 + "\n")
        f.write("详细统计:\n")
        f.write(str(stats))
    
    print(f"\n✅ 报告已保存到: {report_path}")
    
    return stats

def plot_results(portfolio, data, symbol, entries, exits, output_dir):
    """绘制回测结果图表"""
    print(f"\n📊 生成图表...")
    
    # 创建图表
    fig, axes = plt.subplots(3, 1, figsize=(14, 10), sharex=True)
    
    # 价格图
    axes[0].plot(data.index, data['Close'], label='Close Price', alpha=0.7, color='blue')
    entry_points = data.index[entries]
    exit_points = data.index[exits]
    axes[0].scatter(entry_points, data['Close'][entries], 
                    color='green', marker='^', s=100, label='Buy Signal', zorder=5)
    axes[0].scatter(exit_points, data['Close'][exits], 
                    color='red', marker='v', s=100, label='Sell Signal', zorder=5)
    axes[0].set_title(f'{symbol} - EMA Cross Strategy Backtest', fontsize=14)
    axes[0].set_ylabel('Price ($)')
    axes[0].legend()
    axes[0].grid(True, alpha=0.3)
    
    # 持仓图 - 修复：使用 portfolio.shares() 代替 portfolio.positions
    try:
        shares = portfolio.shares()
        if hasattr(shares, 'values'):
            shares_values = shares.values.flatten()
        else:
            shares_values = np.array(shares).flatten()
        axes[1].fill_between(data.index[:len(shares_values)], 0, shares_values, alpha=0.3, color='blue')
    except:
        # 如果无法获取持仓数据，跳过
        axes[1].text(0.5, 0.5, 'Position data unavailable', ha='center', va='center')
    axes[1].set_ylabel('Position')
    axes[1].grid(True, alpha=0.3)
    axes[1].set_title('Position Over Time')
    
    # 收益曲线
    cumulative_returns = portfolio.cumulative_returns()
    axes[2].plot(data.index[:len(cumulative_returns)], cumulative_returns, label='Cumulative Returns', color='purple')
    axes[2].axhline(y=0, color='black', linestyle='--', alpha=0.3)
    axes[2].set_ylabel('Cumulative Returns')
    axes[2].set_xlabel('Date')
    axes[2].legend()
    axes[2].grid(True, alpha=0.3)
    axes[2].set_title('Cumulative Returns')
    
    plt.tight_layout(pad=2.0)
    
    # 保存图表
    chart_path = os.path.join(output_dir, f"backtest_chart_{symbol}.png")
    plt.savefig(chart_path, dpi=100)
    plt.close(fig)
    print(f"✅ 图表已保存到: {chart_path}")
    
    return chart_path

def main():
    parser = argparse.ArgumentParser(description='vectorbt EMA 交叉策略回测')
    parser.add_argument('--symbol', type=str, default='TSLA', help='股票代码 (默认: TSLA)')
    parser.add_argument('--start', type=str, default='2023-01-01', help='开始日期 (默认: 2023-01-01)')
    parser.add_argument('--end', type=str, default='2024-01-01', help='结束日期 (默认: 2024-01-01)')
    parser.add_argument('--fast-ema', type=int, default=12, help='快线 EMA 周期 (默认: 12)')
    parser.add_argument('--slow-ema', type=int, default=26, help='慢线 EMA 周期 (默认: 26)')
    parser.add_argument('--output-dir', type=str, default='.', help='输出目录')
    
    args = parser.parse_args()
    
    print("=" * 50)
    print("vectorbt EMA 交叉策略回测")
    print("=" * 50)
    print(f"股票: {args.symbol}")
    print(f"期间: {args.start} 至 {args.end}")
    print(f"策略: EMA{args.fast_ema}/EMA{args.slow_ema} 交叉")
    print("=" * 50)
    
    try:
        # 获取数据
        data = fetch_data(args.symbol, args.start, args.end)
        
        # 运行回测
        portfolio, entries, exits = run_ema_backtest(
            data, args.symbol, args.fast_ema, args.slow_ema
        )
        
        # 生成报告
        stats = generate_report(portfolio, args.symbol, args.output_dir)
        
        # 绘制图表
        chart_path = plot_results(portfolio, data, args.symbol, entries, exits, args.output_dir)
        
        print("\n" + "=" * 50)
        print("✅ 回测完成！")
        print("=" * 50)
        
        return 0
        
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    import sys
    sys.exit(main())
