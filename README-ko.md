<a href="."><img height="160" src="./RARApp/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" alt="RARExtractor"></a>

[![English](https://img.shields.io/badge/English-Click-yellow)](README.md)
[![繁體中文](https://img.shields.io/badge/繁體中文-點擊查看-orange)](README-tw.md)
[![简体中文](https://img.shields.io/badge/简体中文-点击查看-orange)](README-cn.md)
[![日本語](https://img.shields.io/badge/日本語-クリック-blue)](README-ja.md)
[![한국어](https://img.shields.io/badge/한국어-클릭-yellow)](README-ko.md)

# RARExtractor

RAR 압축 파일을 풀 수 있는 가벼운 macOS 네이티브 앱입니다. 파일을 선택하고 필요한 경우 암호를 입력하면 원본 압축 파일과 같은 위치에 압축을 푼 폴더가 생성됩니다.

> Developer ID 서명과 Apple 공증을 완료한 앱을 [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases)에서 다운로드하세요.

## 기능

- `.rar` 파일의 압축을 풉니다. RAR 압축 파일을 만들거나 수정하지 않습니다.
- 암호가 필요한 경우에만 입력란을 표시합니다.
- 압축 해제 진행 상황과 처리 중인 파일 이름을 표시합니다.
- 기존 폴더를 보존합니다. 출력 폴더가 이미 있으면 이름에 번호를 붙입니다.
- Finder의 `Extract RAR` 빠른 동작으로 바로 압축을 풀 수 있습니다.
- 앱 인터페이스는 영어와 중국어 번체를 지원합니다. README 번역 언어가 모두 앱에서 지원되는 것은 아닙니다.

## 시스템 요구 사항

- macOS 14 이상.
- Apple silicon Mac. Intel Mac은 현재 지원하지 않습니다.
- 앱 다운로드와 업데이트 확인에는 인터넷 연결이 필요합니다.

## 설치

1. [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases)에서 최신 릴리스를 선택하세요.
2. **Assets**에서 릴리스에 첨부된 앱 배포 패키지를 다운로드하세요. GitHub가 자동 생성하는 **Source code** 압축 파일은 선택하지 마세요. 패키지 형식과 설치 안내는 릴리스 노트를 확인하세요.
3. 필요한 경우 다운로드한 파일의 압축을 풀고, `RARExtractor.app`을 응용 프로그램 폴더로 드래그한 후 여세요.

Xcode나 빌드 도구는 필요하지 않습니다. 서명 및 공증 상태는 릴리스 노트를 확인하세요. macOS가 실행을 차단하면 다운로드 출처를 확인하고 [Apple 안내](https://support.apple.com/102445)를 따르세요. 시스템 보안 보호 기능을 끄지 마세요.

## 압축 풀기

1. RARExtractor를 열고 `.rar` 파일을 선택하세요. Finder의 ‘다음으로 열기 > RARExtractor’를 사용하거나 앱에서 **⌘O**를 눌러도 됩니다.
2. 압축 해제가 자동으로 시작됩니다. 암호 입력란이 나타나면 압축 파일의 암호를 입력하고 Return을 누르세요.
3. 압축 파일과 같은 위치에서 출력 폴더를 확인하세요. 예를 들어 `Photos.rar`는 `Photos` 폴더에 풀립니다. 해당 폴더가 이미 있으면 `Photos 2`, `Photos 3` 순서로 이름을 붙입니다.

원본 압축 파일은 변경되지 않습니다. 압축 해제에 성공하면 앱이 자동으로 종료됩니다. 압축 파일이 있는 폴더에 쓰기 권한이 있어야 하며, 현재는 다른 출력 위치를 선택할 수 없습니다.

## Finder 빠른 동작

1. 앱을 설치한 후 한 번 이상 실행하세요.
2. ‘시스템 설정 > 일반 > 로그인 항목 및 확장 프로그램’을 열고 Finder 확장 프로그램 설정에서 `Extract RAR`를 활성화하세요. 설정 위치는 macOS 버전에 따라 다를 수 있습니다.
3. Finder에서 `.rar` 파일 하나를 선택한 후 ‘빠른 동작 > Extract RAR’를 실행하세요.

중국어 번체 인터페이스에서 이 동작의 이름은 `解壓縮 RAR`입니다. 필요한 경우에만 암호를 요청하며, 기존 출력 폴더를 덮어쓰지 않고 원본 압축 파일과 같은 위치에 압축을 풉니다.

## 업데이트

Sparkle을 통한 자동 업데이트 확인과 `Check for Updates…` 메뉴가 통합되어 있습니다. 업데이트 피드와 서명 공개 키가 설정되지 않은 빌드에서는 비활성화됩니다. 1.0.0에는 업데이트 설정이 포함되어 있습니다.

설정이 완료된 빌드는 기본적으로 업데이트를 자동 확인하고 설치 전에 동의를 구합니다. 자동 업데이트를 사용할 수 없다면 [GitHub Releases](https://github.com/yanun0323/RARExtractor/releases)에서 새 버전을 다운로드하고, RARExtractor를 종료한 후 응용 프로그램 폴더의 앱을 교체하세요. GitHub Release를 게시하는 것만으로 Sparkle 업데이트가 활성화되지는 않습니다.

## 문제 해결

- **암호가 올바르지 않음:** 암호를 다시 입력하세요. RARExtractor는 잊어버린 암호를 복구할 수 없습니다.
- **압축을 풀 수 없음:** 압축 파일이 온전하고 해당 폴더에 쓰기 권한이 있는지 확인하세요. 전체 RAR 호환성 테스트는 아직 진행 중입니다.
- **빠른 동작이 보이지 않음:** 앱을 한 번 실행한 후 시스템 설정에서 Finder 확장 프로그램을 확인하세요.
- **Check for Updates…를 사용할 수 없음:** 업데이트 소스가 설정되지 않았거나 업데이트 확인이 이미 진행 중일 수 있습니다.

## 프로젝트 상태 및 피드백

Universal 2 지원과 포괄적인 호환성·보안·대용량 압축 파일 테스트는 아직 완료되지 않았습니다.

문제나 기능 제안은 [GitHub Issues](https://github.com/yanun0323/RARExtractor/issues)에 등록하세요. macOS 버전, 앱 버전, 재현 단계를 포함해 주세요. 개인 압축 파일이나 암호는 업로드하지 마세요.

## 타사 소프트웨어

압축 해제에는 RARLAB 공식 UnRAR 소스를 사용합니다. [UnRAR 라이선스](Vendor/UnRAR/license.txt)를 확인하세요. 업데이트에는 [Sparkle](https://github.com/sparkle-project/Sparkle)을 사용합니다.

UnRAR 소스: https://www.rarlab.com/rar/unrarsrc-7.2.7.tar.gz

SHA-256: `01d903a7dcf413cb2925696d7796e48e38d471f79bfe7ef3ad2aebf6c12dbefd`
