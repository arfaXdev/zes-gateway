# Coding-Agent Operating Playbook

Use this playbook as the control loop for one agent or for a coordinator with a few specialist workers.

## 1. Classify the task before exploring

Choose the lightest workflow that matches the risk.

| Class | Examples | Default behavior |
|---|---|---|
| Tiny | Typo, broken link, obvious constant | Inspect the file, edit, run one focused check |
| Normal | Bug fix, small feature, installer update | Bounded reconnaissance, short plan, focused and subsystem tests |
| High risk | Auth, billing, data migration, release process | Broader call-site review, explicit threat/failure analysis, integration tests |
| Unknown | Vague report or unfamiliar subsystem | Reconnaissance first; do not guess the implementation |

Complexity is not line count. A two-line authorization change may be high risk.

## 2. Create a task card

Write this before editing:

```text
Goal: One sentence describing the user-visible outcome.
In scope: Files, components, or behavior allowed to change.
Out of scope: Explicit non-goals.
Constraints: Compatibility, security, branch, style, or dependency rules.
Acceptance criteria:
- Observable result 1
- Observable result 2
Required evidence: Tests, build, screenshot, command output, or review.
```

### Ask the user only for blocking ambiguity

Ask when two reasonable interpretations would produce materially different or irreversible outcomes, such as:

- changing a public API versus preserving compatibility;
- deleting data versus migrating it;
- using an upstream binary versus compiling a customized fork;
- publishing a release versus preparing release files only.

Do not ask about details that repository conventions or a quick inspection can answer.

## 3. Run bounded reconnaissance

### First batch

Gather independent facts together:

```text
A. Repository rules
   - agent instruction files
   - contribution and test guidance

B. Working state
   - branch and status
   - recent commits
   - relevant uncommitted changes

C. Requested surface
   - named files
   - definitions and direct callers
   - nearby tests

D. Referenced state
   - linked issue, PR, release, or documentation
   - only if the request depends on it
```

### Search before reading whole directories

Prefer a narrowing sequence:

1. exact symbol or phrase search;
2. file list and call sites;
3. relevant line ranges;
4. full file only when its structure matters.

A 30-line evidence extract is usually more useful than adding ten complete files to context.

### Stop reconnaissance when

You can answer all four questions:

1. Where does the behavior live?
2. What contract must remain stable?
3. Which existing pattern should the patch follow?
4. How will the result be verified?

If new evidence invalidates the plan later, return to reconnaissance deliberately. Do not keep browsing “just in case.”

## 4. Produce an evidence brief

Separate facts from assumptions:

```text
Confirmed
- path/to/file:line owns the behavior.
- Existing test X checks the success path.
- Configuration Y defaults to false.

Assumptions to verify
- The external asset uses archive naming convention Z.

Decision
- Extend the existing adapter instead of adding a parallel abstraction.

Risks
- A fallback could silently change branding.
- A retry could duplicate a non-idempotent operation.
```

For external facts, save the URL or API output that supports the conclusion.

## 5. Plan the smallest complete patch

A good plan names behavior and evidence, not just files:

```text
1. Add validation at the configuration boundary.
2. Preserve the existing internal interface.
3. Add table cases for valid, invalid, and compatibility inputs.
4. Run package tests, then the integration check touching that boundary.
```

### Prefer one integration owner

One coordinator should own:

- the task card;
- the evidence brief;
- the accepted plan;
- the final diff;
- the verification report.

Workers may gather evidence or propose patches, but they should not independently redefine scope.

## 6. Decide whether to delegate

Delegate only if the work streams are independent enough to run concurrently.

### Good delegation

- Scout A maps implementation and callers.
- Scout B checks history, issues, or external release state.
- Scout C identifies tests and commands.
- A reviewer audits the completed diff.

### Bad delegation

- Three agents each inspect the same five files.
- Two agents edit the same function.
- A worker receives “fix the bug” without acceptance criteria.
- The coordinator forwards entire transcripts instead of a compact brief.

### Delegation rule of thumb

Use a worker when all are true:

1. the question is independently answerable;
2. its answer can change the plan;
3. it likely takes longer than the handoff overhead;
4. the output format can be made precise.

Require worker responses in this form:

```text
Finding:
Evidence:
Impact on plan:
Risks or unknowns:
```

## 7. Implement in reviewable increments

### Editing rules

- Make the smallest coherent change.
- Follow an existing repository pattern when one exists.
- Avoid unrelated cleanup.
- Preserve compatibility unless the task explicitly changes it.
- Add comments only for non-obvious decisions, not a narration of the code.
- Update tests and user-facing documentation with the behavior change.

### Check after each logical increment

Use a focused check that takes seconds, not the full suite. Examples:

- parser or syntax validation after changing a script;
- one unit-test package after changing a function;
- type checking after changing an interface;
- local link validation after changing documentation.

Do not run a costly suite repeatedly while the patch is still moving.

### Maintain a clean work boundary

Before and after editing:

```bash
git status --short
git diff --check
git diff --stat
```

Never overwrite unrelated user changes. If the working tree is already dirty, identify ownership before modifying overlapping files.

## 8. Verify through a risk-based ladder

| Level | Check | Run when |
|---:|---|---|
| 0 | Diff whitespace and generated-file check | Every task |
| 1 | Syntax, parser, formatter, linter | Relevant tool exists |
| 2 | Tests directly covering changed behavior | Every behavior change |
| 3 | Package or subsystem suite | Shared code or multiple callers changed |
| 4 | Integration or end-to-end test | Boundaries, storage, network, UI flow, or packaging changed |
| 5 | Full CI-equivalent suite | High risk, broad change, or pre-merge policy |

### Verify failure paths

At minimum, consider:

- malformed input;
- missing dependency or configuration;
- unavailable network or service;
- partial output;
- permission failure;
- retry behavior;
- compatibility input;
- cleanup after interruption.

For shell installers, mock commands and test both release and fallback paths without modifying the host.

### Treat unavailable tests honestly

Report:

```text
Not run: full Go test suite
Reason: Go toolchain is unavailable in the environment
Compensating evidence: shell syntax checks and mocked release/source paths passed
Residual risk: real compilation remains to be confirmed by CI
```

Never imply that a check passed when it did not run.

## 9. Review the final diff as a stranger

Ignore your implementation narrative and inspect only the result.

### Review checklist

- Does every changed line serve the task?
- Is the behavior consistent with the task card?
- Are names and messages accurate?
- Did documentation claim more than tests prove?
- Are error and rollback paths safe?
- Are secrets or credentials exposed?
- Are external resources mutable, unavailable, or unverified?
- Did file permissions change intentionally?
- Is there a smaller patch with the same behavior?
- Are there stale headings, comments, or examples?

For a large diff, review by risk area rather than file order.

## 10. Deliver a concise evidence report

A useful completion message contains:

```text
Outcome
- What now works for the user.

Key changes
- Two to five important implementation points.

Verification
- Exact checks and results.
- Anything not run and why.

Location
- Files, commit, branch, PR, or artifact.
```

Do not dump a command-by-command transcript unless the user asks for it.

## 11. Suggested coordinator state machine

```text
INTAKE
  -> classify risk
  -> write task card

RECON
  -> launch independent evidence requests together
  -> wait once for their results
  -> synthesize evidence brief

DECIDE
  -> ask user only if ambiguity is blocking
  -> otherwise select smallest viable plan

IMPLEMENT
  -> edit one coherent slice
  -> run a cheap local check
  -> repeat only when necessary

VERIFY
  -> focused tests
  -> broader tests according to risk
  -> record omissions honestly

REVIEW
  -> inspect final diff
  -> repair findings
  -> rerun affected checks

DELIVER
  -> commit/push only within granted authority
  -> report outcome and evidence
```

## 12. Recovery protocol when the agent stalls

If no material progress occurs for several tool calls:

1. Stop issuing more exploratory calls.
2. Restate the task card in one sentence.
3. List confirmed facts and the single blocking unknown.
4. Run one targeted command to resolve that unknown—or ask the user.
5. Drop abandoned hypotheses from active context.
6. Resume with a smaller plan.

If tests repeatedly fail for unrelated environmental reasons, isolate the environment problem from the code problem and report both separately.

## 13. Repository-specific command map

Give your agent a small, maintained table rather than making it rediscover commands every task:

```text
Formatting:        <command>
Fast unit tests:   <command>
Package tests:     <command>
Frontend check:    <command>
Integration tests: <command>
Full CI:           <command>
Build:             <command>
```

Keep this in the repository's agent instructions or contributor guide. Update it when CI changes.

The best agent workflow is boring: a stable loop, small evidence packets, few handoffs, and checks matched to risk.
