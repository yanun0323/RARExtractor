<a href="."><img height="160" src="./RARApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="RARExtractor"></a>

[![English](https://img.shields.io/badge/English-Click-yellow)](README.md)
[![繁體中文](https://img.shields.io/badge/繁體中文-點擊查看-orange)](README-tw.md)
[![简体中文](https://img.shields.io/badge/简体中文-点击查看-orange)](README-cn.md)
[![日本語](https://img.shields.io/badge/日本語-クリック-blue)](README-ja.md)
[![한국어](https://img.shields.io/badge/한국어-클릭-yellow)](README-ko.md)

# RARExtractor

RAR ファイルを展開する、軽量な macOS ネイティブアプリです。ファイルを選び、必要に応じてパスワードを入力するだけで、元のアーカイブと同じ場所に展開先フォルダが作成されます。

> Developer ID による署名と Apple の公証を完了したアプリを [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases) からダウンロードできます。

## 機能

- `.rar` ファイルを展開します。RAR アーカイブの作成や変更は行いません。
- パスワードが必要な場合にのみ入力欄を表示します。
- 展開の進捗と処理中のファイル名を表示します。
- 既存のフォルダを保持します。出力先が存在する場合は名前に連番を付けます。
- Finder の `Extract RAR` クイックアクションから直接展開できます。
- アプリの表示言語は英語と繁体字中国語です。README の翻訳言語とアプリの対応言語は異なります。

## システム要件

- macOS 14 以降。
- Apple silicon 搭載 Mac。Intel Mac は現在未対応です。
- アプリのダウンロードと更新チェックにはインターネット接続が必要です。

## インストール

1. [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases) を開き、最新のリリースを選びます。
2. **Assets** から、リリースに添付されたアプリの配布パッケージをダウンロードします。GitHub が自動生成する **Source code** は選ばないでください。パッケージ形式や手順はリリースノートを確認してください。
3. 必要に応じてダウンロードしたファイルを解凍し、`RARExtractor.app` を「アプリケーション」フォルダへドラッグして開きます。

Xcode やビルドツールは不要です。署名と公証の状況はリリースノートを確認してください。macOS が起動をブロックする場合は、入手元を確認したうえで [Apple の案内](https://support.apple.com/102445)に従ってください。システムのセキュリティ保護は無効にしないでください。

## ファイルを展開する

1. RARExtractor を開き、`.rar` ファイルを選びます。Finder の「このアプリケーションで開く > RARExtractor」、またはアプリ内の **⌘O** も使えます。
2. 展開が自動的に始まります。パスワード入力欄が表示されたら、アーカイブのパスワードを入力して Return を押します。
3. アーカイブと同じ場所に出力フォルダが作成されます。例えば `Photos.rar` は `Photos` に展開されます。そのフォルダが存在する場合は `Photos 2`、`Photos 3` の順に名前を付けます。

元のアーカイブは変更されません。展開が成功するとアプリは自動的に終了します。アーカイブがあるフォルダへの書き込み権限が必要です。現在、別の出力先は選べません。

## Finder クイックアクション

1. アプリをインストールし、一度以上開きます。
2. 「システム設定 > 一般 > ログイン項目と機能拡張」を開き、Finder の機能拡張設定で `Extract RAR` を有効にします。設定の場所は macOS のバージョンによって異なる場合があります。
3. Finder で `.rar` ファイルを一つ選び、「クイックアクション > Extract RAR」を実行します。

繁体字中国語の表示では、このアクションの名前は `解壓縮 RAR` です。必要な場合にのみパスワードを求め、既存の出力フォルダを上書きせずにアーカイブと同じ場所へ展開します。

## アップデート

Sparkle による自動更新チェックと `Check for Updates…` メニューを組み込んでいます。更新フィードと署名用公開鍵が未設定のビルドでは無効です。1.0.0 には更新設定が含まれています。

設定済みのビルドでは、標準で自動チェックを行い、更新のインストール前に確認します。自動更新が利用できない場合は、[GitHub Releases](https://github.com/yanun0323/RARExtractor/releases) から新版をダウンロードし、RARExtractor を終了してから「アプリケーション」内のアプリを置き換えてください。GitHub Release の公開だけでは Sparkle の更新は有効になりません。

## トラブルシューティング

- **パスワードが違う：**再入力してください。RARExtractor では忘れたパスワードを復元できません。
- **展開できない：**アーカイブが完全で、その保存先フォルダに書き込めることを確認してください。RAR の包括的な互換性テストは進行中です。
- **クイックアクションが見つからない：**アプリを一度開いてから、システム設定で Finder の機能拡張を確認してください。
- **Check for Updates… が使えない：**更新元が未設定か、更新チェックがすでに実行中の可能性があります。

## 開発状況とフィードバック

Universal 2 対応、および互換性・安全性・大容量アーカイブの包括的なテストは未完了です。

不具合や機能の要望は [GitHub Issues](https://github.com/yanun0323/RARExtractor/issues) にお寄せください。macOS のバージョン、アプリのバージョン、再現手順を記載してください。個人情報を含むアーカイブやパスワードはアップロードしないでください。

## サードパーティ製ソフトウェア

Sparkle、UnRAR、Intel BSD、BLAKE2 を含む[サードパーティのライセンス通知全文](THIRD_PARTY_NOTICES.txt)を `RARExtractor.app/Contents/Resources/THIRD_PARTY_NOTICES.txt` に同梱しています。各ライセンスは該当するコンポーネントに適用されます。プロジェクト独自のコードのライセンスは未選定です。UnRAR は MIT ライセンスではなく、RAR 互換の圧縮作成ツールの開発や RAR 圧縮アルゴリズムの再現への利用を禁止しています。

展開には RARLAB 公式の UnRAR ソースを使用しています。[UnRAR ライセンス](Vendor/UnRAR/license.txt)をご覧ください。更新には [Sparkle](https://github.com/sparkle-project/Sparkle) を使用しています。

UnRAR ソース：https://www.rarlab.com/rar/unrarsrc-7.2.7.tar.gz

SHA-256：`01d903a7dcf413cb2925696d7796e48e38d471f79bfe7ef3ad2aebf6c12dbefd`
