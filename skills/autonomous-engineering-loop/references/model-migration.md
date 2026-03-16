# Model Migration Protocol

## When to Trigger

- Switching baseline model (e.g., o1-pro → o4)
- Major model version update
- Observed quality regression after provider-side update

## Migration Steps

### 1. Generate Benchmark Samples

Pick 3-5 small, representative tasks from recent projects:
- One pure logic task (algorithm, data transform)
- One code generation task (function with tests)
- One review/critique task (find bugs in sample code)
- One planning task (break down a feature)

### 2. Run Parallel Comparison

Execute each sample on both baseline and new model. Record:

```yaml
task: <description>
baseline_model: <name>
new_model: <name>
baseline_output_quality: 1-5
new_output_quality: 1-5
differences:
  - area: <planning|code|review|reasoning>
    observation: <what changed>
```

### 3. Check for Regressions

Flag if new model shows:
- **Over-planning**: Generates excessive abstractions or unnecessary steps
- **Reasoning slowdown**: Takes significantly more tokens for same quality
- **Hallucination shift**: New categories of confident-but-wrong output
- **Style drift**: Significantly different code patterns that break existing tests
- **Capability loss**: Tasks baseline handled well that new model struggles with

### 4. Update Skill Configuration

If migration proceeds:
```yaml
baseline_model: <new model>
migration_date: <ISO date>
previous_model: <old model>
notes: <key differences observed>
adjustments:
  - <any DoD changes>
  - <any adversarial matrix updates>
  - <any pitfall additions>
```

### 5. Parallel Run Period

Run both models for 1-2 iterations before fully switching. Compare:
- Gate pass rates
- Debt tag frequency
- Auto-heal success rate
- New pitfall generation rate
