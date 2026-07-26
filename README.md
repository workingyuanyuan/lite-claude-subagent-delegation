# claude-gemini-orchestrator

`claude-gemini-orchestrator` enables **Claude Code** to act as a primary orchestrator that delegates bounded, objectively verifiable execution tasks to **Gemini** worker models using your authenticated subscription session via the official Antigravity CLI (`agy`) without requiring API keys. By offloading routine implementation, documentation, and localized code changes to cost-effective Gemini workers, Claude Code remains focused on high-level architecture, contract specification, code review, and final integration. This project originated from an OpenAI Codex orchestration workflow preserved in `AGENTS.md`.

## Prerequisites

- [ ] **Antigravity CLI (`agy`)**: Installed, authenticated with your subscription session, and available on `PATH`.
- [ ] **PowerShell 7+ (`pwsh`)**: Installed (note that the wrapper script is Windows/PowerShell-oriented).
- [ ] **Git**: Installed and accessible in your environment.
- [ ] **Claude Code**: Installed and configured.

## Installation

1. Copy `CLAUDE.md` to your global Claude Code configuration directory so it loads as global memory across projects:
   ```sh
   cp CLAUDE.md ~/.claude/CLAUDE.md
   ```

2. Copy `scripts/Invoke-AntigravityAgent.ps1` to the path referenced by `CLAUDE.md`:
   ```sh
   mkdir -p ~/.claude/scripts
   cp scripts/Invoke-AntigravityAgent.ps1 ~/.claude/scripts/Invoke-AntigravityAgent.ps1
   ```

3. Verify with `agy models` that the two routed slugs (`gemini-3.6-flash-high` and `gemini-3.1-pro-high`) are available:
   ```sh
   agy models
   ```

## How It Works

When delegating tasks, Claude Code decomposes the problem and writes a self-contained task contract to a temporary UTF-8 file outside the repository. It creates a detached Git worktree (`git worktree add --detach <worktree-path> HEAD`) to maintain an isolated workspace. Claude Code then executes the installed wrapper at `~/.claude/scripts/Invoke-AntigravityAgent.ps1` to launch a single stateless Antigravity CLI worker session. After the worker completes its task, Claude Code reviews the generated diff (`git -C <worktree-path> diff`), validates the changes, integrates accepted work into the main tree, and removes the worktree. Gemini workers perform isolated execution only and never commit, merge, push, or deploy code.

For complete routing policies and model capability metrics, see [`CLAUDE.md`](CLAUDE.md).

## Limitations

- **Git Repository Required**: Delegation requires the target directory to be inside a Git repository, and `WorkingDirectory` must be the root of the Git worktree.
- **Supported Models**: The wrapper script strictly accepts only two model aliases: `gemini-3.6-flash` (resolving to `gemini-3.6-flash-high`) and `gemini-3.1-pro` (resolving to `gemini-3.1-pro-high`).
