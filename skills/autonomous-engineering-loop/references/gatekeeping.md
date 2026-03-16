# Checkpoint Gatekeeping System

## Status Model

```
Draft → Testing → Partial-Promoted → Passed
                ↘ Rolled-Back
```

- **Draft**: Initial implementation, not yet tested
- **Testing**: Running through gate checks
- **Partial-Promoted**: Passed Must-Pass but has debt tags
- **Passed**: All gates cleared (or debt within tolerance)
- **Rolled-Back**: Failed critical gate, reverted

## Gate Levels

### Must-Pass Gate (Blocking)

Failure → **cannot proceed** to next iteration.

Criteria:
- Core logic unit tests pass
- No high-severity security vulnerabilities
- Main flow executes successfully end-to-end
- No Critical findings from Red-Blue review

### Should-Pass Gate (Debt-Tagged)

Failure → proceed with `debt_tag`. Must resolve within `debt_deadline`.

Criteria:
- Coverage ≥ threshold
- Response time ≤ threshold
- No obvious resource leaks
- No Major findings unaddressed

Debt tag format:
```yaml
debt_tag: <identifier>
description: <what's deferred>
created_iteration: <N>
deadline_iteration: <N+2>
```

### Nice-to-Pass Gate (Deferrable)

Failure → note and move on. No deadline.

Criteria:
- Type completeness
- Documentation coverage
- Edge case tests
- Minor findings from Red-Blue

## Partial Promotion Rules

1. All Must-Pass gates must be green
2. Maximum 3 active debt tags at any time
3. If a debt tag exceeds its deadline → escalate to Must-Pass in next iteration
4. Track debt in `state/debt.yaml`

## Rollback Policy

- Prefer **module-level rollback** (revert specific files/functions)
- Full repo rollback only for security vulnerabilities
- Always record: `commit_id`, `reason`, `affected_modules`
- Rollback entry in iteration log is mandatory
