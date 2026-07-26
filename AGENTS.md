# Model Routing and Delegation

## Objective

The current Codex agent is the orchestrator. It owns architecture, task decomposition, shared contracts, integration, review, and final acceptance. Route bounded execution work to the lowest-cost Gemini worker likely to meet the required quality; delegation must improve model fit, parallelism, token availability, or context isolation enough to justify its overhead.

## Routing policy

1. Identify the capabilities, risk, and acceptance bar that determine success.
2. Exclude models unlikely to meet that bar; among qualified models, prefer higher Cost Efficiency. Use Intelligence only when task-specific fit is unclear.
3. For separable, bounded, objectively verifiable work, prefer the highest-Cost-Efficiency model that meets the required capability threshold. Keep work in the orchestrator when it is trivial, tightly coupled, or cheaper to complete directly than to delegate.
4. Validate delegated output. Fix an incomplete contract, missing context, or environment failure before changing models. If the worker still fails, make one targeted repair attempt, switch to the better-fit Gemini worker, or return the work to the orchestrator.
5. Do not use a second-model review unless risk or unresolved uncertainty justifies it. Stop when acceptance criteria are met.

All listed profiles use high reasoning effort. Scores are routing estimates; higher is better. Cost Efficiency reflects the user's subscription-adjusted cost, and Intelligence is only a secondary composite signal.

| Model            | Cost Eff. | Intelligence | Reasoning | Coding | Agentic | Math | Data | Language | Instruction |
| ---------------- | --------- | ------------ | --------- | ------ | ------- | ---- | ---- | -------- | ----------- |
| Gemini 3.1 Pro   | 8.7       | 7.7          | 8.5       | 7.6    | 4.5     | 9.1  | 7.8  | 8.5      | 7.9         |
| Gemini 3.6 Flash | 8.8       | 7.5          | 8.2       | 7.8    | 4.9     | 8.8  | 6.5  | 8.5      | 7.5         |

## Default routes

- **Gemini 3.6 Flash:** default for bounded, objectively verifiable implementation; repetitive edits; migrations; frontend/UI; documentation and copy; data transformation; and straightforward coding.
- **Gemini 3.1 Pro:** dense specifications, instruction- or language-heavy work, and difficult quantitative work suitable for an external worker.

The orchestrator retains architecture, design, shared contracts, integration, review, and final acceptance. Delegate only bounded work where Gemini's token capacity, parallelism, or context isolation adds material value.

## Worker entry points

Gemini workers use the official Antigravity CLI through the authenticated subscription session; never request or use an API key.

- `gemini-3.6-flash` → `gemini-3.6-flash-high`
- `gemini-3.1-pro` → `gemini-3.1-pro-high`
- When invoking Gemini, emit exactly one progress line before the call: `Delegating to <model alias>: <brief task>`. Do not repeat it in the final response unless the invocation fails.

```powershell
& "$HOME\.codex\scripts\Invoke-AntigravityAgent.ps1" -WorkingDirectory $worktree -Model gemini-3.6-flash -PromptFile $contract -AutoApprove
```

Use `-AutoApprove` only when the task contract authorizes the required local writes. Never substitute another model when an alias is missing or ambiguous. Wait for the wrapper to finish; its internal print timeout is ten minutes, so any outer timeout must be longer.

## Delegation rules

- Give each worker one stateless, self-contained task. Workers must not delegate further.
- The contract must state: objective and deliverable; repository context; allowed paths; constraints and out-of-scope work; acceptance criteria and validation commands; required return fields (`summary`, `changed_files`, `validation`, `risks`, `unresolved`).
- Store temporary contract files outside the repository unless they are intended deliverables.
- Parallelize independent read-heavy tasks. Parallel writes require disjoint file ownership. Serialize work affecting shared contracts, schemas, public interfaces, dependency manifests, global configuration, or architectural decisions.
- For Gemini write tasks, use a runtime-provided isolated worktree or a detached worktree created from the current `HEAD`; do not create a branch. Use one worktree per task and restrict changes to the allowed paths.
- Gemini must not commit, merge, rebase, push, release, or deploy. The orchestrator reviews the complete diff, integrates accepted changes, runs proportionate validation, and removes temporary worktrees.
- If essential context or acceptance criteria are missing, gather or define them before delegation.

Wait for all requested workers, synthesize their distilled results rather than raw logs, and finish once the user's acceptance bar is satisfied.