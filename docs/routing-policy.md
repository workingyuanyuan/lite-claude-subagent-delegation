# Routing Policy Reference

## 1. Scope and Precedence

- `CLAUDE.md` is the authoritative single source of truth for all routing, delegation, capability scoring, and isolation policies.
- This document (`docs/routing-policy.md`) expands and operationalizes `CLAUDE.md` into actionable rules for operators.
- This document must never contradict `CLAUDE.md`. In any conflict or ambiguity between this document and `CLAUDE.md`, `CLAUDE.md` strictly governs.

## 2. Decision Procedure

Operators must execute the following 5-step decision procedure sequentially for every candidate task:

1. **Step 1: Determine Delegation Warrant**
   - **What is decided**: Whether to delegate the task to a Gemini worker or keep it in the Claude Code orchestrator.
   - **Criterion**: The task must be separable, bounded, and objectively verifiable, and delegation must provide a clear benefit in model fit, parallelism, token availability, or context isolation.
   - **Branch — Keep in Orchestrator**: If the task is trivial, tightly coupled, cheaper to complete directly, or involves orchestrator-reserved responsibilities (architecture, design, shared contracts, integration, review, final acceptance), the operator must keep the work in the orchestrator.
   - **Branch — Delegate**: If all delegation criteria are met, proceed to Step 2.

2. **Step 2: Verify Technical Preconditions**
   - **What is decided**: Whether the execution environment supports worker invocation.
   - **Criterion**: All five enforced preconditions must hold:
     1. `agy` (Antigravity CLI) is installed on `PATH` and authenticated against the user's subscription session.
     2. PowerShell 7+ (`#requires -Version 7.0`) is available.
     3. Wrapper script `$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1` exists.
     4. Target `$WorkingDirectory` is a valid directory and is a Git worktree root (`git rev-parse --is-inside-work-tree` returns `true` and `rev-parse --show-toplevel` matches `$WorkingDirectory`).
     5. Task contract file (`-PromptFile`) exists, is a leaf file, is non-empty, and contains valid UTF-8.
   - **Branch — Keep in Orchestrator**: If any precondition fails, the operator must not delegate; execute the work in the orchestrator and log the specific failure reason.
   - **Branch — Proceed**: If all preconditions hold, proceed to Step 3.

3. **Step 3: Evaluate Capability Threshold**
   - **What is decided**: Which worker models meet the required capability threshold and quality bar for the task.
   - **Criterion**: Assess task requirements against model capabilities and domain profiles:
     - `gemini-3.6-flash`: Qualified for bounded implementation, repetitive edits, migrations, frontend/UI, documentation/copy, data transformation, and straightforward coding.
     - `gemini-3.1-pro`: Qualified for dense specifications, instruction- or language-heavy work, and difficult quantitative work.
   - **Branch — Keep in Orchestrator**: If no Gemini model meets the required capability threshold, the operator must keep the task in the orchestrator.
   - **Branch — Proceed**: If one or more models qualify, proceed to Step 4.

4. **Step 4: Select Model by Cost Efficiency**
   - **What is decided**: Which qualified worker model to select for primary execution.
   - **Criterion**: Prefer the qualified model with the higher Cost Efficiency score (`gemini-3.6-flash` at 8.8 vs `gemini-3.1-pro` at 8.7). Intelligence (composite score) must be used as a secondary signal only when task-specific fit remains unclear.
   - **Branch — Select Gemini 3.6 Flash**: Select `gemini-3.6-flash` for straightforward coding, UI, copy, migrations, data transformation, or repetitive edits.
   - **Branch — Select Gemini 3.1 Pro**: Select `gemini-3.1-pro` when the task requires dense spec comprehension, instruction/language intensity, or complex math/quantitative work.
   - **Proceed**: Once the model is selected, proceed to Step 5.

5. **Step 5: Determine Isolation Mode and Execution Parameters**
   - **What is decided**: Worktree creation, approval flags (`-AutoApprove`), execution mode, and concurrency limits.
   - **Criterion**: Classify task mutation scope (read-only analysis vs bounded write vs shared contracts/architectural).
   - **Branch — Read-Only Analysis**: Pass repository root as `$WorkingDirectory`, omit `-AutoApprove`, execute in background (`run_in_background: true`), and parallelize with other independent read-heavy tasks.
   - **Branch — Bounded Write**: Create detached Git worktree (`git worktree add --detach <path> HEAD`), pass `-AutoApprove` (only if authorized by task contract for local writes), set `$WorkingDirectory` to worktree root, execute in background (`run_in_background: true`).
   - **Branch — Shared Contracts / Architectural**: Must serialize execution (no parallel writes permitted). If work touches core architecture, retain in orchestrator.

## 3. Orchestrator Reservations and Disqualifiers

### Orchestrator Reservations
The orchestrator strictly retains exclusive ownership of the following work classes:
1. **Architecture**: System architecture, structural design, and technical strategy.
2. **Design**: Component boundaries, module contracts, and high-level interface definitions.
3. **Shared Contracts**: Common schemas, public API definitions, shared protocols, dependency manifests, and global configuration.
4. **Integration**: Merging worker diffs, assembling multi-part deliverables, and resolving cross-component interactions.
5. **Review**: Evaluating worker diffs, verifying contract compliance, and assessing code quality.
6. **Final Acceptance**: Verifying system behavior against final acceptance criteria and authorizing release or deployment.

### Delegation Disqualifiers
The operator must not delegate work under any of the following three disqualifying conditions:
1. **Trivial Work**: Tasks so small or simple that contract creation and delegation overhead exceed the effort to complete them directly.
2. **Tightly Coupled Work**: Tasks that cannot be isolated into a self-contained worktree or contract without touching broad system dependencies.
3. **Work Cheaper to Complete Directly**: Tasks where context transfer, contract authoring, or worktree management cost more time or tokens than direct orchestrator execution.

## 4. Per-Model Routing Profiles

### Gemini 3.6 Flash
- **Model Alias**: `gemini-3.6-flash`
- **Resolved Antigravity Slug**: `gemini-3.6-flash-high`
- **Routed Work Classes**:
  - Bounded, objectively verifiable implementation
  - Repetitive edits
  - Migrations
  - Frontend/UI
  - Documentation and copy
  - Data transformation
  - Straightforward coding
- **Move-Off Signals**:
  - Task involves dense specifications or complex multi-document requirements.
  - Task requires instruction-heavy or language-heavy nuance beyond standard implementation.
  - Task involves difficult quantitative or mathematical modeling.
  - Worker fails to satisfy acceptance criteria after one targeted repair attempt.

### Gemini 3.1 Pro
- **Model Alias**: `gemini-3.1-pro`
- **Resolved Antigravity Slug**: `gemini-3.1-pro-high`
- **Routed Work Classes**:
  - Dense specifications
  - Instruction- or language-heavy work
  - Difficult quantitative work suitable for an external worker
- **Move-Off Signals**:
  - Task is straightforward coding or repetitive editing where `gemini-3.6-flash` meets the capability threshold (prefer higher Cost Efficiency).
  - Task requires architectural decisions, shared contract edits, or final integration reserved for the orchestrator.

### Model Capability Reference Table

All listed profiles use high reasoning effort. Scores are routing estimates; higher is better. Cost Efficiency reflects the user's subscription-adjusted cost, and Intelligence is only a secondary composite signal.

| Model            | Cost Eff. | Intelligence | Reasoning | Coding | Agentic | Math | Data | Language | Instruction |
| ---------------- | --------- | ------------ | --------- | ------ | ------- | ---- | ---- | -------- | ----------- |
| Gemini 3.1 Pro   | 8.7       | 7.7          | 8.5       | 7.6    | 4.5     | 9.1  | 7.8  | 8.5      | 7.9         |
| Gemini 3.6 Flash | 8.8       | 7.5          | 8.2       | 7.8    | 4.9     | 8.8  | 6.5  | 8.5      | 7.5         |

## 5. Conflict Resolution Rules

1. When **higher Cost Efficiency** conflicts with **meeting the required capability threshold**, prefer **meeting the capability threshold**, because Cost Efficiency is evaluated only among qualified models that are likely to achieve the required quality bar.
2. When **parallel execution efficiency** conflicts with **shared-contract safety**, prefer **serial execution (or keeping work in the orchestrator)**, because work affecting shared contracts, schemas, public interfaces, dependency manifests, global configuration, or architectural decisions requires strict serialization and orchestrator oversight.
3. When **conducting a second-model review** conflicts with **stopping at the acceptance bar**, prefer **stopping once acceptance criteria are met**, because second-model reviews add token and latency overhead and must not be used unless explicit risk or unresolved uncertainty justifies them.
4. When **delegation convenience** conflicts with **trivial or tightly coupled tasks**, prefer **keeping work in the orchestrator**, because delegation overhead is justified only when it materially improves model fit, parallelism, token availability, or context isolation.
5. When **execution speed** conflicts with **worktree isolation for write tasks**, prefer **creating a detached Git worktree**, because write tasks require strict isolation boundaries to allow clean diff review, verification, and rollback without corrupting the main worktree.

## 6. Failure and Escalation Ladder

Operators and orchestrators must follow this four-rung escalation ladder in strict order when handling worker task failures. Operators must not skip, reorder, or soften any rung.

1. **Rung 1: Contract, Context, and Environment Diagnosis**
   - **Trigger**: Worker task failure, invalid output, missing required return fields (`summary`, `changed_files`, `validation`, `risks`, `unresolved`), or script wrapper error.
   - **Action**: Inspect failure logs. Diagnose and fix any incomplete contract, missing repository context, unstated constraints, or environment failure (e.g., path resolution, missing `agy` CLI, UTF-8 encoding). Re-run the task on the original model profile.
   - **Condition for Advancing**: Contract, context, and environment are verified correct and complete, but the worker still produces failing or incomplete output.

2. **Rung 2: Targeted Repair Attempt**
   - **Trigger**: Worker failure occurring after contract and environment verification (Rung 1).
   - **Action**: Make exactly one targeted repair attempt by providing specific failure feedback, error logs, diff corrections, or refined instructions to the same worker model.
   - **Condition for Advancing**: The single targeted repair attempt fails to produce output satisfying the acceptance criteria.

3. **Rung 3: Switch to Better-Fit Gemini Worker**
   - **Trigger**: Failure of the single targeted repair attempt on the primary worker model (Rung 2).
   - **Action**: Switch to the better-fit alternative Gemini worker, selected against the failure mode rather than by rank — neither model dominates the other across the capability table. Issue a fresh task invocation with updated worker specifications.
   - **Condition for Advancing**: The alternative Gemini worker fails to satisfy the task acceptance criteria upon execution.

4. **Rung 4: Return Work to the Orchestrator**
   - **Trigger**: Failure of the alternative Gemini worker (Rung 3) to satisfy acceptance criteria.
   - **Action**: Reclaim the task completely. The Claude Code orchestrator executes the work directly, cleans up temporary worktrees, logs the delegation failure reason, and performs final verification.
   - **Condition for Advancing**: N/A (terminal rung of the escalation ladder).

## 7. Isolation Decision Table

| Task Type | Worktree Required | `-AutoApprove` Permitted | Parallelizable |
| --- | --- | --- | --- |
| Read-only analysis | No (pass repository root as `-WorkingDirectory`) | No (must omit `-AutoApprove`) | Yes (independent read-heavy tasks may run concurrently) |
| Bounded write | Yes (must create detached worktree: `git worktree add --detach <path> HEAD`) | Yes (only when authorized by task contract for local writes) | Yes (provided tasks have disjoint file ownership) |
| Work touching shared contracts, schemas, public interfaces, dependency manifests, global configuration, or architectural decisions | Yes (if delegated as a bounded write; otherwise kept in orchestrator) | Yes (only when authorized by task contract for local writes) | No (must serialize execution; parallel writes prohibited) |
