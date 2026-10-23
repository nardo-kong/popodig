# 2.0 第六批：素材、滑鼠辨識與圖像教學

日期：2026-10-23；基線 `df0adbb`；P0 #22；分支 `codex/dig-down-2`、PR #16。
版本：0.2.1-playtest，save schema 3 / worldgen v7 均未更動。

## 實際反饋與原因

用戶原話：「根本不知道一個東西代表樹根，那個代表食物，鼠標放上去也沒有提示」。
此項 #4／#15 理解結果記為需修改，未捏造試玩 seed、時長或其他操作。

原本地上物資僅為圓點／矩形；inspector 沒有查詢 ItemSystem 的物資堆，
牆內線索與已取得物資缺乏圖像對照。先前工程 smoke 通過不能證明能看懂。

## 已完成

1. 內建 imagegen 製作六張透明 PNG：食物漿果／種子、築巢枝條束、石材、銅色礦石、
   加工金屬錠、分岔樹根。接入物資堆、鼠鼠負重、已發現根系標記、開局圖片及圖文對照。
   世界與教學使用同一份貼圖。原圖保留，Godot 匯入限制 128px＋mipmaps，
   Texture region 去透明留白；沒有用高解細節直接硬塞進小畫面。
2. 滑鼠旁提示名稱／實際數量／用途／具體操作；右上資訊同步。
   食物自取、建材佈置、原料加工、金屬升級分別說明，不再只顯示地形。
3. 牆上的小芽／纖維／石紋／礦光／星光明示為「線索」，不顯示埋藏數量或特定收藏身份；
   全黑區域先攔截，不洩漏隱藏地形、特徵或物資。
4. 樹根分成可覓食、已採完、沒有可採食物三種真實狀態。
   可覓食者明示「4，在根旁已挖開的乾燥空地劃覓食區」；其他根系不虛假承諾。
   首次發現通知亦依真實狀態說明。
5. 開局左側用食物／建材實圖說明；目標加入選工具與左鍵拖曳。
   I／面板按鈕可開圖文對照，H 說明也可連入；指南暫停並恢復先前狀態，沒有教學鎖。
6. 提示不吃滑鼠事件，避免遮住底部工具；離開視窗／失焦隱藏。
   滑鼠座標統一來自 viewport 事件，與挖掘事件使用相同轉換。

主要程式：`resource_visuals.gd`、`world_hover_info.gd`、`world_hover_view.gd`、
`resource_guide_view.gd`、`discovery_glyphs.gd`、`root_landmark_view.gd`、
GameApp、物資／鼠鼠視圖、DevelopmentView、雙語文字與相關 QA。

## 素材交付與提示詞

最終素材目錄：`assets/art/production/resources/`。

- `food_berries_01.png`
- `building_bundle_01.png`
- `stone_pile_01.png`
- `copper_ore_01.png`
- `metal_ingots_01.png`
- `root_cluster_01.png`

完整六組提示詞、來源檔名、工具與透明背景設定：
`art/production/resource_imagegen_01.json`。使用內建 imagegen，沒有 CLI/API fallback。
素材生成原圖 1280×1280；遊戲匯入最大 128×128，六張 RGBA 含 mipmaps 約 0.5MiB。
主體暖色、輪廓與少量大色階配合既有鼠鼠／土地；實際小尺寸和教學 54px 均目視核對。
`CREDITS.md` 已修正，沒有再把這批素材誤記為程式生成。

## 驗證證據

環境 Godot `4.7.stable.official.5b4e0cb0f` / macOS M1 Max。

- import/parse：通過。
- 相關／核心增量 **227/227**：resource_readability、frontier_cues、context_tutorial、
  localization、save_roundtrip、discovery_flow、root_feature_flow。
  包含六圖可載入／實際透明度／匯入上限、雙語用途、真實物資數量、未挖線索不洩數量、
  全黑物資／未揭露根系不洩漏、耗盡／無食物根系不誤導，以及 inspect 不改物資狀態。
- 中英文 × 1280×720／1920×1080 四組真正開窗流程成功。
  以 viewport 滑鼠／按鍵事件驅動，未設定 QA inspector 座標捷徑。
  食物／建材停留、線索區分、根系說明、I／Esc 指南、暫停恢復與正常左鍵挖掘穿透均通過。
- 樹根畫面使用獨立 UI fixture（在已可見洞壁加一個已揭露根系），驗證標記與提示，
  不作為正常挖掘找到根系、真實玩家理解或通關證據；既有根系作業由核心增量驗證。
- 產出 20 張畫面：`art/qa/screenshots/phase22_*`（食物、建材、線索、樹根、圖文指南各四組）。
  目視核對中文1280五類、英文1280建材、中文1920樹根、英文1920指南等代表畫面；
  世界中的食物／建材不再是無法區分的小幾何塊。
- 本批是單一呈現／教學修正，按用戶節奏只做上述增量與短流程；沒有重跑全套或288種子。
  沒有修改世界布點、經濟成本或存檔格式。沒有新增完整性能 benchmark。

機器報告：`phase22_incremental.json`、`phase22_native.json`、`phase22_build.json`
均在 `art/qa/reports/`。歷史 Phase 20／21 報告與截圖保持原樣。

## 實際試玩包與剩餘事項

`exports/macos/DigDown-0.2.1.app`，官方 4.7 universal release 模板、本地 ad-hoc 簽名。
嚴格 build（未使用音訊例外參數）通過，實際 release 的新局／工具／說明／存讀成功；
即使傳 development 參數仍無作弊／遙測，QA 資料不入包。
本輪原生 UI 四組與匯出程式退出都無錯誤，但未修改 #17 根因，未代替聆聽或宣布修復。

新版獨立輸出，沒有覆寫或終止用戶正在執行的舊遊戲；正常關閉舊版後啟動 0.2.1，
繼續原進度即可看到新提示與素材，不必重新開始家園。
啟動／重建說明：`docs/qa/2_0_MACOS_PREVIEW.md`。

#22 指定工程驗收完成；同一玩家能否自主辨別、繼續挖掘及根旁覓食仍待複驗。
#3／#4／#15 不由自動測試代簽。沒有建立 milestone tag；本批提交見 Git／PR #16。
