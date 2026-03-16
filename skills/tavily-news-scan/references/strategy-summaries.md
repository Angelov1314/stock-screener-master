Tavily 新闻输出要点
- 输出字段：title、summary、url、publishedAt
- 与风控的对接：将新闻摘要提交给 Gemini 进行即时风险分析；若风险高，触发风控动作（如暂停交易、清仓等）
- 降噪与去重：对重复新闻与低置信度结果进行去重
