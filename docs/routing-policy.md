# Routing Policy Reference

## 1. Scope and Precedence

- The `antigravity-delegation-gemini37` skill (`versions/opus-5/skills/antigravity-delegation-gemini37/SKILL.md`) is the authoritative source of truth for routing, delegation, capability scoring, and isolation policy.
- `CLAUDE.md` holds only the trigger rule that tells the orchestrator when to load that skill. It deliberately contains no policy detail.
- This document expands the skill into operator-facing notes. It must never contradict the skill; in any conflict, the skill governs.

## 2. Decision Procedure

1. **Determine delegation warrant.** The task must be separable, bounded, and objectively verifiable, and delegation must improve model fit, parallelism, token availability, or context isolation. Keep the work in the orchestrator when it is trivial, tightly coupled, cheaper to finish directly, or falls under an orchestrator reservation (Section 3).
2. **Verify preconditions.** `agy` is on `PATH` and authenticated; PowerShell 7+ is available; the wrapper exists at `$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1`; `-WorkingDirectory` resolves to a Git worktree root; `-PromptFile` is a non-empty, valid UTF-8 file. The wrapper enforces all of these and throws otherwise.
3. **Evaluate the capability threshold.** Determine which models are likely to meet the acceptance bar for this specific task, using the capability table in Section 4.
4. **Select the model, then the reasoning effort.** Prefer the highest Cost Efficiency that clears the threshold (Section 4), then choose Medium or High by the rule in Section 4.1. Use Intelligence only when task-specific fit is unclear.
5. **Choose the isolation mode.** Read-only tasks take the repository root with no `-AutoApprove`. Write tasks take a dedicated detached worktree. Work touching shared contracts is serialized or kept in the orchestrator. Always invoke with `run_in_background: true`.

## 3. Orchestrator Reservations and Disqualifiers

The orchestrator retains architecture, design, shared contracts, integration, review, and final acceptance.

This is grounded in the capability table, not preference alone: the orchestrator leads every worker on Agentic and Reasoning. Work requiring sustained autonomous multi-step decisions, open-ended exploration, or judgement that evolves as the task unfolds therefore stays in the orchestrator regardless of Cost Efficiency.

The converse also follows from the table. The orchestrator has the lowest Cost Efficiency of any row, so its capacity is the scarcest resource in the system. Bounded work that a worker can complete should be delegated rather than absorbed, because absorbing it spends the most expensive capacity available.

Since the worker set is now a single model family (Section 4.0), the orchestrator additionally holds any work that needs judgement independent of the Gemini line — most concretely, reviewing delegated output. A failure mode shared across Gemini generations has no cross-family worker left to catch it, so orchestrator review is the only place it can surface.

Do not delegate work that is trivial (delegation overhead exceeds the work), tightly coupled (cannot be isolated into a worktree and a self-contained contract), or cheaper to complete directly.

## 4. Model Profiles

Scores are routing estimates on a 0–100 scale; higher is better. Cost Efficiency reflects the user's subscription-adjusted cost, and Intelligence is only a secondary composite signal. The Gemini 3.7 Flash row is measured at High reasoning effort; Section 4.1 covers Medium.

| Model            | Role                | Cost Eff. | Intelligence | Reasoning | Coding | Agentic | Math | Data | Language | Instruction |
| ---------------- | ------------------- | --------- | ------------ | --------- | ------ | ------- | ---- | ---- | -------- | ----------- |
| Opus 5           | Orchestrator (self) | 30        | 80           | 91        | 81     | 62      | 95   | 74   | 88       | 63          |
| Gemini 3.1 Pro   | Worker              | 86        | 77           | 84        | 76     | 44      | 91   | 78   | 85       | 79          |
| Gemini 3.7 Flash | Worker — default    | 92        | 78           | 87        | 79     | 58      | 93   | 68   | 85       | 80          |

The Opus 5 row is a reference baseline describing the orchestrator itself. It has no slug and cannot be invoked; its purpose is to make the capability cost of delegating explicit rather than assumed.

### 4.0 What Changed at Gemini 3.7 Flash

Two workers were retired at this generation, for two different reasons.

**The Flash pair collapsed into one model.** The previous generation ran both 3.6 Flash and 3.5 Flash because 3.6 led on Reasoning while 3.5 led on Agentic, forcing a route by task shape. Gemini 3.7 Flash takes the top worker score on Cost Efficiency, Intelligence, Reasoning, Coding, Agentic, Math, and Instruction simultaneously, so no shape of bounded work has a reason to route around it. Its Agentic score of 58 is the largest single jump in the table and sits close to the orchestrator's 62; multi-step edits inside a worktree, build-test-fix loops, and exploratory tasks are now default-route work rather than a separate route. The orchestrator reservation in Section 3 still holds, because it rests on open-ended judgement with no fixed acceptance bar, not on step count.

**Claude Opus 4.6 was removed entirely.** It led 3.7 Flash by one point on Reasoning and two on Data — inside the noise of estimated scores — while trailing on every other dimension at roughly two thirds of the Cost Efficiency. No task description could honestly justify selecting it, so keeping it in the table would only invite misrouting on a remembered reputation for depth. Its slug is still offered by `agy models`; the wrapper's allowlist is what makes the retirement real.

This has a cost worth stating plainly rather than discovering later. Opus 4.6 was the only worker outside the Gemini line, so the delegation system no longer has a cross-family second opinion. Escalation is now *raise reasoning effort, then return to the orchestrator* (Section 6), and any error mode common to Gemini models must be caught by orchestrator review. That is a deliberate trade of redundancy for cost, made because the capability table no longer supports paying for the redundancy.

### 4.1 Reasoning Effort: Medium as the Default

Reasoning effort is part of the Antigravity slug, so it is chosen at every call. For Gemini 3.7 Flash the choice is not a general quality dial — it moves some dimensions and not others:

| Dimension | Medium relative to High |
| --- | --- |
| Coding | Identical |
| Agentic | Identical |
| Reasoning, Math, Data, Language, Instruction | Lower |
| Cost Efficiency | Higher — fewer reasoning tokens for the same Coding and Agentic |

Coding and Agentic are precisely the dimensions most bounded delegated work turns on: writing the change, editing across files, running the build, reading the failure, and fixing it. High buys nothing on either. Medium is therefore the default, and High is a targeted upgrade rather than a safer choice.

Route to `gemini-3.7-flash-high` when success depends on one of the five dimensions Medium gives up:

- **Reasoning / Math** — non-trivial algorithms, concurrency or invariant arguments, quantitative derivation.
- **Instruction** — dense specifications, or multi-constraint contracts where every constraint must hold simultaneously.
- **Language** — copy, documentation, or naming where the wording itself is the deliverable rather than a byproduct.
- **Data** — only if 3.1 Pro is unavailable; otherwise data-bound work belongs in Section 4.3.

Judge the dimension the task turns on, not its apparent size. A thousand-line mechanical refactor is Coding and Agentic work and stays on Medium; a twenty-line function whose correctness is an argument does not. When a task is genuinely mixed, prefer Medium first: escalating after an observed failure costs one re-run, while defaulting to High costs on every task that never needed it.

### 4.2 Gemini 3.7 Flash

- **Slugs:** `gemini-3.7-flash-medium` (default), `gemini-3.7-flash-high` (targeted upgrade per Section 4.1)
- **Routed work:** all bounded delegated work — implementation, repetitive edits, refactors, migrations, frontend/UI, documentation and copy, data transformation, test writing, straightforward coding, multi-step edits within a worktree, iterative build-test-fix loops, and tasks requiring exploration before the change is clear.
- **Move off when:** the binding constraint is data handling, where 3.1 Pro leads by ten points even against High (prefer 3.1 Pro); or High has already failed the task on capability, which exhausts the worker set and returns the work to the orchestrator.

### 4.3 Gemini 3.1 Pro

- **Slug:** `gemini-3.1-pro-high` — Antigravity publishes no Medium tier for 3.1 Pro, so High is the only routed effort.
- **Routed work:** work whose binding constraint is data handling — schema and dataset comprehension, data modelling, and large structured-data transformation. Data (78 against 68) is the only dimension on which it clearly leads the default worker.
- **Move off when:** the task is ordinary coding, editing, or specification-following work. Its former instruction- and language-heavy route no longer applies: 3.7 Flash matches it on Language and leads it on Instruction at higher Cost Efficiency, even before the Medium-tier cost advantage.

### 4.4 Retired: Claude Opus 4.6

Not a delegation target. `agy models` still lists its thinking-mode slug, but the wrapper's allowlist rejects it, and it must not be reintroduced on a reasoning-depth argument — see Section 4.0 for why the current table does not support one. Work that genuinely needs non-Gemini judgement stays in the orchestrator.

The retired slug is deliberately not written out anywhere in this repository, so that a search for it returns only real routing references. `tests/Test-OrchestratorConfig.ps1` enforces this: any worker-slug-shaped token outside the wrapper's allowlist fails the run.

## 5. Conflict Resolution

1. Meeting the capability threshold beats higher Cost Efficiency; Cost Efficiency is compared only among qualified models.
2. Shared-contract safety beats parallel throughput — serialize, or keep the work in the orchestrator.
3. Stopping at the acceptance bar beats an extra second-model review.
4. Keeping trivial or tightly coupled work in the orchestrator beats delegation convenience.
5. Worktree isolation for write tasks beats execution speed.
6. Medium effort beats High whenever the task turns on Coding or Agentic, because the scores are identical there and Medium is cheaper.

## 6. Failure Handling

The worker set is one model family with one effort upgrade, so the escalation ladder is short. Do not skip steps to reach the end of it faster; steps 1 and 2 fix the majority of failures, and step 3 cannot repair a bad contract.

1. **Diagnose contract, context, and environment first.** Worker failures, invalid output, missing return fields, and wrapper errors are most often caused by an incomplete contract, missing repository context, an unstated constraint, or an environment problem. Fix the cause and re-run on the same slug. Raising effort does not repair a bad contract.
2. **Make one targeted repair attempt.** Supply specific failure feedback, logs, or refined instructions to the same worker. Exactly one attempt.
3. **Change the slug, selecting against the observed failure mode.** If the shortfall is data or schema handling, move to `gemini-3.1-pro-high`. If it is reasoning, quantitative, instruction-following, or language quality, move from `gemini-3.7-flash-medium` to `gemini-3.7-flash-high`. If the failure was a stall on a multi-step or exploratory task, that is not an effort problem — Medium and High score identically on Agentic — so treat it as a contract problem and return to step 1.
4. **Return the work to the orchestrator.** With Opus 4.6 retired this is the immediate next step after step 3, not a last resort after further worker attempts. Execute the work directly, remove temporary worktrees, state the delegation failure reason, and perform final verification.

## 7. Isolation Reference

| Task type | Worktree | `-AutoApprove` | Parallel |
| --- | --- | --- | --- |
| Read-only analysis | Not required; pass the repository root | No | Yes, for independent reads |
| Bounded write | Required: `git worktree add --detach <path> HEAD` | Only when the contract authorizes the writes | Yes, with disjoint file ownership |
| Shared contracts, schemas, public interfaces, dependency manifests, global configuration, architecture | Required if delegated at all | Only when the contract authorizes the writes | No — serialize |

`-AutoApprove` expands to `--dangerously-skip-permissions`, which auto-approves every tool call the worker makes — including any MCP server configured on the Antigravity CLI. The wrapper's worktree-root check bounds the filesystem; `--add-dir` does not bound MCP. A worker running with the flag can therefore reach anything those servers reach, such as a GitHub server holding a credential. Before passing the flag, confirm that the server list in `~/.gemini/config/mcp_config.json` is acceptable for that task, and prefer granting the specific tools a worker needs under `userSettings.globalPermissionGrants.allow` in `~/.gemini/config/config.json` so the flag is not needed at all.

## 8. Version Migration

The skill name carries the Gemini worker generation (`antigravity-delegation-gemini37`), so upgrading is a rename, not an in-place edit of the previous policy. When a new generation ships:

1. Rename the skill directory to the new generation and update the capability table, slugs, and routes inside it.
2. Update the `ValidateSet` in `Invoke-AntigravityAgent.ps1` so retired models and effort tiers can no longer be invoked, even while `agy models` still lists them. The allowlist holds exact Antigravity slugs, so retiring a model means deleting its slug — nothing else references it.
3. Update the skill name in `versions/<generation>/CLAUDE.md`, this document, and `README.md`.
4. Run `tests/Test-OrchestratorConfig.ps1` to confirm the slug set is consistent across every surface and still offered by `agy models`.
5. Reinstall with `./install.ps1 -Version opus-5 -Force`, then delete the retired skill directory from `$HOME\.claude\skills\`; the installer copies files and never removes a skill that is no longer shipped.

When a generation changes which effort tiers are worth routing to, re-derive Section 4.1 from the new scores rather than carrying the Medium-default rule forward. It holds only because Medium and High tie on Coding and Agentic; a generation where they do not tie needs a different rule.
