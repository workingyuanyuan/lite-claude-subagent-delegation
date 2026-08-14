# claude-gemini-orchestrator

本專案解決了 AI 開發過程中讓 Claude Code 能夠依據模型能力與成本將任務委派給合適子代理的問題。透過本專案的設定，Claude Code 可經由官方 Antigravity CLI（`agy`）呼叫 Gemini 模型，並直接沿用既有的訂閱登入狀態，完全不需要也不應使用 API Key。Claude Code 負責拆解任務、整合、審查與最終驗收；子代理只執行範圍明確、可驗證的單次任務。

## 架構：三行 CLAUDE.md ＋ 一個 Skill

完整的路由與委派策略封裝在 `antigravity-delegation-gemini37` Skill 內，只有在真的要委派時才會載入，因此不會在專案初期的規劃與決策階段佔用主代理的上下文。

留在 `CLAUDE.md` 的僅有三行：主代理的職責邊界、觸發判斷、以及「符合條件就載入 Skill」的指示。觸發條件刻意寫得寬鬆並列舉具體工作類型（實作、重複性編輯、重構、遷移、前端／UI、文件與文案、資料轉換、測試、程式庫研究與唯讀分析、可並行的獨立工作、高上下文消耗、使用者明確要求 worker／子代理／Gemini），以確保封裝後不會錯失原本能夠委派的機會。

Skill 名稱刻意帶上模型世代（`gemini37`）。Antigravity 提供的模型會隨時間更新，帶版本的名稱可讓不同世代的策略並存，不會在升級時被靜默覆蓋。


## 版本

`versions/opus-5/` 是目前採用的版本，對應以 Claude Opus 5 作為主代理的調度設定。

```text
versions/opus-5/
├─ CLAUDE.md
├─ scripts/
│  └─ Invoke-AntigravityAgent.ps1
└─ skills/
   └─ antigravity-delegation-gemini37/
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

封裝腳本接受的 slug 只有三個，推理強度直接寫在 slug 裡，因此每次呼叫都必須明示：

- `gemini-3.7-flash-medium`：預設 worker
- `gemini-3.7-flash-high`：同一模型的高推理強度版本
- `gemini-3.1-pro-high`：資料處理為瓶頸的任務（3.1 Pro 沒有 Medium 級別）

不需要也不可以傳 `--effort`，那會與 slug 重複。封裝腳本會先透過 `agy models` 確認該 slug 仍被提供且唯一命中，再實際呼叫。

`agy models` 仍會列出已被取代的 Gemini 世代、其他推理強度，以及 Claude 的 worker slug；封裝腳本的白名單只放行上述三個，其餘在呼叫 CLI 之前就會被擋下。

## 模型委派範圍

| 模型 | 定位 | 委派範圍 |
| --- | --- | --- |
| Gemini 3.7 Flash | 預設 worker | 所有有界且可客觀驗證的委派工作：實作、重複性編輯、重構、遷移、前端／UI、文件與文案、資料轉換、測試撰寫，以及 worktree 內的多步驟編輯、build-test-fix 迭代、需先探索才能定案的任務 |
| Gemini 3.1 Pro | worker | 瓶頸落在資料處理者：schema 與資料集理解、資料建模、大量結構化資料轉換 |
| Claude Opus 5 | 主代理本身 | 不可委派，僅作為能力表的參照基準 |

worker 之間依「先看能力門檻，再比 Cost Efficiency」排序。

這一代退役了兩個 worker，理由並不相同。

**兩個 Flash 收斂成一個。** 上一代之所以並存，是因為 3.6 Flash 的 Reasoning 較高、3.5 Flash 的 Agentic 較高，必須依任務形態二選一。Gemini 3.7 Flash 同時在 Cost Efficiency、Intelligence、Reasoning、Coding、Agentic、Math、Instruction 七項取得 worker 中的最高分，這個區分就沒有存在理由了。它的 Agentic 為 58（上一代兩個 Flash 分別為 49 與 43），已接近主代理的 62，worktree 內的多步驟與探索型任務直接走預設路由即可。

**Claude Opus 4.6 完全移除。** 它只在 Reasoning 領先 1 分、Data 領先 2 分，落在估計分數的雜訊範圍內，其餘各項皆落後，而 Cost Efficiency 約只有 Gemini 3.7 Flash 的三分之二。沒有任何任務描述能誠實地把它選出來，留在表上只會讓人憑「推理較深」的印象誤路由。它的 slug 仍存在於 `agy models`，真正讓退役生效的是封裝腳本的白名單。

這個決定有代價，值得先寫明而不是日後才發現：Opus 4.6 是唯一非 Gemini 家族的 worker，移除後委派系統不再有跨家族的第二意見。升級路徑變成「提高推理強度 → 退回主代理」，Gemini 家族共通的錯誤模式只能靠主代理的審查攔下。這是拿冗餘換成本，因為能力表已不支持繼續為那份冗餘付費。

3.1 Pro 則只剩 Data 一項具實質領先（78 對 68），路由理由收斂到資料處理為瓶頸的任務。

主代理（Opus 5）的 Cost Efficiency 是全表最低，也就是說**主代理的容量才是整個系統最稀缺的資源**。因此原則是把有界工作盡量交出去，而不是自己吸收——自己做等於用最貴的容量處理本可外包的事。完整規則以 Skill 為準。

## 推理強度：預設 Medium

能力表中 Gemini 3.7 Flash 的分數量測自 **High**。Medium 與 High 相比：

| 項目 | Medium 相對於 High |
| --- | --- |
| Coding | 完全相同 |
| Agentic | 完全相同 |
| Reasoning、Math、Data、Language、Instruction | 較低 |
| Cost Efficiency | 較高——同樣的 Coding 與 Agentic，花更少推理 token |

Coding 與 Agentic 正是大多數有界委派工作真正倚賴的兩項：寫出變更、跨檔案編輯、跑 build、讀錯誤、修掉它。在這兩項上 High 買不到任何東西。因此 **Medium 是預設值，High 是有目標的升級而不是比較安全的選擇**。

只有當任務的成敗落在 Medium 讓出的五項上，才升級為 `gemini-3.7-flash-high`：

- **Reasoning／Math**：非顯而易見的演算法、並行或不變量論證、量化推導
- **Instruction**：密集規格，或多條約束必須同時成立的契約
- **Language**：文案、文件、命名等「用字本身就是交付物」的工作
- **Data**：僅在 3.1 Pro 不可用時；否則資料型任務應走 3.1 Pro

判斷依據是任務倚賴哪個維度，而不是任務看起來多大。上千行的機械式重構屬於 Coding 與 Agentic，留在 Medium；二十行但正確性需要論證的函式則不是。任務性質混合時先用 Medium：事後升級只多花一次重跑，預設 High 則是在每一個本來不需要的任務上都多花。



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

這些規則可以放行的原因為：清單裡沒有任何會改變版本庫狀態的指令，而真正的把關點是調度代理整合前對完整 diff 的審查。

> **注意 `-AutoApprove` 的實際範圍。** 封裝腳本強制 `-WorkingDirectory` 必須是 Git worktree 根目錄，這確實把 worker 的**檔案寫入**限制在一次性的隔離 worktree 內。但 `-AutoApprove` 展開成 `--dangerously-skip-permissions`，它自動核准的是 worker 的**所有**工具呼叫，包含 Antigravity CLI 上掛載的任何 MCP server；`--add-dir` 只約束檔案系統，管不到 MCP。若你設定過帶有憑證的 MCP server（例如持有 token 的 GitHub server），帶 `-AutoApprove` 的 worker 就能透過它對外動作。加旗標前請先確認 `~/.gemini/config/mcp_config.json` 裡的 server 清單，對該任務而言全部可信。

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
& "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" -WorkingDirectory "C:\src\project-worktree" -Model gemini-3.7-flash-medium -PromptFile "C:\src\contracts\task.md" -AutoApprove
```

說明：

- 只有在任務契約允許指定範圍內的本機寫入、且已掛載的 MCP server 對該任務皆可信時，才使用 `-AutoApprove`。它核准的是所有工具，不只是 worktree 內的檔案寫入。
- 子代理不應提交、合併、推送、發布或部署。Claude Code 必須審查輸出並完成最終驗收。
- **呼叫必須在背景執行**：因為封裝腳本的列印逾時是十分鐘，等於 Claude Code PowerShell 工具的前台逾時上限，前台呼叫可能在 worker 完成前被中止。

唯讀分析（不建立 worktree、不加 `-AutoApprove`）。此例的成敗落在推理深度上，因此升級為 High：

```powershell
& "$HOME\.claude\scripts\Invoke-AntigravityAgent.ps1" -WorkingDirectory "C:\src\project" -Model gemini-3.7-flash-high -PromptFile "C:\src\contracts\analysis.md"
```

## 限制

- 委派要求目標目錄位於 Git 版本庫內。
- 封裝腳本只開放 `gemini-3.7-flash-medium`、`gemini-3.7-flash-high` 與 `gemini-3.1-pro-high` 三個 slug。
- Opus 5 是主代理本身，並非可委派的模型，也沒有對應的 slug。
- 沒有非 Gemini 家族的 worker。需要獨立於 Gemini 的判斷時，該工作留在主代理。

## 測試

`tests/Test-OrchestratorConfig.ps1` 驗證某個版本目錄的內部一致性。worker slug 同時出現在多個位置（封裝腳本的 `ValidateSet`、Skill 的 frontmatter 與進入點清單、README 與路由文件），世代升級時只要漏改其中一處，設定仍可順利安裝，卻會在委派當下路由到封裝腳本拒絕的模型。

測試以封裝腳本的 `ValidateSet` 為權威來源，逐一比對其餘位置，並檢查兩個 PowerShell 檔案的語法、Skill 名稱的一致性，以及安裝器預設版本是否存在。已退役的模型與推理強度不是寫死的清單，而是以「slug 形態」推導：任何看起來像 worker slug、卻不在白名單內的字串都會讓測試失敗，因此下一次升級不必記得回來改測試。

```powershell
./tests/Test-OrchestratorConfig.ps1
```

結構性檢查不需要網路，也不需要 Antigravity CLI。若 `agy` 在 `PATH` 上，測試會額外以封裝腳本相同的比對規則驗證每個 slug 是否能在 `agy models` 中唯一命中；否則該項會被跳過。若要求此項必須執行，加上 `-RequireAgy`：

```powershell
./tests/Test-OrchestratorConfig.ps1 -Version opus-5 -RequireAgy
```

## 延伸閱讀

- [`versions/opus-5/skills/antigravity-delegation-gemini37/SKILL.md`](versions/opus-5/skills/antigravity-delegation-gemini37/SKILL.md)：完整編排策略與模型能力表（權威來源）。
- [`versions/opus-5/CLAUDE.md`](versions/opus-5/CLAUDE.md)：三行觸發規則。
- [`docs/routing-policy.md`](docs/routing-policy.md)：路由政策展開參考（英文），含世代升級步驟。
- [codex-gemini-orchestrator](https://github.com/workingyuanyuan/codex-gemini-orchestrator)：本專案的姊妹專案，同一套委派機制的 OpenAI Codex 版本。


## 授權

本專案採用 [MIT License](LICENSE)。
