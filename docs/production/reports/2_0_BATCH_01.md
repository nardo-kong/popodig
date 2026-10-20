# 2.0 第一批 — 發現、前沿與資源

日期：2026-10-21。議題：#3、#4、#5；前置 #2 已完成。

## 實作

- 種子化、分層的小發現／資源點；開局左右分別有食物與築巢纖維承諾。
- 權威特徵資料記錄定義、規模、已領取、待交付位置；滿倉先保留權利，
  解除阻塞後重試，JSON 存讀後不重複發放。
- 前沿可見提示使用真實迷霧距離，不讓未發現洞窟成為隱藏光源。
- FOOD／GENERAL_MATERIAL 穩定 ID 保留，增加 STONE／ORE／METAL；
  材料有遊戲內來源，既有自主搬運支援新物品。無效物品存檔在替換庫存前拒絕。
- Save schema v3，保留 v1→v2→v3 鏈。恢復實際世界與特徵，
  不因 worldgen v7 而用新世界覆蓋舊存檔。
- 世界生成進入 v7 開發版，完整密度／性能驗收仍由 #11 完成。

## 本批驗證

Godot `4.7.stable.official.5b4e0cb0f`，macOS Apple M1 Max。

1. 首次增量：discovery_flow／save_service／colony_jobs，120 passed，0 failed。
2. 三項整合後一次完整單元／整合 runner：1312 passed，0 failed。
3. 場景驗證發現 app/worldgen 版本宣告未同步，修正 config/app.json。
4. 修正後只跑 frontier_cues／foundation：73 passed，0 failed。
5. 庫存載入原子性增量修正後，只跑 discovery_flow／save_service：76 passed，0 failed。
6. `tests/phase20_core_smoke.gd --profile=release`：PASS。由真實鼠鼠挖掘，
   新材料自主搬入倉儲；16 材料中消耗 1 佈置、15 入庫；場景 v3 JSON
   存讀成功，重複領獎遭拒。未注入測試資源。
7. Release 畫面：`art/qa/screenshots/phase20_frontier_1280.png`（1280×720）
   與 `phase20_frontier_1920.png`（1920×1080），已目視檢查。
   左右提示可見、未知遠處保持黑暗；新資源計數顯示。

本批未重跑完整 288-seed／全部舊截圖。後續 #11 才整合世界生成驗收。

## 限制與後續

- Gate A／B 的陌生玩家「想繼續／能讀懂」觀察尚未執行，移交 #15。
  工程 smoke 與畫面不等於人工通過。
- 圖鑑、完整生產、能力與物流反饋由後續 Issues 實作；收藏目前有穩定定義 ID，
  完整命名／圖鑑呈現由 #10 負責。
- Runner／場景退出仍有 ObjectDB/resource 清理警告；無斷言失敗，需在最終 RC
  檢查清理，不能把該次結果稱作完全乾淨的 release validation。
