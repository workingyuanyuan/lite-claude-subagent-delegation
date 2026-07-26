# claude-gemini-orchestrator

本專案解決了 AI 開發過程中讓 Claude Code 能夠依據模型能力與成本將任務委派給合適子代理的問題。透過本專案的設定，`CLAUDE.md` 可讓 Claude Code 經由官方 Antigravity CLI（`agy`）呼叫 Gemini 模型，並直接沿用既有的訂閱登入狀態，完全不需要也不應使用 Gemini API Key。Claude Code 負責拆解任務、整合、審查與最終驗收；Gemini 子代理只執行範圍明確、可驗證的單次任務。

## 版本

`versions/opus/` 是目前採用的版本，對應 Claude Opus 世代的調度設定。

```text
versions/opus/
├─ CLAUDE.md
└─ scripts/
   └─ Invoke-AntigravityAgent.ps1
```

版號目錄名稱代表支援的 Claude 世代，並非專案發布版號。專案保留了 `AGENTS.md` 作為對應 OpenAI Codex 版策略的上游鏡像。

## 需求

- Windows 10 或 Windows 11
- PowerShell 7（`pwsh`）
- Git
- Claude Code
- 官方 Antigravity CLI（`agy`），且已登入可使用 Gemini 模型的訂閱帳號

不需要 Gemini API Key，也不要把憑證、Token 或 API Key 寫入設定、任務契約或版本庫。

## 安裝

主要安裝方式為從專案根目錄執行安裝器：

```powershell
./install.ps1 -Version opus
```

安裝器會把 `versions/opus/CLAUDE.md` 複製到 `$HOME\.claude\CLAUDE.md`（成為 Claude Code 的全域記憶，在每個專案都會載入），並把封裝腳本複製到 `$HOME\.claude\scripts\`。

安裝器預設**不會**覆寫既有檔案。若目的地已存在同名檔案，會列出衝突路徑並中斷；若需覆寫，必須加上 `-Force` 旗標：

```powershell
./install.ps1 -Version opus -Force
```

`CLAUDE.md` 使用的穩定 alias 為：

- `gemini-3.6-flash` → `gemini-3.6-flash-high`
- `gemini-3.1-pro` → `gemini-3.1-pro-high`

封裝腳本會透過 `agy models` 驗證 alias 是否能唯一對應至目標 slug。

## 建議的權限設定

Claude Code 預設每次呼叫封裝腳本與 Git 指令時都會跳出權限確認提示，並行委派時會被打斷多次。建議在 `$HOME\.claude\settings.json` 加入以下允許規則；若該檔案已存在，必須**合併** `permissions.allow` 陣列而不是整份取代：

```json
{
  "permissions": {
    "allow": [
      "PowerShell(& \"$HOME\\.claude\\scripts\\Invoke-AntigravityAgent.ps1\"*)",
      "Bash(git worktree *)",
      "Bash(git diff*)",
      "Bash(git status*)",
      "Bash(git log*)",
      "Bash(git show*)",
      "Bash(git rev-parse*)",
      "Bash(agy models*)"
    ]
  }
}
```

這些規則可以安全放行的原因為：封裝腳本強制 `-WorkingDirectory` 必須是 Git worktree 根目錄，Gemini 的寫入範圍已被限制在一次性的隔離 worktree 內；真正的把關點是調度代理整合前對完整 diff 的審查。清單裡沒有任何會改變版本庫狀態的指令。

## 解除腳本的下載來源標記

從 GitHub 下載 ZIP 或複製帶有 Mark of the Web 的腳本時，檔案可能附帶 `Zone.Identifier`，導致 PowerShell 在 `RemoteSigned` 政策下拒絕執行。每次重新下載或複製後都應重新檢查。

請依序執行以下三個步驟（檢查路徑為 `$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1`）：

檢查標記：

```powershell
Get-Item -LiteralPath "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" -Stream Zone.Identifier -ErrorAction SilentlyContinue
```

解除標記：

```powershell
Unblock-File -LiteralPath "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1"
```

再次確認：

```powershell
Get-Item -LiteralPath "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" -Stream Zone.Identifier -ErrorAction SilentlyContinue
```

執行再次確認指令後沒有任何輸出，即代表下載來源標記已成功移除。

## 使用方式

調度代理會先準備隔離的 Git worktree 與完整 UTF-8 任務契約，再呼叫封裝腳本：

```powershell
& "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" -WorkingDirectory "C:\src\project-worktree" -Model gemini-3.6-flash -PromptFile "C:\src\contracts\task.md" -AutoApprove
```

說明：

- 只有在任務契約允許指定範圍內的本機寫入時才使用 `-AutoApprove`。
- Gemini 不應提交、合併、推送、發布或部署。Claude Code 必須審查輸出並完成最終驗收。
- **呼叫必須在背景執行**：因為封裝腳本的列印逾時是十分鐘，等於 Claude Code PowerShell 工具的前台逾時上限，前台呼叫可能在 worker 完成前被中止。

## 限制

- 委派要求目標目錄位於 Git 版本庫內。
- 封裝腳本只開放 `gemini-3.6-flash` 與 `gemini-3.1-pro` 兩個 alias。

## 延伸閱讀

- [`versions/opus/CLAUDE.md`](versions/opus/CLAUDE.md)：完整編排策略與模型能力表。
- [`docs/routing-policy.md`](docs/routing-policy.md)：路由政策展開參考（英文）。
