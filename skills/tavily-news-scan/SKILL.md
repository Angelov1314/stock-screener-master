---
name: tavily-news-scan
description: 使用 Tavily 实时查询新闻，输出标题、摘要、链接与发布时间；后续可接 Gemini 进行风险分析
---

Trigger: 需要获取 AI 相关最新新闻时调用 Tavily 的 /v1/search
Input:
- query (string)：如 "AI news"、"artificial intelligence"
- time_range (string)：如 "last_24h"
- search_depth (int)：如 3
Output:
- list of news: [{ title, summary, url, publishedAt }]

Workflow:
1) 读取环境变量 TAVILY_API_KEY
2) 发送 POST https://api.tavily.com/search
   - Headers: Authorization: Bearer ${TAVILY_API_KEY}
   - Body: {"query": "<your query>", "time_range": "<time_range>", "search_depth": <depth>}
3) 解析返回，输出最小字段集
4) （可选）把摘要送去 Gemini 做即时风险分析
5) 将结果以 JSONL/简要文本形式返回给调用方

Notes:
- 任何 API Key 都不要写入日志或文件中
- 需要处理 429 限流，带退避
- 输出示例尽量简短，避免把整篇背景塞进上下文
---
