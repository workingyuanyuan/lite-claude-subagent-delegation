---
name: delegate
description: Delegate work to Codex (GPT), agy (Gemini), or Claude subagents when it saves context or improves quality — review of code you wrote, design second opinions, image/PDF/audio/video work, mechanical edits, large merge-bound implementation.
---

# Delegate

Delegate when it saves your context or improves quality, and checking the result costs less than doing the work. Do not delegate evidence-backed research reports, or a chain of dependent steps that fits in your context. Treat every result as unverified.

Before building from a new design (a new project, feature, or redesign; not small changes), ask the advisors in parallel and read-only: Astra and Neon, plus Fable when you are Opus. Report adopted points and disagreements to the user, and build only after the user decides the disagreements.

## Select a configuration

This roster is for a Claude Fable 5.2 or Claude Opus 5.5 main agent; your system prompt states your model ID. Only the Fable advisor depends on which one you are. If you are another model, tell the user this skill has no roster for you before delegating.

| Model ID | Effort | Task fit |
| --- | --- | --- |
| Agent tool `opus` | `high` | Merge-bound code too large for your context; otherwise write it yourself. |
| Agent tool `fable`, only when you are Opus | `medium` | Advisor with Astra and Neon: design discussion and second opinions. Advisor only; do not send it implementation work. |
| `gpt-6.2-sol` | `medium` | Review of code you wrote, including large or risky diffs; non-merged backend work: repro scripts, load tests, one-off tools, backend investigation. |
| `gpt-6.2-astra` | `medium` | Advisor with Neon: design discussion and second opinions; root-cause hypotheses before you act. Advisor only; do not send it implementation work. |
| `gemini-4-neon-medium` | in ID | Advisor with Astra. Images, PDFs, audio, or video: extraction (transcription, timestamped descriptions of video or frames, data read into structured notes) and judgment (find defects, rate against a spec). Mechanical edits: renames, format conversion, boilerplate, tests that follow examples. |

## Run

Write commands in the syntax of the shell you are running (bash or PowerShell). Save each brief and output in `<home>/.local/state/delegation-log/<project-dir-name>/` (create it) as `<YYYYMMDD-HHMMSS>-<model>.{brief,out}.md`. Use `run_in_background` for long runs.

- Codex: `codex exec -m <model> -c model_reasoning_effort="<effort>" -s <read-only|workspace-write> -o <out> -`, brief on stdin. Review through `codex exec` with the diff range in the brief; `codex review` rejects `-m`.
- agy: `agy --model <model> --dangerously-skip-permissions --print-timeout 20m -p <brief text>`, stdout and stderr to `<out>`.
- Agent tool: `subagent_type: general-purpose`, `model` and `effort` from the table. Tell the Fable advisor in its brief not to edit files.

## Brief and integrate

Give each worker its objective, necessary context without your preferred answer, write scope, deliverable, and an acceptance check it can run itself (test, build, or script). Require it to state at the top any tool failure, incomplete work, or change of method, and to say "unknown" rather than invent sources, numbers, or dates.

Run write-capable workers without asking the user. Read-only workers may run in parallel. While a writer runs, do not edit its workspace; give parallel writers separate git worktrees (Agent `isolation: "worktree"`, codex `-C <worktree>`).

Discard conclusions behind a failure notice. Check only the review points you adopt; verify implementations by diff and the acceptance check. When two workers disagree, report the disagreement instead of picking or blending. For insufficient results, first make sure the worker could run the acceptance check, then clarify the brief. Use only the efforts in the table; when a clearer brief does not fix it, take over.
