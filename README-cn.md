<a href="."><img height="160" src="./RARApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="RARExtractor"></a>

[![English](https://img.shields.io/badge/English-Click-yellow)](README.md)
[![繁體中文](https://img.shields.io/badge/繁體中文-點擊查看-orange)](README-tw.md)
[![简体中文](https://img.shields.io/badge/简体中文-点击查看-orange)](README-cn.md)
[![日本語](https://img.shields.io/badge/日本語-クリック-blue)](README-ja.md)
[![한국어](https://img.shields.io/badge/한국어-클릭-yellow)](README-ko.md)

# RARExtractor

轻巧的 macOS 原生 RAR 解压工具。选择文件、按需输入密码，即可在原压缩包旁找到解压后的文件夹。

> 从 [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases) 下载已完成 Developer ID 签名与 Apple 公证的应用。

## 功能

- 解压 `.rar` 文件，不创建或修改 RAR 压缩包。
- 仅在压缩包需要密码时显示密码输入框。
- 显示解压进度与正在处理的文件名。
- 保留现有文件夹：输出文件夹已存在时，自动添加编号。
- 通过 Finder 的 `Extract RAR` 快速操作直接解压。
- 应用界面支持英文和繁体中文；README 的其他语言翻译不代表应用已支持该语言。

## 系统要求

- macOS 14 或更高版本。
- 搭载 Apple silicon 的 Mac，目前不支持 Intel Mac。
- 下载应用和检查更新时需要网络连接。

## 安装

1. 前往 [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases)，选择最新版本。
2. 在 **Assets** 中下载该版本附带的应用安装包，不要下载 GitHub 自动生成的 **Source code** 源代码压缩包。具体打包格式和说明请查看发行说明。
3. 如有需要，先解压下载的文件，再将 `RARExtractor.app` 拖到“应用程序”文件夹并打开。

不需要安装 Xcode 或构建工具。签名和公证状态请以发行说明为准。如果 macOS 阻止打开，请先确认下载来源，再按照 [Apple 官方说明](https://support.apple.com/102445)处理；请勿关闭系统安全防护。

## 解压文件

1. 打开 RARExtractor，选择 `.rar` 文件。也可以在 Finder 中使用“打开方式 > RARExtractor”，或在应用中按 **⌘O**。
2. 应用会自动开始解压。如果出现密码输入框，请输入压缩包密码并按 Return。
3. 在压缩包所在位置找到输出文件夹。例如，`Photos.rar` 会解压到 `Photos`；如果文件夹已存在，则依次使用 `Photos 2`、`Photos 3` 等名称。

原压缩包保持不变。解压成功后，应用会自动退出。压缩包所在文件夹必须允许写入；目前无法另选输出位置。

## Finder 快速操作

1. 安装并至少打开应用一次。
2. 打开“系统设置 > 通用 > 登录项与扩展”，在 Finder 扩展设置中启用 `Extract RAR`。设置位置可能因 macOS 版本而异。
3. 在 Finder 中选中一个 `.rar` 文件，执行“快速操作 > Extract RAR”。

繁体中文界面中的操作名称为 `解壓縮 RAR`。仅在需要时询问密码，解压结果放在压缩包旁，且不覆盖现有输出文件夹。

## 更新

应用已集成 Sparkle 自动检查更新与 `Check for Updates…` 菜单项。未配置更新源和签名公钥的版本会禁用更新，1.0.0 已包含更新配置。

配置完成的版本默认会自动检查，并在安装更新前询问。如果暂未提供自动更新，请从 [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases) 下载新版，退出 RARExtractor 后替换“应用程序”文件夹中的应用。仅发布 GitHub Release 不会启用 Sparkle 更新。

## 常见问题

- **密码不正确：**请重新输入密码。RARExtractor 无法找回遗失的密码。
- **无法解压：**确认压缩包完整，且所在文件夹允许写入。完整的 RAR 兼容性测试仍在进行中。
- **找不到快速操作：**先打开应用一次，再到系统设置检查 Finder 扩展。
- **Check for Updates… 不可用：**当前版本可能未配置更新源，或正在检查更新。

## 项目状态与反馈

Universal 2 支持，以及完整的兼容性、安全性和大型压缩包测试尚未完成。

如遇到问题或有功能建议，请到 [GitHub Issues](https://github.com/yanun0323/RARExtractor/issues) 反馈，并附上 macOS 版本、应用版本和复现步骤。请勿上传私人压缩包或密码。

## 第三方软件

完整的[第三方许可声明](THIRD_PARTY_NOTICES.txt)包含 Sparkle、UnRAR、Intel BSD 和 BLAKE2 声明，随应用存放在 `RARExtractor.app/Contents/Resources/THIRD_PARTY_NOTICES.txt`。各许可证仅适用于对应组件；项目自有代码与文档采用 [MIT 许可证](LICENSE)。UnRAR 并非 MIT 许可，且禁止用于开发 RAR 兼容的压缩创建工具或重建 RAR 压缩算法。

解压使用 RARLAB 官方 UnRAR 源代码，详见 [UnRAR 许可证](Vendor/UnRAR/license.txt)。更新使用 [Sparkle](https://github.com/sparkle-project/Sparkle)。

UnRAR 源代码：https://www.rarlab.com/rar/unrarsrc-7.2.7.tar.gz

SHA-256：`01d903a7dcf413cb2925696d7796e48e38d471f79bfe7ef3ad2aebf6c12dbefd`
