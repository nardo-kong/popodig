# 2.0 macOS 本地試玩

版本 0.2.0-playtest，Godot 4.7 stable universal（Apple Silicon／Intel）。
這是本地 preview，尚有 #17 原生音訊輸出停滯／關閉資源保留，未做公證或公開發行。

## 開始

打開 `exports/macos/DigDown.app`。選擇語言，開始新家園或繼續最新保存。
新家園會先把快速／自動保存複製到 saves/archive，再建立新進度；不是覆寫舊世界。
正常關閉會自動保存；保存失敗會留在遊戲並提示。強制結束程序仍可能丟失最近操作。

跟著土壁的小芽、纖維或閃光，左鍵拖曳指定挖掘，鼠鼠自行工作。
初期先看發現與住處；取得石材／礦石後，工坊和群體工具的資訊才展開。
工坊清單可定位，會說明原料不足、未通路、加工進度或產物放不下。

- 1–7／畫面按鈕：挖掘、睡眠、倉儲、覓食、封堵、加固、工坊。
- H／?：操作說明；C：收藏；Esc：設定。
- 空格：暫停；Tab／按鈕：1×／2×／3×；危險開始時提示並恢復 1×。
- Home：回家；N：最近發現；WASD／方向鍵／中鍵：移動；滾輪：縮放。
- Cmd/Ctrl+S：快速保存；F9：讀取快速保存。

保存位置由 Godot user data 下的 `saves/` 管理。啟動時繼續按修改時間選最新槽位。
測試入口使用獨立目錄，不使用玩家保存。發布版本沒有作弊或本地開發遙測。
首次只需記下讓你想再挖一次的發現、無聊的等待、看不懂／卡住之處，
詳見 `2_0_PLAYER_CHECK.md`。自動腳本通關不代表真人體驗合格。

## 重建

使用官方 Godot 4.7 stable 和同版本 export templates 內的 macos.zip：

```sh
python3 tools/build_playtest_macos.py --godot /path/to/Godot --template /path/to/macos.zip
```

預設嚴格拒絕任何 ERROR。只有交付已知限制的本地 preview 時，才明確加上
`--preview-with-known-audio-issue`；這只允許已隔離的 #17「resources still in use at exit」
訊息，其他腳本、解析、匯出及操作失敗仍會阻擋。報告必須標記音訊未通過。
沒有關閉聲音作為修復。`phase21_build.json` 保存模板雜湊、版本及 release 驗證結果。
官方完整模板包 SHA256：`9714459dc071907c0f3d5f17d608faf69e7cda21331fc5d39c4503ffa4e99eec`；
其中 macos.zip SHA256：`b9b036261c18dac2c6ade52ffb592e3842cb9b76d8c8d0f55bc7b99ac4dfeae0`。

原生介面檢查：`python3 tools/qa/check_phase21_native.py --godot /path/to/Godot`。
音訊診斷：`godot --path . --script tools/qa/probe_native_audio.gd`；
可加 `--audio-driver Dummy` 做對照，Dummy 結果不代表聽到聲音。
音訊問題需要目標機實際聆聽及播放／關閉驗證才可關閉。
