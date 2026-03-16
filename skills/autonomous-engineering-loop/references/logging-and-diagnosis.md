# Structured Logging & Auto-Diagnosis

## JSONL Log Schema

Each engineering action produces a log entry:

```json
{
  "timestamp": "2026-02-22T10:30:00Z",
  "attempt_id": "att-001",
  "checkpoint_id": "cp-003",
  "iteration": 2,
  "model_version": "o1-pro-2025.12",
  "prompt_hash": "sha256:abc123...",
  "action": "implement|test|review|fix|rollback",
  "status": "success|failure|partial",
  "error_code": null,
  "traceback": null,
  "duration_ms": 1500,
  "context": "Brief description of what was attempted"
}
```

### Required Fields

- `timestamp`, `attempt_id`, `iteration`, `action`, `status`

### Optional Fields

- `error_code`, `traceback` (only on failure)
- `prompt_hash` (when LLM-generated code is involved)
- `model_version` (track which model produced the output)

## Log File Location

```
state/engineering.jsonl
```

Append-only. Never truncate during active project.

## Auto-Diagnosis Flow

When errors accumulate:

```
1. Collect last 50 error entries from engineering.jsonl
2. Search pitfall database (state/pitfalls.yaml) via keyword match
3. If known pitfall found:
   a. Apply suggested fix
   b. Re-run failed checkpoint
   c. Log result
   d. Maximum 2 auto-heal attempts per error pattern
4. If unknown or auto-heal exceeded 2 attempts:
   a. Mark as "Complex Pitfall"
   b. Generate diagnostic summary
   c. Request human review or create new pitfall entry
```

## Diagnostic Summary Format

```yaml
error_pattern: <grouped error description>
occurrences: <count>
first_seen: <timestamp>
last_seen: <timestamp>
auto_heal_attempts: <0-2>
matched_pitfall: <PF-xxx or null>
recommendation: <suggested action>
```
