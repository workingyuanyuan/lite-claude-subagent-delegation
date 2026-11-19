# delegate skill：選模型的依據

升級 `SKILL.md` 時才讀。skill 本體不引用這份檔案，也不放分數和額度。

## 適用範圍
- harness：Claude Code；主代理是 Claude Fable 5.2 或 Claude Opus 5.5，使用者每個 session 擇一。
- 一個 harness 一個 repo（Codex 版：`lite-codex-subagent-delegation`）。repo 內以支援的主代理模型命名版本資料夾；支援的主代理有異動時另開資料夾，舊資料夾原樣保留，當作 skill 模型異動的紀錄。前一版是 `claude-opus-5-5/`（只支援 Opus 5.5 主代理）。
- 這份檔案放在版本資料夾根目錄，不在 `skills/delegate/` 裡，安裝時不會被複製進 skill。

## 成本原則
- 訂閱 Claude、GPT、Gemini，不付 API 費用，所以成本看**額度**、不看價格。

## 兩個主代理共用一份 skill（2026-11-17）
- **狀況**：Claude Code 推出 Fable 5.2 後，使用者每個 session 在 Fable 5.2 與 Opus 5.5 之間擇一當主代理。兩種 session 共用同一個 `~/.claude/`（一份 `CLAUDE.md`、一個 skills 目錄），不能再用「換主代理就換安裝版本」的做法。
- **決定（使用者）**：只安裝一份 `delegate` skill，同時支援兩個主代理，版本資料夾以兩個模型命名（`claude-fable-5-2-opus-5-5`）。名冊中依主代理區分的只有一處：Opus 主代理多一位 Fable advisor。主代理從 system prompt 的模型 ID 判斷自己是哪一個。入口句不變。
- **理由**：兩個主代理的名冊只差一列，Run 與 Brief and integrate 完全相同。11/10、11/14、11/15 的規則修改都與主代理是誰無關，拆成兩份就要每次改兩處，容易漂移。單一 skill 也保留 `/delegate` 和現有安裝路徑。
- **沒選的方案**：
  - 兩個獨立 skill 並存安裝（`delegate-fable-5-2`、`delegate-opus-5-5`，入口句要求依模型 ID 選用）。優點是互不影響、skill 內沒有條件分支；缺點是共用規則要改兩份、每個 session 多一則 description、`/delegate` 改名。
  - 共用 `SKILL.md` 加每個主代理一份名冊檔：每次委派多讀一個檔。
  - 切換模型時手動換檔：每個 session 都可能換，不可行。
  - 把 skill 搬到 repo 根目錄、版本資料夾只放 `MODEL-SELECTION.md`：repo 就看不出 skill 支援的主代理怎麼異動（使用者否決）。
- **advisor 意見**：Astra 建議單一 skill，Argon 建議兩個獨立 skill，分歧由使用者決定。
- **何時重新考慮**：兩個主代理的差異擴大到名冊以外（委派原則、Run、Brief 的規則開始不同），或依主代理區分的列明顯變多時，改成兩個獨立 skill。
- **其他模型當主代理**：skill 要求先告知使用者沒有對應名冊（Astra 建議），避免名冊被套用到沒評估過的主代理。

## 名冊的決定
文中「11/17 快照」指前一份分數快照（含 Opus medium、Hydrogen、Argon、Fable high、GPT-6.1 Sol、GPT-6 Astra），已被文末的 2026-11-19 快照取代，舊表見 git 歷史。
- **要 merge 的程式碼由主代理寫，寫完由 Sol 審查。** 最初的依據是 2026-10-25 快照：Opus 5.5 在 Frontier Code 1.1（衡量寫出可 merge 程式碼的能力）得分最高（54.6）；GPT 模型後端能力強、擅長 review。快照沒有衡量 review 品質的項目，Fable 當主代理時 Sol 審查的價值尚未實測。
- **大型實作交給 Opus high subagent，兩個主代理都一樣**（2026-11-19，使用者決定）：11/17 使用者不採 Astra、Argon 的建議（Fable 主代理改用 Fable medium subagent），決定兩者都用 Opus medium。11/19 三位 advisor 都指出新分數讓 Opus medium 的依據更弱（Frontier Code 2.0：31.4），使用者改為 Opus high（36.3），仍低於 Astra（42.2）、Fable medium（38.8）、Sol（38.3）、Neon（38.2）。
- **Gemini 只留 Neon medium 一列**（2026-11-19，使用者決定）：取代 Hydrogen medium、Hydrogen high、Argon medium 三列，接手設計 advisor、媒體抽取與判斷、機械性編輯。
  - 刪 Hydrogen：與 Neon 共用額度（使用者提供）；Neon medium 在 8 項全部不低於 11/17 快照的 Hydrogen high（Frontier Code 2.0 同為 38.2，GDP.pdf 32.8 對 30.0），也不低於 Hydrogen medium。
  - 刪 Argon：已是上一代模型。Neon medium 在 6 項高於 Argon medium（HLE-Diamond 63.6 對 42.5、Frontier Code 2.0 38.2 對 24.4、AA-Omniscience 57.9 對 49.0、GDP.pdf 32.8 對 25.6、AutomationBench 53.3 對 50.1、Terminal-Bench-Science 54.8 對 48.6），Argon 只在 AA-Briefcase（62.6 對 53.2）和 Terminal-Bench 4.0（55.1 對 54.5）較高。Argon 有獨立額度，`agy` 仍可用，但不在名冊。
  - advisor 意見：三位都同意 Neon 接 Gemini 的 advisor 席位（Astra 要求先實測）。分歧：Argon 的去留（Astra 留作 Neon 額度用完時的備援；Argon、Neon 主張移出名冊）、Hydrogen 的去留（Astra 兩列都留到 Neon 通過實測；Argon 留 medium 做抽取；Neon 全刪）。由使用者決定。
- **Sol 只留 medium 一列，承接原 Sol high 的工作；Astra 只當 advisor，不接執行實作**（2026-11-19，使用者決定）：Astra 的額度消耗比 Sol 高很多（使用者提供），所以即使 Astra medium 在 6 項高於 Sol medium（Frontier Code 2.0 42.2 對 38.3、Terminal-Bench-Science 74.8 對 60.5），大型或高風險 diff 的審查仍交給 Sol medium。GPT-6.2 Sol medium 在 Frontier Code 2.0（38.3 對 35.1）、Terminal-Bench 4.0（56.1 對 51.5）、Terminal-Bench-Science（60.5 對 46.2）、AutomationBench（40.2 對 33.2）高於 11/17 快照的 GPT-6.1 Sol high，其餘 4 項略低（差 0.9 到 2.8）。Astra、Neon 曾建議把原 Sol high 的工作交給 Astra medium，Argon 建議保留 Sol high；使用者因額度不採。
- **Opus 主代理加 Fable 5.2 medium 當第三位 advisor**（2026-11-17，使用者決定）：搭建前與 Astra、Neon 一起平行、唯讀詢問，用 Agent tool（`model: fable`、`effort: medium`）。Fable medium 在 11/17 快照除 GDP.pdf 外都高於 Opus medium；對新快照的 Opus high 也在 6 項較高（GDP.pdf、Terminal-Bench 4.0 較低）。是比主代理強的模型給意見，不是同模型的第二意見。只當 advisor，不接實作。尚未實測。
- **Fable 主代理不設 Claude advisor**（主代理提案，11/17 Astra、Argon 意見一致）：另一個 Fable 是同模型的第二意見，只剩隔離 context 的價值（前一版「不設 Opus advisor」的理由相同）。Opus 多數項目低於 Fable medium，又同屬 Claude，不如 GPT、Gemini 能提供不同家族的觀點。
- **不選 GPT-6 Luna。** 輕量任務由 Gemini 承接（原本是 Hydrogen，現在是 Neon）；Gemini 適合委派的任務較窄、額度不容易用完，性價比更好。
- **Gemini 的定位**：擅長多模態（PNG/PDF/WAV/MP4）。Neon 也接機械性程式任務，用來分流 GPT 額度。
- **Sonnet** 目前不在名冊；之後若加入，算執行任務的角色（Agent tool 或 agy 的 `claude-sonnet-5-5-*`）。
- **Claude 角色用 Agent tool**，不用 agy 的 `claude-opus-5-5-*`：共用 Claude Code 的工具、權限、MCP，結果直接回到主代理。

## effort 的選法
- 優先用供應商推薦的預設值，或 Quality vs Cost 圖上性價比突出的選項。
- 名冊每個模型只列一個 effort（2026-11-19）：Sol、Astra、Neon、Fable 用 medium，Opus 用 high。新快照只有這 5 個組合的分數，沒有 Sol high、Neon high、Fable high。
- **skill 不再有升 effort 的選項**（2026-11-19，使用者決定）：完全不用 Sol high，其他模型也只用名冊上的 effort。結果未通過驗收時先釐清 brief，仍不行就由主代理接手。

## 委派規則的決定
- 驗證成本接近自己做的成本 → 不委派（已和使用者確認）。
- 委派結果一律視為未驗證的意見。前例：Gemini 曾在要求有證據支撐的報告中捏造模型、分數和日期。
- 若發現每次都需要主代理完整驗證、實際品質沒提升，要重新和使用者討論委派規則。紀錄在 `~/.local/state/delegation-log/<專案>/`，可回頭檢視。
- 紀錄不放 `~/.claude/` 底下，避免寫入設定目錄時跳權限提示。
- **結果不足時的處理順序**（2026-11-10，參考 claude.dev〈Which Claude model should you build with?〉）：先確認 worker 能自己跑驗收（測試、build、腳本），再釐清 brief 或升 effort；缺的是知識或能力時改派較強的模型，因為升 effort 補不了這些。brief 的 acceptance check 也因此要求是 worker 能自己執行的檢查。2026-11-19 起拿掉升 effort 和改派較強模型這兩步（見「effort 的選法」）：名冊每個模型只剩一個 effort，Astra 不接實作，剩下的處理是釐清 brief 或由主代理接手。
- **多模態預設 Hydrogen，Argon 只做判斷**（2026-11-14）：回顧紀錄，Gemini 共 45 次呼叫（Argon 24、Flash 21、Hydrogen 0）。多數 Argon 是視覺／音訊審查，符合原表；但 radar-repro 影片逆向分析（逐段輸出 storyboard JSON，屬擷取）連派 5 次 Argon。原因是 Argon 列「Review or opinions」範圍太寬，Hydrogen 列只寫「Multimodal extraction」沒有例子。→ Hydrogen 列寫明是媒體任務的預設，並列出轉錄、影片／影格時間軸描述、從圖片或 PDF 讀資料；Argon 列改成「對媒體做判斷」，並接手 Hydrogen 失敗的媒體任務。2026-11-19 起兩者都由 Neon 一列承接，抽取與判斷不再需要選模型，Neon 列仍保留這些例子。
- **搭建前固定問兩位 advisor**（2026-11-15）：新專案、新功能或改版（不含小改動）開始搭建前，一律平行、唯讀地問 Astra 和 Argon，把採納點和分歧呈報使用者，分歧由使用者決定後才動工。不再區分「設計找 Astra、高風險或 UX 才加 Argon」，主代理不必判斷該問誰，省 context，也提升設計品質（使用者決定）。來源：11/06 使用者在 phone-disassembly 要求「在開始搭建前先向其他代理詢問第二意見」，原本只存成該專案記憶；11/15 記憶整理時被當成與 skill 重複刪除，才發現 skill 沒有這條規則。兩人互補的實例見下方「設計審查加派 Argon」。2026-11-17 起 Opus 主代理另加 Fable，2026-11-19 起 Gemini 的席位由 Argon 換成 Neon，見「名冊的決定」。
- **連續依賴步驟不委派**（同一篇）：彼此依賴的步驟放得進主代理 context 時，拆分和合併的成本會比省下的多。超出 context 的大型工作仍然照名冊委派。

## 實測紀錄（2026-10-25，agy 1.4.7、codex-cli 0.163）
以下都是 Opus 5.5 當主代理時的實測，文中的 Flash 是當時名冊裡的 Gemini 3.8 Flash；Argon 已於 2026-11-19 移出名冊。
- **`/boost` 在 `agy -p` 下會展開**：orchestrator 選 Delegation routine，派 DeepCoder，底下再開子代理。9 行的 race condition 修好了，但花 7 分 35 秒、輸出約 2.7 萬 token，而且修法過度設計（多加 property、參數、RLock），不是可直接 merge 的 diff。→ 原本只保留給根因調查（DeepInvestigator 路線），後來刪除，見下方 t8。
- **`/browser` 在 `agy -p` 下也會展開**，但 WSL 沒有 Chrome，子代理連不上 DevTools。主代理沒有回報失敗，改讀 HTML 原始碼推出答案並當作成功回覆。→ 瀏覽器任務先移出 skill；brief 範本加入「失敗或換方法要在開頭明講」。要恢復，需在 WSL 安裝 Chrome，並在第一次連線時手動允許遠端偵錯。
- `agy --output-format json` 的 `status` 在子代理失敗時仍是 `SUCCESS`，不能依賴它判斷成敗。
- **音訊轉錄（新 session 主動委派）**：主代理交給 Flash 轉錄，再自行加派 Argon 重聽核對。日期、數字、人名全對；但 Flash 把「被擋」聽成「被打」，Argon 正確，主代理沒回報差異，還寫成兩邊都沒有的「被打爆」並稱「兩邊一致」。→ skill 加入「兩個代理結果不一致時回報差異，不挑選也不混寫」。
- **設計討論（新 session）**：入口句原本只寫「委派能省 context 或提升品質時」，Opus 判斷自己就能做，沒載入 skill。事後手動請 Astra 審查，找到會重新造成事件順序顛倒的嚴重缺陷（寫回結果時沒有檢查租約歸屬）。→ 入口句改成固定檢查點：交付設計或要 merge 的程式碼之前一定讀 skill。
- **設計審查加派 Argon（使用者指定）**：同一份已整合 Astra 意見的 DESIGN.md，Argon 的第一項發現就是 Astra 漏掉的「批次認領 20 件 × 60 秒租約」缺陷（brief 沒有點出批次），並指出 claim token 擋不住已送出的 HTTP 請求；另找到文件中錯誤的 PostgreSQL 細節（`DELETE ... LIMIT`、HOT update）。→ Argon 的 Task fit 加入：高風險設計與 Astra 並行給第二份意見。目前只有這一次樣本，需持續觀察。
- **Boost 根因調查（t8，新 session）**：帶假線索（refresher thread、TTL）的偶發 bug，根因是字串雜湊隨機化讓 `set` 走訪順序改變同分排序。Opus 沒有委派，38 秒內用固定 `PYTHONHASHSEED` 確認根因並正確修好。Opus 自己查得出來時不會選 Boost，而 Boost 又慢又會過度修改 → 從 skill 刪除 Boost。
- **小改動不強制審查**：t8 的一行修正沒有觸發「交付要 merge 的程式碼前讀 skill」的檢查點，但驗證完整，審查價值低。使用者決定維持現狀，不改成「任何 commit 前」。
- `codex exec -s read-only -o <路徑>` 可以寫到工作目錄外（`-o` 由 CLI 寫，不受 sandbox 限制）。

## 實測紀錄（2026-11-19，agy 1.5.12、codex-cli 0.170.0）
- **同一份名冊修改 brief 平行問 Astra、Argon、Neon**（Fable 5.2 主代理）：三份都正常完成。Neon 引用的分數逐項核對正確，建議的完整度與 Argon 相當；Neon 沒有先查 `agy` 的模型 ID（brief 也沒有給）。只有這一次樣本。

## 待觀察
- 新版 skill 尚未實測：Fable 與 Opus 主代理是否都載入 skill、Opus 是否會加問 Fable、Fable 是否不會加問；Sol 審查是否仍找得到 Fable 漏掉的問題。
- Fable 與 Opus 的相對額度消耗未知；Opus 由 medium 升 high 後的額度消耗也未知。
- Neon 的設計意見與媒體判斷品質未實測：benchmark 沒有衡量這兩項。便宜的試法是用委派紀錄裡的舊任務（租約 DESIGN.md、一個媒體判斷任務）讓 Neon 重跑，和 Argon 當時的結果比對。品質不如 Argon 時，重新討論是否把 Argon 加回來。
- Sol medium 審查大型或高風險 diff 的品質未實測；GPT-6.2 Sol high 沒有分數。

## 分數快照（2026-11-19，8 個共同 benchmark，5 個組合）

| Benchmark | GPT-6.2 Astra · medium | GPT-6.2 Sol · medium | Claude Fable 5.2 · medium | Claude Opus 5.5 · high | Gemini 4 Neon · medium |
| --- | --- | --- | --- | --- | --- |
| AA-Briefcase | 47.7 | 48.2 | 61.0 | 58.9 | 53.2 |
| AA-Omniscience | 64.2 | 59.2 | 77.0 | 64.8 | 57.9 |
| AutomationBench | 43.8 | 40.2 | 40.2 | 33.0 | 53.3 |
| Frontier Code 2.0 | 42.2 | 38.3 | 38.8 | 36.3 | 38.2 |
| GDP.pdf | 28.4 | 29.2 | 23.8 | 28.8 | 32.8 |
| HLE-Diamond | 56.0 | 50.7 | 66.3 | 55.6 | 63.6 |
| Terminal-Bench 4.0 | 58.6 | 56.1 | 55.1 | 56.6 | 54.5 |
| Terminal-Bench-Science 0.1 | 74.8 | 60.5 | 60.5 | 49.0 | 54.8 |

來源：Frontier-Model-Doh-Choo-choo 專案的網頁。skill 本身不依賴這個專案。
