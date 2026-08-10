---
name: antigravity-delegation-gemini36
description: Policy for delegating bounded execution work from the Claude Code orchestrator to Antigravity CLI workers (gemini-3.6-flash, gemini-3.5-flash, gemini-3.1-pro, claude-opus-4-6). Covers model routing, Git worktree isolation, task contracts, background invocation, and parallelism. Use whenever work is separable, bounded, and objectively verifiable — implementation, repetitive edits, refactors, migrations, frontend/UI, documentation and copy, data transformation, test writing, codebase research or analysis reads — or whenever several independent units of work could run in parallel, the task would consume a large amount of context, or the user asks to delegate, spawn a worker, use a subagent, or run something with Gemini, Opus 4.6, or Antigravity.
---

# Antigravity Delegation

## Objective

The Claude Code main agent is the orchestrator. It owns architecture, task decomposition, shared contracts, integration, review, and final acceptance. Route bounded execution work to the lowest-cost worker likely to meet the required quality; delegation must improve model fit, parallelism, token availability, or context isolation enough to justify its overhead.

## Routing policy

1. Identify the capabilities, risk, and acceptance bar that determine success.
2. Exclude models unlikely to meet that bar; among qualified models, prefer higher Cost Efficiency. Use Intelligence only when task-specific fit is unclear.
3. For separable, bounded, objectively verifiable work, prefer the highest-Cost-Efficiency model that meets the required capability threshold. Keep work in the orchestrator when it is trivial, tightly coupled, or cheaper to complete directly than to delegate.
4. Validate delegated output. Fix an incomplete contract, missing context, or environment failure before changing models. If the worker still fails, make one targeted repair attempt, then switch to a better-fit worker, then return the work to the orchestrator.
5. Do not use a second-model review unless risk or unresolved uncertainty justifies it. Stop when acceptance criteria are met.

Scores are routing estimates on a 0–100 scale; higher is better. Cost Efficiency reflects the user's subscription-adjusted cost, and Intelligence is only a secondary composite signal.

| Model            | Role                | Cost Eff. | Intelligence | Reasoning | Coding | Agentic | Math | Data | Language | Instruction |
| ---------------- | ------------------- | --------- | ------------ | --------- | ------ | ------- | ---- | ---- | -------- | ----------- |
| Opus 5           | Orchestrator (self) | 30        | 80           | 91        | 81     | 62      | 95   | 74   | 88       | 63          |
| Opus 4.6         | Worker              | 60        | 74           | 88        | 78     | 49      | 89   | 70   | 83       | 63          |
| Gemini 3.1 Pro   | Worker              | 86        | 77           | 84        | 76     | 44      | 91   | 78   | 85       | 79          |
| Gemini 3.5 Flash | Worker              | 87        | 75           | 82        | 78     | 49      | 88   | 65   | 85       | 75          |
| Gemini 3.6 Flash | Worker — default    | 88        | 74           | 85        | 78     | 43      | 86   | 63   | 84       | 75          |

The Opus 5 row describes you and is a reference baseline, not a delegation target; it has no alias and cannot be invoked. Read it two ways. Its lead in Agentic is why sustained autonomous multi-step work, open-ended exploration, and evolving judgement stay in the orchestrator. Its lowest Cost Efficiency is why everything else should leave: orchestrator capacity is the scarcest resource here, so delegating bounded work protects it. Where a worker trails Opus 5 on a score the task depends on, that gap is the quality you are trading for parallelism, token capacity, and context isolation.

## Default routes

- **Gemini 3.6 Flash:** default for bounded, objectively verifiable implementation; repetitive edits; migrations; frontend/UI; documentation and copy; data transformation; and straightforward coding. Prefer it for single-pass work.
- **Gemini 3.5 Flash:** bounded work that is agentic in shape — multi-step edits inside the worktree, iterative build-test-fix loops, and tasks needing exploration before the change is clear.
- **Gemini 3.1 Pro:** dense specifications, instruction- or language-heavy work, and difficult quantitative work suitable for an external worker.
- **Opus 4.6:** work whose binding constraint is reasoning or comprehension depth rather than volume — intricate debugging, refactors with subtle invariants, and large cross-file analysis reads. Also the first escalation target when a Gemini worker fails on capability rather than on contract or context.

The orchestrator retains architecture, design, shared contracts, integration, review, and final acceptance. Delegate only bounded work where a worker's token capacity, parallelism, or context isolation adds material value.

## Worker entry points

Workers use the official Antigravity CLI through the authenticated subscription session; never request or use an API key.

- `gemini-3.6-flash` → `gemini-3.6-flash-high`
- `gemini-3.5-flash` → `gemini-3.5-flash-high`
- `gemini-3.1-pro` → `gemini-3.1-pro-high`
- `claude-opus-4-6` → `claude-opus-4-6-thinking`

The Gemini slugs carry reasoning effort as a suffix; Opus 4.6 ships only in thinking mode and has no `-high` variant. Do not pass `--effort`. Never substitute another model when an alias is missing or ambiguous.

When invoking a worker, emit exactly one progress line before the call: `Delegating to <model alias>: <brief task>`. Do not repeat it in the final response unless the invocation fails.

```powershell
& "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" -WorkingDirectory $worktree -Model gemini-3.6-flash -PromptFile $contract -AutoApprove
```

Use `-AutoApprove` only when the task contract authorizes the required local writes. **Always invoke with `run_in_background: true`:** the wrapper's print timeout is ten minutes, which equals the PowerShell tool's foreground limit, so a foreground call can be killed before the worker finishes. Backgrounding is also what makes parallel delegation possible.

## Delegation rules

- Delegation requires a Git repository; the wrapper rejects any `-WorkingDirectory` that is not a worktree root. Outside a repository there is no isolation boundary, so keep the work in the orchestrator.
- Give each worker one stateless, self-contained task. Workers must not delegate further.
- The contract must state: objective and deliverable; repository context; allowed paths; constraints and out-of-scope work; acceptance criteria and validation commands; required return fields (`summary`, `changed_files`, `validation`, `risks`, `unresolved`).
- Store temporary contract files outside the repository unless they are intended deliverables.
- Parallelize independent read-heavy tasks. Parallel writes require disjoint file ownership. Serialize work affecting shared contracts, schemas, public interfaces, dependency manifests, global configuration, or architectural decisions.
- For write tasks, create a detached worktree from the current `HEAD`; do not create a branch. Use one worktree per task and restrict changes to the allowed paths. For read-only tasks, pass the repository root and omit `-AutoApprove`.

  ```bash
  git worktree add --detach <worktree-path> HEAD
  ```

- Workers must not commit, merge, rebase, push, release, or deploy. The orchestrator reviews the complete diff, integrates accepted changes, runs proportionate validation, and removes temporary worktrees.

  ```bash
  git -C <worktree-path> diff
  git worktree remove <worktree-path>
  ```

- If essential context or acceptance criteria are missing, gather or define them before delegation.

Wait for all requested workers, synthesize their distilled results rather than raw logs, and finish once the user's acceptance bar is satisfied.
