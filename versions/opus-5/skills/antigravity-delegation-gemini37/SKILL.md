---
name: antigravity-delegation-gemini37
description: Policy for delegating bounded execution work from the Claude Code orchestrator to Antigravity CLI workers (gemini-3.7-flash-medium, gemini-3.7-flash-high, gemini-3.1-pro-high). Covers model and reasoning-effort routing, Git worktree isolation, task contracts, background invocation, and parallelism. Use whenever work is separable, bounded, and objectively verifiable — implementation, repetitive edits, refactors, migrations, frontend/UI, documentation and copy, data transformation, test writing, codebase research or analysis reads — or whenever several independent units of work could run in parallel, the task would consume a large amount of context, or the user asks to delegate, spawn a worker, use a subagent, or run something with Gemini or Antigravity.
---

# Antigravity Delegation

## Objective

The Claude Code main agent is the orchestrator. It owns architecture, task decomposition, shared contracts, integration, review, and final acceptance. Route bounded execution work to the lowest-cost worker likely to meet the required quality; delegation must improve model fit, parallelism, token availability, or context isolation enough to justify its overhead.

## Routing policy

1. Identify the capabilities, risk, and acceptance bar that determine success.
2. Exclude models unlikely to meet that bar; among qualified models, prefer higher Cost Efficiency. Use Intelligence only when task-specific fit is unclear.
3. For separable, bounded, objectively verifiable work, prefer the highest-Cost-Efficiency model that meets the required capability threshold. Keep work in the orchestrator when it is trivial, tightly coupled, or cheaper to complete directly than to delegate.
4. Validate delegated output. Fix an incomplete contract, missing context, or environment failure before changing models. If the worker still fails, make one targeted repair attempt, then raise reasoning effort or switch worker, then return the work to the orchestrator.
5. Do not use a second-model review unless risk or unresolved uncertainty justifies it. Stop when acceptance criteria are met.

Scores are routing estimates on a 0–100 scale; higher is better. Cost Efficiency reflects the user's subscription-adjusted cost, and Intelligence is only a secondary composite signal. The Gemini 3.7 Flash row is measured at High reasoning effort.

| Model            | Role                | Cost Eff. | Intelligence | Reasoning | Coding | Agentic | Math | Data | Language | Instruction |
| ---------------- | ------------------- | --------- | ------------ | --------- | ------ | ------- | ---- | ---- | -------- | ----------- |
| Opus 5           | Orchestrator (self) | 30        | 80           | 91        | 81     | 62      | 95   | 74   | 88       | 63          |
| Gemini 3.1 Pro   | Worker              | 86        | 77           | 84        | 76     | 44      | 91   | 78   | 85       | 79          |
| Gemini 3.7 Flash | Worker — default    | 92        | 78           | 87        | 79     | 58      | 93   | 68   | 85       | 80          |

The Opus 5 row describes you and is a reference baseline, not a delegation target; it has no slug and cannot be invoked. Read it two ways. Its lead in Agentic and Reasoning is why sustained autonomous multi-step work, open-ended exploration, and evolving judgement stay in the orchestrator. Its lowest Cost Efficiency is why everything else should leave: orchestrator capacity is the scarcest resource here, so delegating bounded work protects it. Where a worker trails Opus 5 on a score the task depends on, that gap is the quality you are trading for parallelism, token capacity, and context isolation.

## Reasoning effort

Gemini 3.7 Flash at Medium scores identically to High on **Coding** and **Agentic**, and lower on **Reasoning, Math, Data, Language, and Instruction**, at higher Cost Efficiency. Route on that split:

- Default to `gemini-3.7-flash-medium`.
- Use `gemini-3.7-flash-high` only when success depends on one of the five dimensions Medium gives up — non-trivial algorithmic or quantitative work, dense specifications, multi-constraint instructions that must all hold, or prose whose wording is the deliverable.
- Judge the dimension the task actually turns on, not its apparent size. A large mechanical refactor stays on Medium; a short function whose correctness is a proof does not.

## Default routes

- **`gemini-3.7-flash-medium`:** default for all bounded delegated work — implementation, repetitive edits, refactors, migrations, frontend/UI, documentation and copy, data transformation, test writing, straightforward coding, multi-step edits inside a worktree, iterative build-test-fix loops, and tasks needing exploration before the change is clear.
- **`gemini-3.7-flash-high`:** the same work when it depends on Reasoning, Math, Language, or Instruction, and the escalation target when Medium fails on capability rather than on contract or context.
- **`gemini-3.1-pro-high`:** work whose binding constraint is data handling — schema and dataset comprehension, data modelling, and large structured-data transformation.

There is no non-Gemini worker. Work needing judgement independent of the Gemini line stays in the orchestrator.

The orchestrator retains architecture, design, shared contracts, integration, review, and final acceptance. Delegate only bounded work where a worker's token capacity, parallelism, or context isolation adds material value.

## Worker entry points

Workers use the official Antigravity CLI through the authenticated subscription session; never request or use an API key.

`-Model` takes one of the three exact slugs above and nothing else. Reasoning effort is part of the slug, so it is always explicit at the call site; do not pass `--effort`. `agy models` also lists superseded Gemini generations, other effort levels, and Claude worker slugs — do not route to them, and never substitute another slug when the intended one is missing.

When invoking a worker, emit exactly one progress line before the call: `Delegating to <model slug>: <brief task>`. Do not repeat it in the final response unless the invocation fails.

```powershell
& "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" -WorkingDirectory $worktree -Model gemini-3.7-flash-medium -PromptFile $contract -AutoApprove
```

Use `-AutoApprove` only when the task contract authorizes the required local writes **and** every MCP server configured on the CLI is acceptable for this worker to use. It auto-approves every tool call, not just file writes inside the worktree; the worktree bounds the filesystem, not MCP. Omit it for read-only tasks. **Always invoke with `run_in_background: true`:** the wrapper's print timeout is ten minutes, which equals the PowerShell tool's foreground limit, so a foreground call can be killed before the worker finishes. Backgrounding is also what makes parallel delegation possible.

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
