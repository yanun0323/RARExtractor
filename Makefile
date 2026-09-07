CXX := clang++
CXXFLAGS := -std=c++17 -O2 -Wall -Wextra -Wpedantic -mmacosx-version-min=14.0
UNRAR_CXXFLAGS := -O2 -std=c++11 -Wno-logical-op-parentheses -Wno-switch -Wno-dangling-else -mmacosx-version-min=14.0
CPPFLAGS := -D_UNIX -ISources/UnRARBridge/include -IVendor/UnRAR
BUILD_DIR := build
XCODE_BUILD_DIR := DerivedData/Build/Products/Debug
APP := $(CURDIR)/$(XCODE_BUILD_DIR)/RARExtractor.app
ACTION := $(APP)/Contents/PlugIns/ExtractRARAction.appex
UNRAR_DIR := Vendor/UnRAR
UNRAR_LIBRARY := $(UNRAR_DIR)/libunrar.a

.PHONY: $(wildcard *)

## help: 顯示可用指令
help:
	@echo ""
	@echo "Usage:"
	@echo ""
	@sed -n 's/^## //p' Makefile | column -t -s ':' | sed -e 's/^/\t/'
	@echo ""

## build: 建立 UnRARBridge 與命令列原型
build: $(BUILD_DIR)/rar-prototype

## app: 建立 macOS 應用程式與 ArchiveWorker XPC service
app:
	@xcodebuild -quiet -workspace RARExtractor.xcworkspace -scheme RARExtractor -configuration Debug -derivedDataPath DerivedData build

## release: 建置、簽署、公證並產生 Release ZIP 與 Sparkle appcast（不發布）
release:
	@bash scripts/release.sh

## test: 建立並執行安全邊界測試
test: $(BUILD_DIR)/path-safety-test
	@$(BUILD_DIR)/path-safety-test

## xpc-test: 透過 macOS 應用程式驗證 bookmark、XPC 和解壓縮
xpc-test: app
	@smoke_dir=$$(mktemp -d /tmp/rar-xpc-smoke.XXXXXX); \
	trap 'rm -rf "$$smoke_dir"' EXIT; \
	curl --connect-timeout 10 --max-time 180 -fsSL https://raw.githubusercontent.com/libarchive/libarchive/master/libarchive/test/test_read_format_rar_binary_data.rar.uu -o "$$smoke_dir/sample.rar.uu"; \
	uudecode -o "$$smoke_dir/sample.rar" "$$smoke_dir/sample.rar.uu"; \
	pkill -x RARExtractor 2>/dev/null || true; \
	open -W -n -g --env RAR_XPC_SMOKE_TEST=1 --stdout "$$smoke_dir/stdout.log" --stderr "$$smoke_dir/stderr.log" -a "$(APP)" "$$smoke_dir/sample.rar"; \
	cat "$$smoke_dir/stdout.log"; \
	cat "$$smoke_dir/stderr.log" >&2; \
	grep -q '^RAR_XPC_SMOKE_TEST: passed: 2 items$$' "$$smoke_dir/stdout.log"; \
	test "$$(find "$$smoke_dir/sample" -type f | wc -l | tr -d ' ')" = 2

## action-test: 驗證 Finder Quick Action bundle、簽章和註冊
action-test: xpc-test
	@test -x "$(ACTION)/Contents/MacOS/ExtractRARAction"
	@test -x "$(ACTION)/Contents/XPCServices/ArchiveWorker.xpc/Contents/MacOS/ArchiveWorker"
	@test "$$(plutil -extract NSExtension.NSExtensionPointIdentifier raw -o - "$(ACTION)/Contents/Info.plist")" = "com.apple.ui-services"
	@! plutil -extract NSExtension.NSExtensionAttributes.NSExtensionActivationRule raw -o - "$(ACTION)/Contents/Info.plist" | grep -q TRUEPREDICATE
	@codesign --verify --deep --strict "$(APP)"
	@pluginkit -a "$(ACTION)"
	@pluginkit -m -A -D -v -i app.rarextractor.ExtractRARAction | grep -q "$(ACTION)"

## run: 執行原型，例如 make run list sample.rar
run: build
	@$(BUILD_DIR)/rar-prototype $(ARGS)

## clean: 移除建置產物
clean:
	@$(MAKE) -C $(UNRAR_DIR) -f makefile clean
	@rm -rf $(BUILD_DIR) DerivedData

$(BUILD_DIR)/.created:
	@mkdir -p $(BUILD_DIR)
	@touch $@

$(UNRAR_LIBRARY):
	@$(MAKE) -C $(UNRAR_DIR) -f makefile lib CXX=$(CXX) CXXFLAGS="$(UNRAR_CXXFLAGS)" AR=ar STRIP=strip

$(BUILD_DIR)/rar_bridge.o: Sources/UnRARBridge/rar_bridge.cpp Sources/UnRARBridge/include/rar_bridge.h | $(BUILD_DIR)/.created
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/rar-prototype: Sources/RARPrototype/main.cpp $(BUILD_DIR)/rar_bridge.o $(UNRAR_LIBRARY)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $^ -pthread -o $@

$(BUILD_DIR)/path-safety-test: Tests/path_safety_test.cpp $(BUILD_DIR)/rar_bridge.o $(UNRAR_LIBRARY)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $^ -pthread -o $@

ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
%:
	@:
