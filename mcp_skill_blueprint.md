# 🧠 MCP Skill: Autonomous Engineering Loop

---

## 0️⃣ Metadata

```yaml
skill_name: Autonomous Engineering Loop
version: 1.0.0
model_family: o1-pro (2025.12 baseline)
owner: <your_name>
created_at: 2026-02-20
```

---

# 1️⃣ Core Blueprint (Immutable Layer)

> ⚠️ 本部分只允许极少修改。若业务变化，请写入 Amendments。

## 1.1 Scope

* 本技能目标：
* 核心功能：
* 明确不包含功能（Non-Goals）：

## 1.2 Definition of Done (DoD)

### Must-Pass

* [ ] 核心逻辑单元测试通过
* [ ] 无高危安全漏洞
* [ ] 主流程成功执行

### Should-Pass

* [ ] 覆盖率 ≥ X%
* [ ] 响应时间 ≤ X ms
* [ ] 无明显资源泄露

### Nice-to-Pass

* [ ] 类型完整
* [ ] 文档齐全
* [ ] 边界测试覆盖

---

## 1.3 Dependencies

* Python 版本：
* 第三方库：
* API 权限：
* 环境变量：
* 外部服务依赖：

---

# 2️⃣ Versioned Amendments (Mutable Layer)

> 每轮迭代只修改这里

```yaml
iteration: 1
changes:
  - 新增 API 限流逻辑
  - 修改缓存策略
reason:
  - 发现生产环境 429 错误
```

---

# 3️⃣ Red-Blue Adversarial Matrix

> 每轮必须跑一轮对抗

## 3.1 Personas

| Persona           | 目标               |
| ----------------- | ---------------- |
| Logic Critic      | 找逻辑漏洞            |
| Chaos Engineer    | 制造资源耗尽 / API 429 |
| Malicious Insider | 越权 / 泄露密钥        |
| Minimalist        | 检查冗余             |
| Lazy Reviewer     | 只挑3个显眼问题         |

---

## 3.2 强制要求

每个 Persona 必须提供：

* ❗ 具体问题
* ❗ 影响分析
* ❗ 复现步骤（curl / python 伪代码）
* ❗ 严重等级（Critical / Major / Minor）

---

# 4️⃣ Checkpoint Gatekeeping System

---

## 4.1 状态模型

```yaml
status:
  - Draft
  - Testing
  - Partial-Promoted
  - Passed
  - Rolled-Back
```

---

## 4.2 Gate Levels

### Must-Pass Gate

若失败 → 禁止进入下一阶段

### Should-Pass Gate

若失败 → 打 debt_tag

### Nice-to-Pass Gate

可延期修复

---

## 4.3 Partial Promotion

```yaml
debt_tag:
  - coverage_below_80
  - memory_leak_minor
debt_deadline: iteration+2
```

---

## 4.4 Rollback Policy

* 模块级回滚优先
* 禁止整 repo 回滚（除非安全漏洞）
* 必须记录 commit_id

---

# 5️⃣ Structured Logging System

---

## 5.1 日志格式（JSONL）

```json
{
  "timestamp": "",
  "attempt_id": "",
  "checkpoint_id": "",
  "model_version": "",
  "prompt_hash": "",
  "error_code": "",
  "traceback": "",
  "context": ""
}
```

---

## 5.2 自动诊断流程

1. 收集最近50条错误
2. RAG 检索 pitfalls
3. LLM 生成分类与修复建议
4. 若属于已知轻量问题 → 自动生成 patch
5. 最多自愈2次
6. 超过2次 → 标记 Complex Pitfall

---

# 6️⃣ Pitfall Memory System

---

## 6.1 Pitfall Template

```yaml
id: PF-001
title: File handle not closed
symptom: 内存泄露
root_cause: 未使用 with 语句
fix: 强制使用 context manager
frequency: 3
```

---

## 6.2 强制注入机制

每次新项目启动：

* 自动抽取 top-10 高频 pitfalls
* 注入为 system constraints
* 生成工程戒律列表

---

## 6.3 记忆有效性审计

每3个项目：

* 检查命中率
* 低命中合并或删除
* 高频升级为工程规范

---

# 7️⃣ Blueprint Health Check (Checkpoint 0)

每轮迭代前必须执行：

* [ ] 是否存在过时 DoD？
* [ ] Non-Goals 是否仍合理？
* [ ] Dependencies 是否更新？
* [ ] 是否出现 scope creep？

---

# 8️⃣ Model Migration Protocol

```yaml
baseline_model: o1-pro-2025.12
new_model: o4-2026.06
```

迁移步骤：

1. 生成小功能样例
2. 对比输出差异
3. 检查：
   * 是否过度规划？
   * 是否 reasoning 变慢？
   * 是否 hallucination pattern 变化？
4. 若差异显著 → 更新 DoD & 挑刺矩阵

---

# 9️⃣ Iteration Log

```yaml
iteration: 3
checkpoint_passed: 4/5
debt_remaining: 2
new_pitfalls_added: 1
blueprint_updated: yes
```

---

# 🔟 Final Retrospective

每次完整通过后：

* 写入：
  * 本轮最大风险
  * 最低效步骤
  * 新增工程戒律
* 更新：
  * Amendments
  * Pitfalls
  * System Prompt 模板

---

# 🔥 运行循环（执行顺序）

1. Checkpoint 0 → 蓝图健康检查
2. 实现功能
3. 多人格红蓝对抗
4. 进入 Gate 判断
5. 生成 JSONL 日志
6. LLM 诊断
7. 自愈 ≤2 次
8. 记录 pitfalls
9. 复盘更新
10. 进入下一 iteration

---

# 🧩 设计哲学总结

* 蓝图必须是“活文档”
* 门禁必须允许债务存在
* 记忆必须动态注入
* 诊断不能写死规则
* 模型升级必须 smoke test
