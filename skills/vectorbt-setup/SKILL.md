# vectorbt-setup Skill

设置 vectorbt 回测环境，专注于美股交易。

## 功能

- 检查并安装必要的 Python 包
- 配置美股数据源（使用 yfinance，无需 API key）
- 初始化回测环境

## 依赖

- vectorbt - 回测框架
- yfinance - 获取美股数据
- pandas - 数据处理
- numpy - 数值计算

## 使用方法

```bash
python /Users/jerry/.openclaw/workspace/skills/vectorbt-setup/setup.py
```

## 数据说明

- 美股数据通过 yfinance 获取
- 无需 API key，免费使用
- 支持日线、分钟线等多种时间周期
