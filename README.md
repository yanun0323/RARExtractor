<a href="."><img height="160" src="./RARApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="RARExtractor"></a>

[![English](https://img.shields.io/badge/English-Click-yellow)](README.md)
[![繁體中文](https://img.shields.io/badge/繁體中文-點擊查看-orange)](README-tw.md)
[![简体中文](https://img.shields.io/badge/简体中文-点击查看-orange)](README-cn.md)
[![日本語](https://img.shields.io/badge/日本語-クリック-blue)](README-ja.md)
[![한국어](https://img.shields.io/badge/한국어-클릭-yellow)](README-ko.md)

# RARExtractor

A lightweight, native macOS app for extracting RAR archives. Choose a file, enter a password if needed, and find the extracted folder beside the original archive.

> Download the Developer ID–signed and Apple-notarized app from [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases).

## Features

- Extract `.rar` files without creating or modifying RAR archives.
- Enter a password only when the archive requires one.
- See extraction progress and the current filename.
- Keep existing folders: a numbered name is used if the output folder already exists.
- Extract directly from Finder with the `Extract RAR` Quick Action.
- English and Traditional Chinese app interface. These README translations do not add other interface languages.

## Requirements

- macOS 14 or later.
- A Mac with Apple silicon. Intel Macs are not currently supported.
- An internet connection to download the app and check for updates.

## Installation

1. Open [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases) and choose the latest release.
2. Under **Assets**, download the packaged app attached to the release—not GitHub’s automatically generated **Source code** archives. Follow the release notes for the available package format.
3. Unzip the download if needed, then drag `RARExtractor.app` to **Applications** and open it.

No Xcode or build tools are required. Read the release notes for signing and notarization status. If macOS blocks the app, verify its source and follow [Apple’s guidance](https://support.apple.com/102445); do not disable system security protections.

## Extract an archive

1. Open RARExtractor and choose a `.rar` file. You can also use Finder’s **Open With > RARExtractor**, or press **⌘O** in the app.
2. Extraction starts automatically. If prompted, enter the archive password and press Return.
3. Find the output folder in the same location as the archive. For example, `Photos.rar` extracts to `Photos`; if that folder exists, the app uses `Photos 2`, then `Photos 3`, and so on.

The original archive stays unchanged. The app quits automatically after successful extraction. The archive’s parent folder must be writable; there is currently no destination picker.

## Finder Quick Action

1. Install and open the app at least once.
2. Open **System Settings > General > Login Items & Extensions** and enable `Extract RAR` in the Finder extensions settings. The settings location may vary by macOS version.
3. Select one `.rar` file in Finder, then choose **Quick Actions > Extract RAR**.

In the Traditional Chinese interface, this action is named `解壓縮 RAR`. It asks for a password only when needed and extracts beside the archive without overwriting existing output folders.

## Updates

Sparkle is integrated for automatic update checks and the **Check for Updates…** menu item. It is disabled in builds without a configured update feed and signing public key; version 1.0.0 includes the update configuration.

Configured builds check automatically by default and ask before installing updates. If automatic updates are unavailable, download the newer app from [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases), quit RARExtractor, and replace the app in Applications. A GitHub release alone does not enable Sparkle updates.

## Troubleshooting

- **Incorrect password:** enter the password again. RARExtractor cannot recover forgotten passwords.
- **Unable to extract:** check that the archive is complete and its parent folder is writable. Full RAR compatibility testing is still in progress.
- **Quick Action missing:** open the app once, then check Finder extensions in System Settings.
- **Check for Updates… is disabled:** the build may lack an update source, or an update check may already be in progress.

## Project status and feedback

Universal 2 support and comprehensive compatibility, security, and large-archive testing are not complete.

Report problems or request features through [GitHub Issues](https://github.com/yanun0323/RARExtractor/issues). Include your macOS version, app version, and steps to reproduce. Do not upload private archives or passwords.

## Third-party software

Extraction uses RARLAB’s official UnRAR source. See the [UnRAR license](Vendor/UnRAR/license.txt). Updates use [Sparkle](https://github.com/sparkle-project/Sparkle).

UnRAR source: https://www.rarlab.com/rar/unrarsrc-7.2.7.tar.gz

SHA-256: `01d903a7dcf413cb2925696d7796e48e38d471f79bfe7ef3ad2aebf6c12dbefd`
