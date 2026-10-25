# delegate skill：選模型的依據

升級 `SKILL.md` 時才讀。skill 本體不引用這份檔案，也不放分數和額度。

## 適用範圍
- harness：Claude Code；主代理固定是 Claude Opus 5.5。
- 一個 harness 一個 repo（Codex 版：`lite-codex-subagent-delegation`）。repo 內以主代理模型 ID 命名版本資料夾，主代理換模型時另開資料夾。
- 這份檔案放在版本資料夾根目錄，不在 `skills/delegate/` 裡，安裝時不會被複製進 skill。

## 成本原則
- 訂閱 Claude、GPT、Gemini，不付 API 費用，所以成本看**額度**、不看價格。

## 名冊的決定
- **要 merge 的程式碼由 Opus 寫，寫完由 Sol 審查。** Claude Opus 5.5 在 Frontier Code 1.1（衡量寫出可 merge 程式碼的能力）得分最高；GPT 模型後端能力強、擅長 review。
- **不設 Opus advisor。** 主代理就是 Opus，同模型的第二意見只剩隔離 context 的價值。原本想讓 Opus 在 benchmark 中當對照，但 skill 不放分數，所以不需要。
- **不選 GPT-6 Luna。** Gemini 3.8 Flash 能力勝過它；Gemini 適合委派的任務較窄、額度不容易用完，性價比更好。
- **Gemini 的定位**：擅長多模態（PNG/PDF/WAV/MP4）。Flash 也接機械性程式任務，用來分流 GPT 額度。
- **Sonnet** 目前不在名冊；之後若加入，算執行任務的角色（Agent tool 或 agy 的 `claude-sonnet-5-5-*`）。
- **Claude 角色用 Agent tool**，不用 agy 的 `claude-opus-5-5-*`：共用 Claude Code 的工具、權限、MCP，結果直接回到主代理。

## effort 的選法
- 優先用供應商推薦的預設值，或 Quality vs Cost 圖上性價比突出的選項。
- Argon 預設是 medium，medium 就夠。下表列 Argon high 只是因為 medium 的共同 benchmark 太少。
- Sol、Flash 先用 medium，沒通過驗收或任務明顯困難才升 high。

## 委派規則的決定
- 驗證成本接近自己做的成本 → 不委派（已和使用者確認）。
- 委派結果一律視為未驗證的意見。前例：Gemini 曾在要求有證據支撐的報告中捏造模型、分數和日期。
- 若發現每次都需要主代理完整驗證、實際品質沒提升，要重新和使用者討論委派規則。紀錄在 `~/.local/state/delegation-log/<專案>/`，可回頭檢視。
- 紀錄不放 `~/.claude/` 底下，避免寫入設定目錄時跳權限提示。

## 實測紀錄（2026-10-25，agy 1.4.7、codex-cli 0.163）
- **`/boost` 在 `agy -p` 下會展開**：orchestrator 選 Delegation routine，派 DeepCoder，底下再開子代理。9 行的 race condition 修好了，但花 7 分 35 秒、輸出約 2.7 萬 token，而且修法過度設計（多加 property、參數、RLock），不是可直接 merge 的 diff。→ skill 只用它做根因調查（DeepInvestigator 路線）。
- **`/browser` 在 `agy -p` 下也會展開**，但 WSL 沒有 Chrome，子代理連不上 DevTools。主代理沒有回報失敗，改讀 HTML 原始碼推出答案並當作成功回覆。→ 瀏覽器任務先移出 skill；brief 範本加入「失敗或換方法要在開頭明講」。要恢復，需在 WSL 安裝 Chrome，並在第一次連線時手動允許遠端偵錯。
- `agy --output-format json` 的 `status` 在子代理失敗時仍是 `SUCCESS`，不能依賴它判斷成敗。
- **音訊轉錄（新 session 主動委派）**：主代理交給 Flash 轉錄，再自行加派 Argon 重聽核對。日期、數字、人名全對；但 Flash 把「被擋」聽成「被打」，Argon 正確，主代理沒回報差異，還寫成兩邊都沒有的「被打爆」並稱「兩邊一致」。→ skill 加入「兩個代理結果不一致時回報差異，不挑選也不混寫」。
- `codex exec -s read-only -o <路徑>` 可以寫到工作目錄外（`-o` 由 CLI 寫，不受 sandbox 限制）。

## 分數快照（2026-10-25，10 個共同 benchmark）

| Benchmark | GPT-6.1 Sol · high | GPT-6 Astra · medium | Gemini 3.8 Flash · high | Gemini 4 Argon · high | Claude Opus 5.5 · medium | Gemini 3.8 Flash · medium | GPT-6.1 Sol · medium |
| --- | --- | --- | --- | --- | --- | --- | --- |
| AA-Briefcase | 49.1 | 47.5 | 42.1 | 64.6 | 57.0 | 41.1 | 44.0 |
| AA-Omniscience | 60.8 | 60.6 | 54.6 | 49.9 | 64.5 | 53.0 | 60.4 |
| ARC-AGI 2 | 91.7 | 92.1 | 89.2 | 91.3 | 87.5 | 82.9 | 86.7 |
| AutomationBench | 33.2 | 34.1 | 29.7 | 51.3 | 29.5 | 29.7 | 31.7 |
| CritPt | 30.0 | 29.1 | 18.3 | 27.1 | 27.7 | 12.3 | 27.7 |
| Frontier Code 1.1 | 48.0 | 48.8 | 38.0 | 45.9 | 54.6 | 41.2 | 50.2 |
| GDP.pdf | 32.0 | 30.4 | 21.0 | 21.8 | 25.6 | 22.8 | 30.0 |
| GDPval-AA | 50.6 | 49.3 | 46.8 | 56.2 | 54.3 | 46.1 | 47.5 |
| Humanity’s Last Exam | 51.4 | 52.7 | 47.8 | 57.1 | 54.7 | 42.1 | 49.9 |
| SciCode | 55.8 | 54.2 | 56.6 | 61.8 | 59.3 | 55.1 | 53.2 |

來源：Frontier-Model-Doh-Choo-choo 專案的網頁。skill 本身不依賴這個專案。
