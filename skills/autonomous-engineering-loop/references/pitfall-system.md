# Pitfall Memory System

## Pitfall Database

Stored in `state/pitfalls.yaml`. Each entry:

```yaml
- id: PF-001
  title: File handle not closed
  symptom: Memory leak, "too many open files" error
  root_cause: Not using context manager (with statement)
  fix: Wrap all file operations in `with open(...) as f:`
  keywords: [file, handle, leak, open, close]
  frequency: 3
  last_seen: 2026-02-20
  severity: Major
```

## Pitfall Lifecycle

### Creation

New pitfall when:
- Auto-diagnosis encounters unknown error pattern (2+ occurrences)
- Red-Blue review identifies recurring issue class
- Retrospective surfaces repeated mistake

### Injection (Per Project)

At project start (Checkpoint 0):
1. Sort pitfalls by `frequency` descending
2. Take top 10
3. Generate engineering commandments list:
   ```
   ⚠️ Engineering Commandments (from pitfall memory):
   1. Always use context managers for file I/O (PF-001, freq: 3)
   2. Set explicit timeouts on all HTTP requests (PF-007, freq: 5)
   ...
   ```
4. Include in system context for all implementation steps

### Audit (Every 3 Projects)

Review all pitfalls:
- **Hit rate > 30%** → Upgrade to permanent engineering rule
- **Hit rate 10-30%** → Keep as pitfall
- **Hit rate < 10%** → Merge with similar or archive
- **No hits in 6+ months** → Archive

Hit rate = (times matched in auto-diagnosis) / (total projects since creation)

## Pitfall Search

During auto-diagnosis, search by:
1. Exact `error_code` match
2. Keyword overlap with `keywords` field
3. Fuzzy match on `symptom` text

Minimum 60% keyword overlap to consider a match.
