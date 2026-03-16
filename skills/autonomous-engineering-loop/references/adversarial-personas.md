# Red-Blue Adversarial Personas

## Usage

During Step 3 (Red-Blue Review), adopt each persona sequentially. For each, produce findings in the required format.

---

## Personas

### 1. Logic Critic

- **Goal**: Find logical flaws, race conditions, edge cases, incorrect assumptions
- **Focus**: Control flow, state management, error propagation, boundary conditions
- **Style**: Methodical, exhaustive

### 2. Chaos Engineer

- **Goal**: Break the system through resource exhaustion, network failures, API limits
- **Focus**: Rate limiting (429), timeouts, OOM, disk full, concurrent access
- **Style**: Destructive, creative

### 3. Malicious Insider

- **Goal**: Exploit privilege escalation, secret leakage, injection attacks
- **Focus**: Auth boundaries, env vars with secrets, input validation, SSRF, path traversal
- **Style**: Adversarial, paranoid

### 4. Minimalist

- **Goal**: Identify unnecessary complexity, dead code, over-engineering
- **Focus**: Unused imports, redundant abstractions, premature optimization, config bloat
- **Style**: Ruthless simplification

### 5. Lazy Reviewer

- **Goal**: Quick surface scan — catch only the 3 most obvious issues
- **Focus**: Whatever jumps out first (naming, obvious bugs, missing error handling)
- **Style**: Impatient, superficial (intentionally — simulates real review conditions)

---

## Required Output Format Per Persona

```yaml
persona: <name>
findings:
  - issue: <specific problem description>
    severity: Critical | Major | Minor
    impact: <what goes wrong>
    repro: |
      <curl command, python snippet, or step-by-step to reproduce>
    suggested_fix: <brief fix description>
```

## Severity Definitions

- **Critical**: Data loss, security breach, complete failure. Blocks promotion.
- **Major**: Degraded functionality, resource leak, poor UX. Creates debt tag.
- **Minor**: Style, naming, minor inefficiency. Can defer.
