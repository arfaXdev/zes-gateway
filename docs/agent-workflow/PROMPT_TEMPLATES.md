# Coding-Agent Prompt Templates

These templates reduce avoidable back-and-forth. Replace bracketed fields and delete sections that do not apply.

## 1. Top-level implementation prompt

```text
Goal
[Describe the user-visible result in one or two sentences.]

Repository and scope
- Repository: [name/path]
- In scope: [components/files/behaviors]
- Out of scope: [explicit non-goals]

Constraints
- Preserve: [API/config/data compatibility]
- Follow: [repository instructions and conventions]
- Dependencies: [allowed/not allowed]
- Remote actions: [none / commit / push / open PR]

Acceptance criteria
1. [Observable behavior]
2. [Failure behavior]
3. [Documentation or compatibility result]

Required verification
- [Focused test]
- [Build/type/lint check]
- [Integration test if needed]

Workflow
1. Inspect repository instructions, status, relevant files, callers, tests, and referenced history.
2. Batch independent reconnaissance.
3. Summarize confirmed facts and the proposed smallest patch.
4. Ask only if a material ambiguity remains; otherwise implement.
5. Review the final diff and report exact verification results.
```

Why this works: it gives the agent authority boundaries, a stopping condition, and a verification target.

## 2. Fast bug-fix prompt

```text
Reproduce and fix: [symptom].

Expected: [behavior]
Actual: [behavior]
Reproduction: [minimal steps or input]
Relevant logs/errors: [text]

Preserve [compatibility contract]. Do not refactor unrelated code.
Find the owning code path and nearest tests first. Add a regression test that fails before the fix and passes after it. Run focused tests, inspect the final diff, and report any broader suite not run.
```

## 3. Documentation and installer prompt

```text
Audit and correct [files]. Verify all claims against the repository and current release state.

Check specifically:
- commands are executable as written;
- environment variables reach the intended process;
- referenced artifacts/releases actually exist;
- platform and dependency requirements are explicit;
- branding and compatibility claims match the built artifact;
- local links and file permissions are correct;
- empty or stale sections are removed or repaired.

Use mocked command dependencies to exercise destructive or host-changing script paths safely. Do not claim a full build passed unless it ran.
```

## 4. Reconnaissance scout

Use one scout per independent question.

```text
Question
[One precise question whose answer can change the implementation plan.]

Scope
- Read only: [directories/files/history/API]
- Do not edit files.
- Do not solve adjacent problems.

Return at most [N] bullets in this format:
- Finding: [concise conclusion]
  Evidence: [path:line, command output, commit, or URL]
  Impact: [what this means for the plan]
  Unknown: [remaining uncertainty, if any]
```

Good question:

```text
Which code path selects the Playground model when navigating from a model row, and which tests cover it?
```

Bad question:

```text
Explore the frontend and tell me anything useful.
```

## 5. History and external-state scout

```text
Determine the current external state needed for this task.

Verify:
- [PR/issue/session/release]
- exact commit or artifact names;
- whether state is current, inherited, draft, prerelease, or published;
- whether the repository is a fork and where releases are actually hosted.

Prefer authoritative API output over search snippets. Do not modify local or remote state.

Return:
1. Confirmed facts with identifiers and URLs
2. Mismatches with local documentation/code
3. The minimum change implied by those facts
```

## 6. Test-mapping scout

```text
Map verification for [behavior]. Do not edit.

Return:
- closest existing tests;
- exact focused commands;
- fixtures/mocks already used by the repository;
- important untested failure paths;
- the smallest regression test that would prove the fix.
```

## 7. Implementer worker

Give an implementer an approved plan, not an open-ended problem.

```text
Implement only this approved slice:
[behavioral change]

Confirmed context:
[evidence brief]

Allowed files:
[list]

Acceptance criteria:
[list]

Required checks:
[list]

Do not expand scope or edit overlapping files. If a confirmed fact is wrong, stop and return the contradiction with evidence. Otherwise return:
- changed files;
- behavior implemented;
- checks run and outcomes;
- residual risks.
```

## 8. Final diff reviewer

The reviewer should receive the task contract and diff, not the implementer's persuasive narrative.

```text
Review the final diff against this contract:
[task card]

Prioritize:
1. correctness and regressions;
2. security, permissions, and secret handling;
3. compatibility and failure behavior;
4. misleading documentation;
5. missing tests;
6. unnecessary scope.

For each finding return:
- Severity: blocker / high / medium / low
- Location: file:line
- Problem: concrete failure, not preference
- Evidence or scenario: how it manifests
- Smallest fix: actionable correction

If there are no material findings, say so and list the residual risks or unrun checks. Do not invent findings to fill the response.
```

## 9. UI verification reviewer

```text
Review [page/flow] at desktop and narrow mobile widths.

Check:
- navigation and focus behavior;
- loading, empty, error, and populated states;
- keyboard and screen-reader labels;
- overflow and touch targets;
- direct URL and refresh behavior;
- whether actions preserve selected state;
- browser console and failed network requests.

Return screenshots or exact observations, viewport sizes, and reproducible defects. Separate visual preference from functional failure.
```

## 10. Security-focused reviewer

```text
Threat-model only the changed surface in [diff/files].

Trust boundaries:
[list]

Check:
- authorization before resource lookup or forwarding;
- secret leakage in logs/errors;
- path, URL, shell, and template injection;
- archive extraction and file permissions;
- unsafe retries or duplicate side effects;
- scope/tenant ownership checks;
- dependency and downloaded-artifact integrity;
- fail-open behavior.

Return concrete attack or failure paths with preconditions. Ignore generic advice unrelated to the diff.
```

## 11. Stalled-agent reset prompt

```text
Stop exploring. Do not edit yet.

In no more than 12 lines, return:
- the task's observable definition of done;
- confirmed facts;
- assumptions still being treated as facts;
- the single blocking unknown;
- one command or one user question that resolves it;
- the smallest viable next step.

Discard unrelated context and continue only from this summary.
```

## 12. Completion-report template

```text
Implemented
- [User-visible result]

Changed
- [Important change 1]
- [Important change 2]

Verified
- PASS: [command/check]
- PASS: [command/check]
- NOT RUN: [check] — [reason and residual risk]

Delivered
- Commit: [hash/message]
- Branch/PR/artifact: [location]
```

## 13. Compact task card

```markdown
# Task

## Goal

## Scope

## Constraints

## Acceptance criteria
- [ ]
- [ ]

## Evidence

## Decisions

## Verification
| Check | Result | Notes |
|---|---|---|
```

## Prompt design rules

1. **Describe outcomes, not keystrokes.** Let the agent follow repository patterns.
2. **Name non-goals.** This prevents opportunistic refactoring.
3. **State remote authority.** Committing, pushing, publishing, and deleting are different permissions.
4. **Require evidence format.** Short structured findings are easier to integrate than transcripts.
5. **Bound exploration.** Define the question and maximum useful response.
6. **Separate roles.** Scouts gather evidence; the coordinator decides; reviewers challenge the diff.
7. **Do not over-delegate.** One strong prompt plus batched tools is often faster than five agents.
8. **Make omissions explicit.** “Not run” is better than ambiguous silence.
