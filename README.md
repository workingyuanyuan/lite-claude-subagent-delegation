# Claude Subagent Delegation

讓 Claude Code 主代理透過 `CLAUDE.md` 的一句提示讀取個人全域 skill，主動把任務委派給其他 harness 的代理：Codex CLI（GPT）、Antigravity CLI `agy`（Gemini），以及 Claude Code 內建 Agent tool（Fable、Opus）。只在能省下主代理 context 或提升品質、且驗證成本低於自己做時委派。

版本資料夾以支援的主代理模型命名。`claude-fable-5-2-opus-5-5` 是目前的版本：主代理可以是 Claude Fable 5.2 或 Claude Opus 5.5，每個 session 擇一，兩者共用同一份 skill。`claude-opus-5-5` 是只支援 Opus 5.5 主代理的前一版，原樣保留當紀錄。Codex 版見 [lite-codex-subagent-delegation](https://github.com/workingyuanyuan/lite-codex-subagent-delegation)。

## 檔案

```text
claude-fable-5-2-opus-5-5/      目前的版本
  CLAUDE.md
  MODEL-SELECTION.md
  skills/
    delegate/
      SKILL.md
claude-opus-5-5/                前一版（只支援 Opus 5.5 主代理）
```

- [CLAUDE.md](claude-fable-5-2-opus-5-5/CLAUDE.md)：加入個人全域指令的英文入口句。
- [SKILL.md](claude-fable-5-2-opus-5-5/skills/delegate/SKILL.md)：英文委派策略與呼叫方式。
- [MODEL-SELECTION.md](claude-fable-5-2-opus-5-5/MODEL-SELECTION.md)：選模型的依據、實測紀錄與分數快照。只在升級 skill 時讀，不安裝。

## 前置需求

- [Codex CLI](https://github.com/openai/codex)（已驗證 0.163）與 [Antigravity CLI](https://antigravity.google/docs/cli/reference/) `agy`（已驗證 1.4.7），皆已登入。
- 支援 Windows（PowerShell / Git Bash）與 WSL / Linux（bash）；skill 只描述指令參數，由主代理依當下 shell 寫出對應語法。

## 手動安裝

### 1. 複製 skill 資料夾

將 `claude-fable-5-2-opus-5-5/skills/delegate` 整個資料夾複製到個人技能目錄：

| 系統 | 個人技能目錄 |
| --- | --- |
| Windows | `%USERPROFILE%\.claude\skills` |
| macOS / Linux | `~/.claude/skills` |

完成後應為 `~/.claude/skills/delegate/SKILL.md`。在本機維護 repo 時，也可以改用 symlink 指向 repo 內的 `SKILL.md`。

### 2. 加入全域入口句

在 `~/.claude/CLAUDE.md`（Windows：`%USERPROFILE%\.claude\CLAUDE.md`）加入：

```text
Before delivering a design or merge-bound code, and whenever delegating would save your context or improve quality, read and follow the delegate skill and proactively delegate suitable tasks.
```

若已有其他委派 skill 的入口句，改成上句。

### 3. 確認載入

開啟新對話，確認可用 skill 清單中出現 `delegate`，再以明確呼叫檢查：

```text
/delegate 請說明你讀取的 SKILL.md 路徑，以及各模型適合的任務。
```

## 委派策略

| 模型 | effort | 適用工作 |
| --- | --- | --- |
| Opus（Agent tool） | `medium` | 要 merge 但大到會吃滿主代理 context 的程式碼；其餘由主代理自己寫 |
| Fable（Agent tool，僅 Opus 主代理） | `medium` | 搭建前與 Astra、Argon 並行的第三份設計意見；不接實作 |
| `gpt-6.1-sol` | `medium` | 主代理寫完後的 code review；不 merge 的後端工作 |
| `gpt-6.1-sol` | `high` | 大型或高風險 diff，或 medium 未通過驗收 |
| `gpt-6-astra` | `medium` | 搭建前的設計討論與第二意見；動手前的根因假設 |
| `gemini-4-argon-medium` | ID 內 | 搭建前與 Astra 並行的設計意見；對圖片、PDF、影音做判斷；Hydrogen 做不好的媒體任務 |
| `gemini-4-hydrogen-medium` | ID 內 | 多模態抽取（媒體任務的預設） |
| `gemini-4-hydrogen-high` | ID 內 | 機械性程式任務；medium 未通過驗收或明顯困難的抽取 |

新專案、新功能或改版開始搭建前，主代理會平行、唯讀地詢問所有 advisor，把採納點與分歧呈報使用者，分歧由使用者決定後才動工。

寫檔委派直接執行；只讀委派可平行，寫檔委派期間主代理不改同一工作目錄，平行寫檔用 git worktree。每次委派的 brief 與輸出存於 `~/.local/state/delegation-log/<專案>/`。委派結果一律視為未驗證，主代理負責最終驗收與整合。

## 授權

[MIT](LICENSE)
