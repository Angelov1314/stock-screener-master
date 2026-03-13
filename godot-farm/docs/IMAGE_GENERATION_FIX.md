# Image Generation Fix Summary

## Issue
- `nano-banana-pro` skill **not installed**
- Direct Gemini model calls **not allowed**

## Solution
Switch to **`openai-image-gen`** skill which is:
- ✅ Already configured in openclaw.json
- ✅ Uses OpenAI Images API (DALL-E 3)
- ✅ API key already set

## Updated Configuration

### farm_orchestrator.js
```javascript
art: { 
  skill: 'openai-image-gen',
  model: 'moonshot/kimi-k2.5'
}
```

### Art Agent Prompt
- Updated to use OpenAI DALL-E 3
- Prompts optimized for illustration style
- Output: 1024x1024, downscale to 64x64

## To Generate Images

Option 1: Use skill command directly
```bash
cd /Users/jerry/.openclaw/workspace/godot-farm
python3 /usr/local/lib/node_modules/openclaw/skills/openai-image-gen/scripts/gen.py \
  --model dall-e-3 \
  --prompt "Hand-drawn carrot illustration..." \
  --out-dir assets/crops/carrot
```

Option 2: Art Agent uses skill via OpenClaw API
- Agent calls skill internally
- Generates all 20 sprites in batch

## Recommendation

**现在有两个选择：**

A) **继续完成代码** → 图像 Sprint 2 用 OpenAI 批量生成
B) **现在生成图像** → 运行 OpenAI skill 命令生成20张图

**建议选 A**，因为：
- 代码部分即将完成 (State + QA Agent)
- 图像生成需要较长时间 (20张 × 10-20秒)
- 可以先测试游戏逻辑，再补图像

你的决定？