#!/usr/bin/env python3
import os
import json
import requests

def main():
    base = "https://api.tavily.com/search"
    api_key = os.getenv("TAVILY_API_KEY")
    if not api_key:
        print(json.dumps({"error": "TAVILY_API_KEY not set"}))
        return

    # Tavily API: api_key 放在请求体中
    payload = {
        "api_key": api_key,
        "query": "AI artificial intelligence news today",
        "search_depth": "basic",
        "include_answer": False,
        "include_images": False,
        "include_raw_content": False,
        "max_results": 10
    }
    headers = {
        "Content-Type": "application/json"
    }

    try:
        resp = requests.post(base, headers=headers, json=payload, timeout=15)
        resp.raise_for_status()
        data = resp.json()
        # 最小输出字段
        results = []
        for item in data.get("results", []):
            results.append({
                "title": item.get("title"),
                "summary": item.get("content") or item.get("snippet", ""),
                "url": item.get("url"),
                "publishedAt": item.get("published_date", "")
            })
        print(json.dumps({"results": results}, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"error": str(e)}))


if __name__ == "__main__":
    main()
