# Binance Grid Trading Bot

全自动高频网格交易系统，支持动态间距、风控熔断、舆情监控。

## 📁 项目结构

```
binance-grid-bot/
├── config.yaml           # 配置文件（交易对、网格参数、风控规则）
├── main.py              # 主入口
├── grid_trader.py       # 核心交易框架（行情、网格、订单）
├── risk_manager.py      # 风控模块（仓位、止损、熔断、限流）
├── test_suite.py        # 测试套件
├── test_eth_trade.py    # ETH 买卖测试脚本
└── logs/                # 日志目录（自动创建）
```

## 🚀 快速开始

### 1. 安装依赖

```bash
pip install ccxt pandas numpy ta pyyaml requests
```

### 2. 配置 API Key

```bash
export BINANCE_API_KEY="your_api_key"
export BINANCE_SECRET_KEY="your_secret_key"
```

### 3. 修改配置

编辑 `config.yaml`：
- 调整 `trading.symbol`（交易对，如 ETH/USDT）
- 调整 `grid.amount_per_grid`（每格交易金额）
- 调整 `risk_management` 各项风控参数

### 4. 运行测试

```bash
# 验证 API 连接和逻辑
python3 test_suite.py

# ETH 买卖测试（小额）
python3 test_eth_trade.py
```

### 5. 启动机器人

```bash
python3 main.py
```

## ⚙️ 配置说明

### 交易参数 (`trading`)
- `symbol`: 交易对，如 ETH/USDT、BTC/USDT
- `market_type`: spot（现货）或 future（合约）

### 网格参数 (`grid`)
- `base_spacing`: 基础网格间距（如 0.005 = 0.5%）
- `grid_count`: 单边网格数量
- `amount_per_grid`: 每格交易金额（USDT）
- `dynamic_spacing`: 动态间距调整（基于 ADX、布林带）

### 中轴锚定 (`anchor`)
- `method`: 中轴计算方式（bb_middle = 布林带中轨）
- `timeframe`: K 线周期（5m、15m、1h）
- `trading_hours`: 交易/非交易时段不同配置

### 风控参数 (`risk_management`)
- `position_limits.max_position_ratio`: 最大仓位比例（如 0.5 = 50%）
- `stop_loss.max_drawdown`: 总资金回撤止损（如 0.05 = 5%）
- `circuit_breaker`: 熔断机制（连续错误、价格波动）
- `rate_limit`: API 限流保护

### 舆情监控 (`sentiment`)
- 集成 Tavily + Gemini
- 敏感词触发直接熔断
- AI 风险判定超过阈值暂停交易

## 🛡️ 风控特性

1. **仓位限制**: 最大仓位比例、单边最大层数
2. **止损机制**: 总资金回撤止损、单笔网格止损、追踪止损
3. **熔断系统**: 
   - 连续 API 错误熔断
   - 价格剧烈波动熔断
   - 舆情风险熔断
4. **API 保护**: 频率限制、退避重试

## 🧪 测试

```bash
# 完整测试套件
python3 test_suite.py

# 测试项目：
# - API 连接验证
# - 配置文件检查
# - 网格逻辑计算
# - 风控规则验证
```

## ⚠️ 风险提示

- ⚡ **这是真实交易代码，会使用真实资金**
- 🔒 **确保 API Key 只有交易权限，不要开通提币**
- 💰 **建议先用小额测试（如 5-10 USDT）**
- 📊 **先在 Binance 测试网验证策略**

## 📝 日志

日志文件保存在 `logs/` 目录：
- `grid_bot_YYYYMMDD.log`: 交易日志

## 🔄 后续优化

- [ ] IBKR 交易所接入
- [ ] 更复杂的动态平衡策略
- [ ] 机器学习预测辅助
- [ ] 多币种组合交易

---

**免责声明**: 自动交易有风险，过往表现不代表未来收益。请充分了解风险后再使用。
