# 2.0 第五批：首局與試玩交付

日期：2026-10-22。基線：`4e108a3`，分支 `codex/dig-down-2`，PR #16。
用戶要求持續做到令人滿意、願意玩；本批領取 P1 #18–#21。

## 完成範圍

- #18：初期先看探索承諾；取得原料／建立工坊後展開能力與成本。
  顯示可達材料的實際差額、缺料、通路、加工進度、產物阻塞；七種工具保留自由使用。
  新增可點工具列與雙語說明；收斂無工作時的空計數與重複教學。
- #19：1×/2×/3×與暫停，固定 0.05 秒模擬步長；危險開始提示並回復 1×。
  回家、最近發現、工坊定位；相機位置與縮放保存。說明／設定／圖鑑期間阻擋相機操作；
  Cmd/Ctrl+S 不會同時向下移動。速度設定仍為 O-005 provisional。
- #21：真正主場景提供新家園、繼續最新槽位、說明、語言及離開。
  新局先封存快速／自動保存，未開始不覆寫；正常關閉保存，失敗留在遊戲。
  修正不同 seed 讀檔時先依保存 header 生成基礎 metadata，再恢復完整世界。
- #20：官方 4.7 universal template、本地 release .app、原創向量圖示、可重現打包工具。
  真實 release 即使傳入 development 仍無作弊／遙測，包內排除 tests/tools/docs/art/qa。
  試玩入口、工具、說明及存讀在實際匯出程式內檢查成功。
- 音效：修正 ambience/music 的 import loop_mode：2 才是 Forward；1 是 Disabled。
  四項回歸斷言直接檢查載入資源的循環範圍。

主要改動：GameApp、DevelopmentView、新入口／說明／時間控制視圖、WorldCamera、
ProductionSystem.status、能力成本查詢、SaveService、音效匯入、balance/app config、
export_presets、打包／原生驗證工具及相關單元／流程測試。沒有修改世界布點算法。

## 驗證

環境：Godot `4.7.stable.official.5b4e0cb0f`，macOS Apple M1 Max。

- import/parse 通過。批末 RC **1418/1418**，包括 save soak。
- 四條核心／加工升級／收藏／完整戰役流程通過。完整戰役採正常命令，無物資注入或跳章：
  980.4 模擬秒、5 鼠、暖巢附近食物 10、家園回憶 6/6、保存狀態可恢復。
- 七個分散種子重播通過。延用第三批 v7 288/288 矩陣，沒有不必要重跑。
- 水 benchmark 240 步：平均 0.607ms，p95 2.069ms，max 2.210ms。
- 最後相機／定位／循環改動後，相關增量 **173/173**（entry_saves、time_control、
  audio_bank、production_flow、save_roundtrip），沒有再跑第二次大集合。
- 真正開窗的 release-profile：中英文各 1280×720／1920×1080 四組介面流程成功；
  漸進資訊、說明邊界、恢復原暫停、固定 tick、危險降速、實際升級按鈕、工坊定位、相機存讀均檢查。
- 入口流程另驗：保留舊檔、新局正常挖掘首個發現、快速保存、實際場景重載、相同 seed 與發現保留、正常關閉保存。
- UI 狀態用少量物品 fixture 驗證 affordance，明確不當作正常玩法通關證據。
- 目視核對上述四種首局／說明組合與中文入口，共九張新圖；未見越界或重疊。
  `art/qa/screenshots/phase21_*`；首局沒有開發資訊／作弊列。

機器證據：`art/qa/reports/phase21_validation.json`、`phase21_native.json`、
`phase21_campaign_telemetry.json`、`phase21_build.json`、`phase21_audio.json`。
歷史 Phase 20 截圖／報告保持原樣。原生 UI 的功能成功與音訊關閉錯誤分開記錄。

## #17 音訊：仍未通過

新探針 `tools/qa/probe_native_audio.gd` 不建立 GameApp。
本機十次播放：CoreAudio ambience position 停在 0.0058 秒，距離最後 mix 持續增加到
2.404 秒，objects 1530→1539；退出保留三個 WAV resources。
相同非 headless 探針改 Dummy，position 前進到 1.771 秒，objects 固定 1529，退出無錯誤。
Dummy 不是可聽見的輸出證據。原生 release 也重現，因此不只是 editor 關閉階段。

已試 PCM／原始 QOA、單播放器／多播放器、預設／強制 STREAM、LaunchServices、
重新選預設 output；沒有可靠修復，無效編碼改動已撤回。也曾有單次 CoreAudio 探針正常，
故尚不能斷言上游根因。系統有正常預設揚聲器；沒有把沙盒中的空裝置清單當成無裝置。
下一步需在獨立目標環境比較原生 callback／實際聆聽，判斷本機、驅動或引擎問題。

打包腳本預設仍嚴格失敗。這次明確使用 `--preview-with-known-audio-issue` 產生本地預覽，
只允許既知資源退出訊息，其餘 ERROR 一律阻擋。不是靜音修復，也不是正式 RC 通過。
#20 保留開放直到音訊驗收完成；簽名為本地 ad-hoc，沒有公證／公開上架。

## 仍待真實觀察

#3／#4／#15：前沿是否讓人好奇、回報是否想再找下一個、是否因運輸重布局、
完整流程的等待與滿足感。沒有真人觀察，不能宣稱令人滿意或願意繼續玩。
試玩卡 `docs/qa/2_0_PLAYER_CHECK.md`；啟動／重建說明 `docs/qa/2_0_MACOS_PREVIEW.md`。

沒有新增戰鬥、個體工具或複雜配方；未擅改物流成本或既有塌方規則。
未建立 milestone tag。提交 ID 由本批 Git commit／PR #16 記錄。
