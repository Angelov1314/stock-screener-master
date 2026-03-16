---
name: autonomous-engineering-loop
description: >
  Execute a structured, self-correcting engineering workflow with built-in quality gates,
  adversarial review, and pitfall memory. Use when building or iterating on any software
  project that needs: (1) disciplined multi-iteration development cycles, (2) automated
  red-blue adversarial code review, (3) checkpoint-based gatekeeping with technical debt
  tracking, (4) structured JSONL logging with LLM-powered auto-diagnosis, (5) pitfall
  memory injection to prevent recurring mistakes, (6) model migration safety checks.
  Trigger on: "engineering loop", "autonomous loop", "structured build", "iterate with
  gates", "red-blue review", "pitfall check", or any request for a disciplined,
  multi-pass engineering workflow.
---

# Autonomous Engineering Loop

A 10-step cyclic workflow that enforces quality through adversarial review, graduated
gates, structured logging, and learned pitfall avoidance.

## Quick Start

1. Copy `assets/project-template/` into project's `state/` directory
2. Fill in `state/blueprint.yaml` (scope, DoD, dependencies)
3. Run the loop below

## Execution Loop

Every iteration follows this sequence **in order**:

### Step 1 — Blueprint Health Check (Checkpoint 0)

Before writing any code, verify the blueprint:

- [ ] DoD criteria still relevant?
- [ ] Non-goals still accurate?
- [ ] Dependencies up to date?
- [ ] Any scope creep since last iteration?

If blueprint needs changes → write them in `state/iterations.yaml` under `amendments`,
**not** in the immutable blueprint section.

### Step 2 — Implement

Write/modify code for this iteration's goals. During implementation:

- Load top-10 pitfalls from `state/pitfalls.yaml` as active constraints
- Reference the engineering commandments generated from pitfalls
- Log each significant action to `state/engineering.jsonl`

### Step 3 — Red-Blue Adversarial Review

Adopt each persona from [references/adversarial-personas.md](references/adversarial-personas.md)
and review the implementation. Output findings in the required YAML format.

**All 5 personas must run.** Minimum output: 1 finding per persona (or explicit "no issues found" with justification).

### Step 4 — Gate Evaluation

Apply the gatekeeping rules from [references/gatekeeping.md](references/gatekeeping.md):

1. Run Must-Pass checks → any failure **blocks** promotion
2. Run Should-Pass checks → failures create debt tags in `state/debt.yaml`
3. Run Nice-to-Pass checks → note for later
4. Check existing debt tags → escalate any past deadline

Update `state/blueprint.yaml` status field.

### Step 5 — Write JSONL Log

Append iteration summary to `state/engineering.jsonl`:

```json
{"timestamp":"...","attempt_id":"...","iteration":N,"action":"gate-eval","status":"...","context":"..."}
```

### Step 6 — Auto-Diagnosis

If any failures exist, follow the diagnosis flow in
[references/logging-and-diagnosis.md](references/logging-and-diagnosis.md):

1. Collect recent errors
2. Search pitfall database
3. Generate fix recommendations

### Step 7 — Self-Heal (max 2 attempts)

If a known pitfall matches:
1. Apply suggested fix
2. Re-run failed check
3. Log result

After 2 failed attempts → mark as Complex Pitfall, skip to Step 8.

### Step 8 — Update Pitfalls

Add any new pitfalls discovered this iteration to `state/pitfalls.yaml`.
See [references/pitfall-system.md](references/pitfall-system.md) for format and lifecycle.

### Step 9 — Retrospective

Record in `state/iterations.yaml`:
- Biggest risk encountered
- Least efficient step
- New engineering commandments (if any)
- Whether blueprint was updated

### Step 10 — Next Iteration

Increment iteration counter. Return to Step 1.

---

## State Files

All state lives in `<project_root>/state/`. Initialize from `assets/project-template/`:

| File | Purpose |
|------|---------|
| `blueprint.yaml` | Project scope, DoD, deps, status |
| `pitfalls.yaml` | Learned failure patterns |
| `debt.yaml` | Active/resolved technical debt |
| `iterations.yaml` | Per-iteration log and retrospectives |
| `engineering.jsonl` | Append-only structured action log |

## Reference Docs

Load these **only when needed** at the relevant step:

- [adversarial-personas.md](references/adversarial-personas.md) — Red-Blue persona definitions and output format (Step 3)
- [gatekeeping.md](references/gatekeeping.md) — Gate levels, debt rules, rollback policy (Step 4)
- [logging-and-diagnosis.md](references/logging-and-diagnosis.md) — JSONL schema, auto-diagnosis flow (Steps 5-6)
- [pitfall-system.md](references/pitfall-system.md) — Pitfall format, injection, audit rules (Steps 2, 8)
- [model-migration.md](references/model-migration.md) — Model switch protocol (when changing models)
- [blueprint-original.md](references/blueprint-original.md) — Original methodology document

## Key Rules

1. **Blueprint immutability**: Core scope/DoD only changes through amendments, never direct edits
2. **All 5 personas must review**: No skipping adversarial roles
3. **Self-heal limit**: Max 2 auto-fix attempts per error pattern per iteration
4. **Debt cap**: Max 3 active debt tags; 4th blocks promotion until one resolves
5. **Rollback**: Module-level preferred; full rollback only for security issues
6. **Pitfall injection**: Top 10 pitfalls loaded at every implementation step
7. **Audit cycle**: Every 3 projects, review pitfall hit rates
