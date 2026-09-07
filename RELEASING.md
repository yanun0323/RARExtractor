# Release 發布

## 已設定

- 目前版本：`1.0.1`，build `2`，macOS 14+，Apple silicon。
- 以下發布步驟以首版 `1.0.0` 示範；後續發布須換成對應版本與 tag。
- Developer ID：`Developer ID Application: Yanun Yang (Y366CJ66L6)`。
- 公證 Keychain profile：`RARExtractor-notary`。
- Sparkle Keychain account：`app.rarextractor`。私鑰只保存在本機 Keychain。
- 公鑰與更新網址：`RARApp/Info.plist` 的 `SUPublicEDKey`、`SUFeedURL`。
- 更新網址：`https://github.com/yanun0323/RARExtractor/releases/latest/download/appcast.xml`。

## 建置

```sh
make release
```

流程包含安全邊界測試、Release 建置、移除自動注入的偵錯權限、由內而外簽署 Sparkle 元件、公證、staple、Gatekeeper 驗證、ZIP 封裝、Ed25519 簽章與 SHA-256。任一步失敗就停止；已存在同名 ZIP 時拒絕覆寫。這個指令不會發布至 GitHub。簽署前會比對 App 內的 `THIRD_PARTY_NOTICES.txt`，並執行 `scripts/check-notices.py` 檢查公告是否包含目前依賴的完整授權；更新依賴時也須同步公告。

可透過環境變數覆寫 `SIGNING_IDENTITY`、`DEVELOPMENT_TEAM`、`NOTARY_PROFILE`、`SPARKLE_ACCOUNT`。切換 Sparkle account 時，須確認其公鑰與 App 設定一致。

## 發布到 GitHub

1. 提交並推送對應版本的程式碼，再建立指向該 commit 的 `v1.0.0` tag。
2. 在 `yanun0323/RARExtractor` 建立該 tag 的 Release 草稿。
3. 上傳以下三個檔案：
   - `dist/1.0.0/RARExtractor-1.0.0-macOS-arm64.zip`
   - `dist/1.0.0/appcast.xml`
   - `dist/1.0.0/SHA256SUMS`
4. 確認附件齊全後公開 Release，並設為 Latest（非 prerelease）。
5. 確認上述更新網址可匿名下載 XML，且 XML 中的 ZIP 網址可下載，長度與 SHA-256 相符。

不要發布 `dist/failed-notarization-1.0.0/` 的失敗產物，也不需上傳公證紀錄。不要重新壓縮已簽章的 ZIP。發布前應同步五語 README 中的下載、簽署、公證與更新狀態。

使用 Releases/latest 作為 feed 表示每個後續正式 Release 都必須附上 `appcast.xml`。公開第一版以前，此 URL 回傳 404 是預期情況。發布後應驗證公開 feed 與 ZIP；從舊版實際安裝到新版的端到端更新測試需另行執行。

## 後續版本與金鑰

同步遞增三個 `Info.plist` 的 `CFBundleShortVersionString`，且 `CFBundleVersion` 必須大於目前已發布的 build（目前為 `2`）。保留相同 Sparkle 金鑰，並以新的 `v版本` Release 發布。此流程只產生完整 ZIP 更新，不產生 delta。

使用 Sparkle 官方 `generate_keys --account app.rarextractor -x` 可將私鑰備份至專案外的安全位置；請自行在本機操作，使用加密儲存，勿將私鑰提交 Git 或貼到對話中。失去私鑰會影響既有安裝的更新驗證。
