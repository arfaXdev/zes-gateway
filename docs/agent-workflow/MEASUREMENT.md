# Measuring and Tuning Coding-Agent Performance

Do not optimize an agent from impressions alone. Measure where elapsed time and rework occur, then change one part of the workflow at a time.

## 1. Measure outcomes and latency together

Track at least:

| Metric | Meaning |
|---|---|
| Lead time | Request received to acceptable delivery |
| Active agent time | Time spent reasoning or using tools |
| Tool wait time | Builds, tests, network, and process startup |
| Time to first evidence | How quickly the agent establishes a confirmed fact |
| Time to first valid patch | First patch that survives final review |
| Rework cycles | Material implementation rewrites |
| User clarification count | Blocking questions asked |
| Tool-call count | Total and by category |
| Duplicate discovery rate | Repeated reads/searches for the same fact |
| Verification depth | Highest justified test level completed |
| Escaped defects | Problems found after delivery |
| Scope drift | Changed lines/files unrelated to acceptance criteria |

Speed without escaped-defect tracking rewards reckless behavior.

## 2. Use a simple phase log

For ten tasks, record this table:

```markdown
| Task | Risk | Intake | Recon | Plan | Implement | Verify | Review | Wait | Rework | Result |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| #123 | normal | 2m | 6m | 2m | 14m | 8m | 3m | 5m | 0 | pass |
```

Keep measurement lightweight. Approximate phase timing is enough to expose a 20-minute repeated build or an agent that spends half the task browsing.

## 3. Read the latency equation

A useful mental model is:

```text
Lead time = discovery + decisions + implementation + verification
          + tool waits + handoffs + rework
```

Parallelism can reduce independent discovery and tool waits. It cannot safely remove required decisions or verification. Poor parallelism increases handoffs and rework.

## 4. Diagnose common profiles

| Measured profile | Likely cause | First experiment |
|---|---|---|
| High reconnaissance, low rework | Exploration is too broad | Add stop conditions and line-range reads |
| Low reconnaissance, high rework | Editing began before contracts were known | Require an evidence brief before edits |
| High tool wait | Repeated full builds/tests | Define focused checks and cache dependencies |
| High handoff time | Too many workers or verbose reports | Reduce workers; require four-field findings |
| High clarification count | Weak initial task contract | Use the top-level prompt template |
| Low clarification, wrong result | Agent guesses through material ambiguity | Add explicit ask/no-ask decision rules |
| Many tool calls, little progress | Serial reads and repeated polling | Batch independent calls; wait on conditions |
| Tests pass, defects escape | Verification misses real boundaries | Add integration scenarios and final diff review |
| Large diffs for small tasks | Scope is not controlled | Add allowed files and non-goals |
| Fast patches, slow review | Changes are hard to inspect | Make smaller coherent increments |

## 5. Suggested targets

These are starting points, not universal service-level objectives.

For a normal small-to-medium task:

- one initial reconnaissance batch;
- zero or one user clarification;
- one accepted implementation plan;
- no more than one material rewrite;
- focused tests on every behavior change;
- full-suite runs only when risk or policy requires them;
- no unrelated changed files;
- completion report under roughly 15 lines unless detail is requested.

Do not force a high-risk security change into the same latency target as a typo fix.

## 6. Run one-variable experiments

Examples:

### Experiment A: Batched reconnaissance

- Baseline: agent chooses tool calls freely.
- Change: require repository rules, status, requested files, history, and searches in one initial batch.
- Observe: time to first evidence, tool-call count, duplicate reads, defects.

### Experiment B: Verification ladder

- Baseline: full suite after each edit.
- Change: syntax and focused tests during implementation; full suite once at the end when justified.
- Observe: tool wait, rework, escaped defects.

### Experiment C: Structured worker output

- Baseline: workers return unrestricted prose.
- Change: finding/evidence/impact/unknown format with a bullet limit.
- Observe: handoff time, coordinator context size, contradictory decisions.

### Experiment D: One integration owner

- Baseline: multiple agents edit freely.
- Change: workers are read-only scouts or reviewers; one implementer owns overlapping files.
- Observe: merge conflicts, duplicated edits, rework.

Run enough similar tasks to avoid treating one unusually easy task as proof.

## 7. Instrument tool behavior

If your harness allows it, record:

```json
{
  "task_id": "123",
  "phase": "recon",
  "tool": "search",
  "started_at": "...",
  "duration_ms": 820,
  "input_size": 140,
  "output_size": 2400,
  "cache_hit": false,
  "result": "success",
  "evidence_used": true
}
```

Useful derived signals:

- calls whose output was never used;
- the same file read repeatedly;
- polling calls that return no state change;
- broad searches followed by narrow searches that could have run first;
- full builds invalidated immediately by another edit;
- worker reports too large to integrate efficiently.

Do not log secrets, source content unnecessarily, or hidden reasoning. Operational metadata and explicit outputs are enough.

## 8. Improve the environment before changing models

Many “slow agent” problems are environment problems:

- dependency caches are cold;
- test commands are undocumented;
- the repository lacks targeted tests;
- dev servers do not expose readiness signals;
- linters download themselves every run;
- generated files require a full build;
- network calls have no timeout;
- instruction files contradict CI.

High-value repository improvements include:

1. a command map in the agent instructions;
2. deterministic lockfiles;
3. focused package and component test targets;
4. a one-command CI-equivalent check;
5. build caches keyed by lockfile/toolchain;
6. machine-readable server health endpoints;
7. fixtures for external services;
8. clear ownership of generated files.

## 9. Quality guardrails

Never optimize away:

- authorization and tenant-boundary review;
- migration and rollback analysis;
- checksum or artifact-integrity checks;
- regression tests for confirmed bugs;
- disclosure of tests that did not run;
- protection of unrelated user changes;
- final review of remote side effects.

Instead, make those checks easier and more focused.

## 10. Weekly review template

```markdown
# Agent workflow review — week of YYYY-MM-DD

## Results
- Tasks completed:
- Median lead time:
- Rework rate:
- Escaped defects:

## Largest delay
[Measured bottleneck]

## Evidence
[Two or three representative tasks]

## One change for next week
[Single workflow/environment experiment]

## Guardrail
[Quality metric that must not regress]
```

The optimization loop is the same as good engineering elsewhere: observe, form one hypothesis, change one variable, and verify both speed and quality.
