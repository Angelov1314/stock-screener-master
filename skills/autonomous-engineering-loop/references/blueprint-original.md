# Original Blueprint Document

> Preserved as reference. The SKILL.md and scripts implement this methodology.

## 0️⃣ Metadata

```yaml
skill_name: Autonomous Engineering Loop
version: 1.0.0
model_family: o1-pro (2025.12 baseline)
owner: Jerry
created_at: 2026-02-20
```

## 1️⃣ Core Blueprint (Immutable Layer)

- Scope, core functions, non-goals
- Definition of Done (Must-Pass / Should-Pass / Nice-to-Pass)
- Dependencies

## 2️⃣ Versioned Amendments (Mutable Layer)

- Per-iteration change log with reasons

## 3️⃣ Red-Blue Adversarial Matrix

Personas: Logic Critic, Chaos Engineer, Malicious Insider, Minimalist, Lazy Reviewer

Each must provide: specific problem, impact analysis, reproduction steps, severity level

## 4️⃣ Checkpoint Gatekeeping System

States: Draft → Testing → Partial-Promoted → Passed → Rolled-Back

Gate levels: Must-Pass (block) → Should-Pass (debt tag) → Nice-to-Pass (defer)

Partial promotion with debt_tag + deadline. Rollback policy: module-level only.

## 5️⃣ Structured Logging (JSONL)

Fields: timestamp, attempt_id, checkpoint_id, model_version, prompt_hash, error_code, traceback, context

Auto-diagnosis: collect errors → RAG pitfalls → LLM classify → auto-patch (max 2) → escalate

## 6️⃣ Pitfall Memory System

Template: id, title, symptom, root_cause, fix, frequency

Injection: top-10 high-freq pitfalls as system constraints per project

Audit: every 3 projects, check hit rate, merge/delete low-hit, upgrade high-freq

## 7️⃣ Blueprint Health Check (Checkpoint 0)

Before each iteration: check DoD freshness, non-goals validity, deps, scope creep

## 8️⃣ Model Migration Protocol

Baseline vs new model comparison: over-planning, reasoning speed, hallucination patterns

## 9️⃣ Iteration Log

Track: checkpoint_passed, debt_remaining, new_pitfalls_added, blueprint_updated

## 🔟 Final Retrospective

Record: biggest risk, least efficient step, new engineering commandments

## Execution Loop

1. Checkpoint 0 → 2. Implement → 3. Red-Blue → 4. Gate → 5. JSONL log → 6. LLM diagnose → 7. Self-heal ≤2 → 8. Record pitfalls → 9. Retrospective → 10. Next iteration
