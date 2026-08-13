# Routing Policy Reference

## 1. Scope and Precedence

- The `antigravity-delegation-gemini36` skill (`versions/opus-5/skills/antigravity-delegation-gemini36/SKILL.md`) is the authoritative source of truth for routing, delegation, capability scoring, and isolation policy.
- `CLAUDE.md` holds only the trigger rule that tells the orchestrator when to load that skill. It deliberately contains no policy detail.
- This document expands the skill into operator-facing notes. It must never contradict the skill; in any conflict, the skill governs.

## 2. Decision Procedure

1. **Determine delegation warrant.** The task must be separable, bounded, and objectively verifiable, and delegation must improve model fit, parallelism, token availability, or context isolation. Keep the work in the orchestrator when it is trivial, tightly coupled, cheaper to finish directly, or falls under an orchestrator reservation (Section 3).
2. **Verify preconditions.** `agy` is on `PATH` and authenticated; PowerShell 7+ is available; the wrapper exists at `$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1`; `-WorkingDirectory` resolves to a Git worktree root; `-PromptFile` is a non-empty, valid UTF-8 file. The wrapper enforces all of these and throws otherwise.
3. **Evaluate the capability threshold.** Determine which models are likely to meet the acceptance bar for this specific task, using the capability table in Section 4.
4. **Select by Cost Efficiency among qualified models.** Prefer the highest Cost Efficiency that clears the threshold. Use Intelligence only when task-specific fit is unclear.
5. **Choose the isolation mode.** Read-only tasks take the repository root with no `-AutoApprove`. Write tasks take a dedicated detached worktree. Work touching shared contracts is serialized or kept in the orchestrator. Always invoke with `run_in_background: true`.

## 3. Orchestrator Reservations and Disqualifiers

The orchestrator retains architecture, design, shared contracts, integration, review, and final acceptance.

This is grounded in the capability table, not preference alone: the orchestrator leads every worker on Agentic. Work requiring sustained autonomous multi-step decisions, open-ended exploration, or judgement that evolves as the task unfolds therefore stays in the orchestrator regardless of Cost Efficiency.

The converse also follows from the table. The orchestrator has the lowest Cost Efficiency of any row, so its capacity is the scarcest resource in the system. Bounded work that a worker can complete should be delegated rather than absorbed, because absorbing it spends the most expensive capacity available.

Do not delegate work that is trivial (delegation overhead exceeds the work), tightly coupled (cannot be isolated into a worktree and a self-contained contract), or cheaper to complete directly.

## 4. Model Profiles

Scores are routing estimates on a 0–100 scale; higher is better. Cost Efficiency reflects the user's subscription-adjusted cost, and Intelligence is only a secondary composite signal.

| Model            | Role                | Cost Eff. | Intelligence | Reasoning | Coding | Agentic | Math | Data | Language | Instruction |
| ---------------- | ------------------- | --------- | ------------ | --------- | ------ | ------- | ---- | ---- | -------- | ----------- |
| Opus 5           | Orchestrator (self) | 30        | 80           | 91        | 81     | 62      | 95   | 74   | 88       | 63          |
| Opus 4.6         | Worker              | 60        | 74           | 88        | 78     | 49      | 89   | 70   | 83       | 63          |
| Gemini 3.1 Pro   | Worker              | 86        | 77           | 84        | 76     | 44      | 91   | 78   | 85       | 79          |
| Gemini 3.5 Flash | Worker              | 87        | 75           | 82        | 78     | 49      | 88   | 65   | 85       | 75          |
| Gemini 3.6 Flash | Worker — default    | 88        | 74           | 85        | 78     | 43      | 86   | 63   | 84       | 75          |

The Opus 5 row is a reference baseline describing the orchestrator itself. It has no wrapper alias and cannot be invoked; its purpose is to make the capability cost of delegating explicit rather than assumed.

### 4.1 Gemini 3.6 Flash

- **Alias / slug:** `gemini-3.6-flash` → `gemini-3.6-flash-high`
- **Routed work:** default for bounded, objectively verifiable implementation, repetitive edits, migrations, frontend/UI, documentation and copy, data transformation, and straightforward coding. It holds the highest Cost Efficiency of any worker and leads the Flash pair on Reasoning, which makes it the better single-pass worker.
- **Move off when:** the task is agentic in shape — multi-step, iterative, or requiring exploration before the change is clear (prefer 3.5 Flash); or turns on dense specification comprehension or instruction/language nuance (prefer 3.1 Pro); or on reasoning and comprehension depth (prefer Opus 4.6).

### 4.2 Gemini 3.5 Flash

- **Alias / slug:** `gemini-3.5-flash` → `gemini-3.5-flash-high`
- **Routed work:** bounded work that is agentic in shape — multi-step edits within a worktree, iterative build-test-fix loops, and tasks requiring exploration before the change is clear.
- **Selection rule against 3.6 Flash:** Agentic is the only material gap between the two (49 against 43). Cost Efficiency differs by one point and Coding and Instruction are tied, so route on task shape rather than price. Its Math and Data edge over 3.6 Flash is not a routing reason, because 3.1 Pro leads both by a wide margin and should take that work instead.
- **Move off when:** the task is a single-pass transformation where Reasoning carries it (prefer 3.6 Flash), or the shortfall is specification handling or quantitative depth (prefer 3.1 Pro).

### 4.3 Gemini 3.1 Pro

- **Alias / slug:** `gemini-3.1-pro` → `gemini-3.1-pro-high`
- **Routed work:** dense specifications, instruction- or language-heavy work, and difficult quantitative work suitable for an external worker. It leads every worker on Math, Data, and Instruction.
- **Move off when:** the task is straightforward coding or repetitive editing that a Flash worker already handles, since Cost Efficiency then governs.

### 4.4 Claude Opus 4.6

- **Alias / slug:** `claude-opus-4-6` → `claude-opus-4-6-thinking`
- **Slug note:** unlike the Gemini aliases, this slug carries no reasoning-effort suffix; thinking mode is intrinsic. There is no `-high` variant, and `--effort` must not be passed.
- **Routed work:** tasks whose binding constraint is reasoning or comprehension depth rather than volume — intricate debugging, refactors with subtle invariants, and large cross-file analysis reads. It is also the first escalation target when a Gemini worker fails on capability rather than on contract or context.
- **Move off when:** a Gemini worker already meets the acceptance bar, since Cost Efficiency then governs. Do not re-run completed work on Opus 4.6 for a marginal improvement.

## 5. Conflict Resolution

1. Meeting the capability threshold beats higher Cost Efficiency; Cost Efficiency is compared only among qualified models.
2. Shared-contract safety beats parallel throughput — serialize, or keep the work in the orchestrator.
3. Stopping at the acceptance bar beats an extra second-model review.
4. Keeping trivial or tightly coupled work in the orchestrator beats delegation convenience.
5. Worktree isolation for write tasks beats execution speed.

## 6. Failure Handling

1. **Diagnose contract, context, and environment first.** Worker failures, invalid output, missing return fields, and wrapper errors are most often caused by an incomplete contract, missing repository context, an unstated constraint, or an environment problem. Fix the cause and re-run on the same model. Switching models does not repair a bad contract.
2. **Make one targeted repair attempt.** Supply specific failure feedback, logs, or refined instructions to the same worker. Exactly one attempt.
3. **Switch to a better-fit worker.** Select against the observed failure mode rather than by rank. If the shortfall is reasoning or comprehension depth, prefer Opus 4.6; if it is specification, instruction handling, or quantitative depth, prefer Gemini 3.1 Pro; if the worker stalled on a multi-step or exploratory task rather than on the content itself, prefer Gemini 3.5 Flash.
4. **Return the work to the orchestrator.** Execute it directly, remove temporary worktrees, state the delegation failure reason, and perform final verification.

## 7. Isolation Reference

| Task type | Worktree | `-AutoApprove` | Parallel |
| --- | --- | --- | --- |
| Read-only analysis | Not required; pass the repository root | No | Yes, for independent reads |
| Bounded write | Required: `git worktree add --detach <path> HEAD` | Only when the contract authorizes the writes | Yes, with disjoint file ownership |
| Shared contracts, schemas, public interfaces, dependency manifests, global configuration, architecture | Required if delegated at all | Only when the contract authorizes the writes | No — serialize |

`-AutoApprove` expands to `--dangerously-skip-permissions`, which auto-approves every tool call the worker makes — including any MCP server configured on the Antigravity CLI. The wrapper's worktree-root check bounds the filesystem; `--add-dir` does not bound MCP. A worker running with the flag can therefore reach anything those servers reach, such as a GitHub server holding a credential. Before passing the flag, confirm that the server list in `~/.gemini/config/mcp_config.json` is acceptable for that task, and prefer granting the specific tools a worker needs under `userSettings.globalPermissionGrants.allow` in `~/.gemini/config/config.json` so the flag is not needed at all.
