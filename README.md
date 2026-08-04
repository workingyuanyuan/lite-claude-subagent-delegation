# claude-gemini-orchestrator

本專案解決了 AI 開發過程中讓 Claude Code 能夠依據模型能力與成本將任務委派給合適子代理的問題。透過本專案的設定，Claude Code 可經由官方 Antigravity CLI（`agy`）呼叫 Gemini 與 Claude Opus 4.6 模型，並直接沿用既有的訂閱登入狀態，完全不需要也不應使用 API Key。Claude Code 負責拆解任務、整合、審查與最終驗收；子代理只執行範圍明確、可驗證的單次任務。

## 架構：三行 CLAUDE.md ＋ 一個 Skill

完整的路由與委派策略封裝在 `antigravity-delegation-gemini36` Skill 內，只有在真的要委派時才會載入，因此不會在專案初期的規劃與決策階段佔用主代理的上下文。

留在 `CLAUDE.md` 的僅有三行：主代理的職責邊界、觸發判斷、以及「符合條件就載入 Skill」的指示。觸發條件刻意寫得寬鬆並列舉具體工作類型（實作、重複性編輯、重構、遷移、前端／UI、文件與文案、資料轉換、測試、程式庫研究與唯讀分析、可並行的獨立工作、高上下文消耗、使用者明確要求 worker／子代理／Gemini／Opus 4.6），以確保封裝後不會錯失原本能夠委派的機會。

Skill 名稱刻意帶上模型世代（`gemini36`）。Antigravity 提供的模型會隨時間更新，帶版本的名稱可讓不同世代的策略並存，不會在升級時被靜默覆蓋。


## 版本

`versions/opus-5/` 是目前採用的版本，對應以 Claude Opus 5 作為主代理的調度設定。

```text
versions/opus-5/
├─ CLAUDE.md
├─ scripts/
│  └─ Invoke-AntigravityAgent.ps1
└─ skills/
   └─ antigravity-delegation-gemini36/
      └─ SKILL.md
```

版號目錄名稱代表主代理所屬的 Claude 世代，並非專案發布版號。目錄名稱不可含空格（安裝器只接受英數、點與連字號）。


## 需求

- Windows 10 或 Windows 11
- PowerShell 7（`pwsh`）
- Git
- Claude Code
- 官方 Antigravity CLI（`agy`），且已登入可使用 Gemini 與 Claude 模型的訂閱帳號

不需要 API Key，也不要把憑證、Token 或 API Key 寫入設定、任務契約或版本庫。

## 安裝

主要安裝方式為從專案根目錄執行安裝器：

```powershell
./install.ps1 -Version opus-5
```

安裝器會把 `versions/opus-5/CLAUDE.md` 複製到 `$HOME\.claude\CLAUDE.md`（成為 Claude Code 的全域記憶，在每個專案都會載入），把封裝腳本複製到 `$HOME\.claude\scripts\`，並把 `versions/opus-5/skills/` 底下的 Skill 依原目錄結構複製到 `$HOME\.claude\skills\`。

安裝器預設**不會**覆寫既有檔案。若目的地已存在同名檔案，會列出衝突路徑並中斷；若需覆寫，必須加上 `-Force` 旗標：

```powershell
./install.ps1 -Version opus-5 -Force
```

封裝腳本使用的穩定 alias 為：

- `gemini-3.6-flash` → `gemini-3.6-flash-high`
- `gemini-3.1-pro` → `gemini-3.1-pro-high`
- `claude-opus-4-6` → `claude-opus-4-6-thinking`

Gemini 的 slug 以字尾帶出推理強度，Opus 4.6 則只發布 thinking 模式的 slug，**沒有** `-high` 變體，也不需要傳 `--effort`。封裝腳本會透過 `agy models` 驗證 alias 是否能唯一對應至目標 slug。

## 模型委派範圍

| 模型 | 定位 | 委派範圍 |
| --- | --- | --- |
| Gemini 3.6 Flash | 預設 worker | 有界且可客觀驗證的實作、重複性編輯、遷移、前端／UI、文件與文案、資料轉換 |
| Gemini 3.1 Pro | worker | 密集規格、指令／語言密集型工作、較困難的量化工作 |
| Claude Opus 4.6 | worker | 瓶頸在推理／理解深度而非工作量者：棘手的除錯、含隱性不變量的重構、大範圍跨檔案分析 |
| Claude Opus 5 | 主代理本身 | 不可委派，僅作為能力表的參照基準 |

三個 worker 之間依「先看能力門檻，再比 Cost Efficiency」排序。Gemini 額度充裕且 Cost Efficiency 最高，因此是預設值；Opus 4.6 在推理與理解深度上明顯較強，當任務的瓶頸落在這裡時就該用它，同時它也是 Gemini 因能力不足（而非契約或上下文問題）失敗時的第一個升級對象。

主代理（Opus 5）的 Cost Efficiency 是全表最低，也就是說**主代理的容量才是整個系統最稀缺的資源**。因此原則是把有界工作盡量交出去，而不是自己吸收——自己做等於用最貴的容量處理本可外包的事。完整規則以 Skill 為準。



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
- 子代理不應提交、合併、推送、發布或部署。Claude Code 必須審查輸出並完成最終驗收。
- **呼叫必須在背景執行**：因為封裝腳本的列印逾時是十分鐘，等於 Claude Code PowerShell 工具的前台逾時上限，前台呼叫可能在 worker 完成前被中止。

委派給 Opus 4.6 的唯讀分析（不建立 worktree、不加 `-AutoApprove`）：

```powershell
& "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" -WorkingDirectory "C:\src\project" -Model claude-opus-4-6 -PromptFile "C:\src\contracts\analysis.md"
```

## 限制

- 委派要求目標目錄位於 Git 版本庫內。
- 封裝腳本只開放 `gemini-3.6-flash`、`gemini-3.1-pro` 與 `claude-opus-4-6` 三個 alias。
- Opus 5 是主代理本身，並非可委派的模型，也沒有對應的 alias。

## 延伸閱讀

- [`versions/opus-5/skills/antigravity-delegation-gemini36/SKILL.md`](versions/opus-5/skills/antigravity-delegation-gemini36/SKILL.md)：完整編排策略與模型能力表（權威來源）。
- [`versions/opus-5/CLAUDE.md`](versions/opus-5/CLAUDE.md)：三行觸發規則。
- [`docs/routing-policy.md`](docs/routing-policy.md)：路由政策展開參考（英文）。
- [codex-gemini-orchestrator](https://github.com/workingyuanyuan/codex-gemini-orchestrator)：本專案的姊妹專案，同一套委派機制的 OpenAI Codex 版本。


## 授權

本專案採用 [MIT License](LICENSE)。
