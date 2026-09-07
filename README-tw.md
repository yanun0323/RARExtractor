<a href="."><img height="160" src="./RARApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="RARExtractor"></a>

[![English](https://img.shields.io/badge/English-Click-yellow)](README.md)
[![繁體中文](https://img.shields.io/badge/繁體中文-點擊查看-orange)](README-tw.md)
[![简体中文](https://img.shields.io/badge/简体中文-点击查看-orange)](README-cn.md)
[![日本語](https://img.shields.io/badge/日本語-クリック-blue)](README-ja.md)
[![한국어](https://img.shields.io/badge/한국어-클릭-yellow)](README-ko.md)

# RARExtractor

輕巧的 macOS 原生 RAR 解壓縮工具。選擇檔案、視需要輸入密碼，就能在原始壓縮檔旁找到解壓縮後的資料夾。

> 從 [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases) 下載已完成 Developer ID 簽署與 Apple 公證的 App。

## 功能

- 解壓縮 `.rar` 檔案，不建立或修改 RAR 壓縮檔。
- 只在壓縮檔需要密碼時顯示密碼欄位。
- 顯示解壓縮進度與目前處理的檔案名稱。
- 保留既有資料夾：輸出資料夾已存在時，自動加上編號。
- 透過 Finder 的「解壓縮 RAR」快速動作直接解壓縮。
- App 介面支援英文與繁體中文；README 的其他語言翻譯不代表 App 已支援該語言。

## 系統需求

- macOS 14 或更新版本。
- Apple silicon Mac，目前不支援 Intel Mac。
- 下載 App 與檢查更新時需要網路連線。

## 安裝

1. 前往 [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases)，選擇最新版本。
2. 在 **Assets** 下載該版本附上的 App 安裝包，不要下載 GitHub 自動產生的 **Source code** 原始碼壓縮檔。實際封裝格式與說明請參閱版本公告。
3. 如有需要，先解壓縮下載的檔案，再將 `RARExtractor.app` 拖到「應用程式」資料夾並開啟。

不需要安裝 Xcode 或建置工具。簽署與公證狀態請以版本公告為準。若 macOS 阻擋開啟，請先確認下載來源，再依照 [Apple 官方說明](https://support.apple.com/102445)處理；請勿關閉系統安全防護。

## 解壓縮檔案

1. 開啟 RARExtractor，選擇 `.rar` 檔案。也可以在 Finder 使用「打開檔案的應用程式 > RARExtractor」，或在 App 中按 **⌘O**。
2. App 會自動開始解壓縮。若出現密碼欄位，請輸入壓縮檔密碼並按 Return。
3. 在壓縮檔所在位置找到輸出資料夾。例如，`Photos.rar` 會解壓縮到 `Photos`；若資料夾已存在，則依序使用 `Photos 2`、`Photos 3` 等名稱。

原始壓縮檔保持不變。解壓縮成功後，App 會自動結束。壓縮檔所在資料夾必須允許寫入；目前無法另選輸出位置。

## Finder 快速動作

1. 安裝並至少開啟 App 一次。
2. 開啟「系統設定 > 一般 > 登入項目與延伸功能」，在 Finder 延伸功能設定中啟用「解壓縮 RAR」。設定位置可能因 macOS 版本而異。
3. 在 Finder 選取一個 `.rar` 檔案，執行「快速動作 > 解壓縮 RAR」。

英文介面中的動作名稱為 `Extract RAR`。只有需要時才會詢問密碼，解壓縮結果放在壓縮檔旁，且不覆寫既有輸出資料夾。

## 更新

App 已整合 Sparkle 自動檢查更新與「檢查更新…」選單。未設定更新來源與簽章公鑰的版本會停用更新，1.0.0 已包含更新設定。

完成設定的版本預設會自動檢查，並在安裝更新前詢問。若自動更新尚未提供，請從 [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases) 下載新版，結束 RARExtractor 後替換「應用程式」資料夾中的 App。單純發布 GitHub Release 並不會啟用 Sparkle 更新。

## 疑難排解

- **密碼不正確：**請重新輸入密碼。RARExtractor 無法找回遺失的密碼。
- **無法解壓縮：**確認壓縮檔完整，且所在資料夾允許寫入。完整的 RAR 相容性測試仍在進行中。
- **找不到快速動作：**先開啟 App 一次，再到系統設定確認 Finder 延伸功能。
- **「檢查更新…」無法使用：**目前版本可能未設定更新來源，或正在檢查更新。

## 專案狀態與意見回饋

Universal 2 支援，以及完整的相容性、安全與大型壓縮檔測試尚未完成。

如遇到問題或有功能建議，請至 [GitHub Issues](https://github.com/yanun0323/RARExtractor/issues) 回報，並附上 macOS 版本、App 版本與重現步驟。請勿上傳私人壓縮檔或密碼。

## 第三方軟體

完整的[第三方授權公告](THIRD_PARTY_NOTICES.txt)包含 Sparkle、UnRAR、Intel BSD 與 BLAKE2 聲明，並隨 App 存放於 `RARExtractor.app/Contents/Resources/THIRD_PARTY_NOTICES.txt`。各授權僅適用於對應元件；專案自有程式碼與文件採用 [MIT 授權](LICENSE)。UnRAR 並非 MIT 授權，且禁止用來開發 RAR 相容的壓縮建立工具或重建 RAR 壓縮演算法。

解壓縮使用 RARLAB 官方 UnRAR 原始碼，詳見 [UnRAR 授權](Vendor/UnRAR/license.txt)。更新使用 [Sparkle](https://github.com/sparkle-project/Sparkle)。

UnRAR 原始碼：https://www.rarlab.com/rar/unrarsrc-7.2.7.tar.gz

SHA-256：`01d903a7dcf413cb2925696d7796e48e38d471f79bfe7ef3ad2aebf6c12dbefd`
