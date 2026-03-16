# vectorbt-backtest Skill

使用 vectorbt 进行美股策略回测。

## 功能

- EMA 交叉策略回测
- 自动生成回测报告
- 可视化收益曲线

## 使用方法

```bash
# TSLA EMA 交叉策略回测
python /Users/jerry/.openclaw/workspace/skills/vectorbt-backtest/backtest.py --symbol TSLA --start 2023-01-01 --end 2024-01-01

# AAPL EMA 交叉策略回测
python /Users/jerry/.openclaw/workspace/skills/vectorbt-backtest/backtest.py --symbol AAPL --start 2023-01-01 --end 2024-01-01
```

## 参数

- `--symbol`: 股票代码 (默认: TSLA)
- `--start`: 开始日期 (默认: 2023-01-01)
- `--end`: 结束日期 (默认: 2024-01-01)
- `--fast-ema`: 快线 EMA 周期 (默认: 12)
- `--slow-ema`: 慢线 EMA 周期 (默认: 26)

## 输出

- 回测结果报告
- 收益曲线图表
- 交易统计信息
