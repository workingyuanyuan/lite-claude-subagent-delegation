---
name: delegate
description: Delegate work to Codex (GPT), agy (Gemini), or Opus subagents when it saves context or improves quality — review of code you wrote, design second opinions, image/PDF/audio/video work, mechanical edits, hard root-cause investigation, large merge-bound implementation.
---

# Delegate

Delegate when it saves your context or improves quality, and checking the result costs less than doing the work. Do not delegate evidence-backed research reports. Treat every result as unverified.

## Select a configuration

| Model ID | Effort | Task fit |
| --- | --- | --- |
| Agent tool `opus` | `medium` | Merge-bound code too large for your context; otherwise write it yourself. |
| `gpt-6.1-sol` | `medium` | Review of code you wrote; non-merged backend work: repro scripts, load tests, one-off tools, backend investigation. |
| `gpt-6.1-sol` | `high` | Large or risky diffs, or when medium fails acceptance. |
| `gpt-6-astra` | `medium` | Design discussion, architecture second opinion, root-cause hypotheses before you act. |
| `gemini-4-argon-medium` | in ID | Review or opinions that require images, PDFs, audio, or video. |
| `gemini-3.8-flash-medium` | in ID | Multimodal extraction; mechanical edits: renames, format conversion, boilerplate, tests that follow examples. |
| `gemini-3.8-flash-high` | in ID | The above when medium fails acceptance or the task is clearly hard. |
| `gemini-3.8-flash-medium` + `/boost` | in ID | Hard root-cause investigation (concurrency, flaky bugs); deliverable is a repro and the root cause. Takes minutes even when small. |

## Run

Save each brief and output in `~/.local/state/delegation-log/$(basename "$PWD")/` (`mkdir -p` it) as `<YYYYMMDD-HHMMSS>-<model>.{brief,out}.md`. Use `run_in_background` for long runs.

- Codex: `codex exec -m <model> -c model_reasoning_effort="<effort>" -s <read-only|workspace-write> -o <out> - < <brief>`. Review through `codex exec` with the diff range in the brief; `codex review` rejects `-m`.
- agy: `agy --model <model> --dangerously-skip-permissions --print-timeout 20m -p "$(cat <brief>)" > <out> 2>&1`. For Boost, start the brief with `/boost ` and use `30m`.
- Agent tool: `subagent_type: general-purpose`, `model: opus`, `effort: medium`.

## Brief and integrate

Give each worker its objective, necessary context without your preferred answer, write scope, deliverable, and acceptance check. Require it to state at the top any tool failure, incomplete work, or change of method, and to say "unknown" rather than invent sources, numbers, or dates.

Run write-capable workers without asking the user. Read-only workers may run in parallel. While a writer runs, do not edit its workspace; give parallel writers separate git worktrees (Agent `isolation: "worktree"`, codex `-C <worktree>`).

Discard conclusions behind a failure notice. Check only the review points you adopt; verify implementations by diff and the acceptance check. When two workers disagree, report the disagreement instead of picking or blending. For insufficient results, clarify, raise effort, or take over.
