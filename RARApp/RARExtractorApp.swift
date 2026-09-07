import AppKit
import SwiftUI
import Sparkle
import Combine

/// One updater per application, shared by all windows.
@MainActor
final class UpdateController: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    private let controller: SPUStandardUpdaterController
    private var observation: AnyCancellable?

    init(bundle: Bundle = .main) {
        controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil
        )
        // Development builds without a real feed/key must not contact a placeholder server.
        guard let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              let url = URL(string: feed), url.scheme == "https",
              let host = url.host, !host.isEmpty,
              let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }

        observation = controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.canCheckForUpdates = $0 }
        controller.startUpdater()
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var controller: ArchiveController? {
        didSet {
            deliverPendingURLs()
            if shouldChooseArchive {
                controller?.chooseArchiveIfNeeded()
            }
        }
    }
    private var pendingURLs: [URL] = []
    private var shouldChooseArchive = false

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        shouldChooseArchive = true
        controller?.chooseArchiveIfNeeded()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        shouldChooseArchive = false
        pendingURLs.append(contentsOf: urls)
        deliverPendingURLs()
    }

    private func deliverPendingURLs() {
        guard let controller,
              let archiveURL = pendingURLs.last(where: {
                  $0.pathExtension.caseInsensitiveCompare("rar") == .orderedSame
              })
        else { return }
        pendingURLs.removeAll()
        controller.selectArchive(archiveURL)
    }
}

@main
struct RARExtractorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = ArchiveController()
    @StateObject private var updates = UpdateController()

    var body: some Scene {
        WindowGroup("RAR Extractor") {
            ContentView(controller: controller)
                .onAppear {
                    appDelegate.controller = controller
                    DispatchQueue.main.async {
                        NSApplication.shared.keyWindow?.setContentSize(
                            NSSize(width: 340, height: 92)
                        )
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 340, height: 92)
        .commands {
            CommandGroup(after: .appInfo) {
                Button(
                    String(localized: "command.checkForUpdates", defaultValue: "Check for Updates…"),
                    action: updates.checkForUpdates
                )
                .disabled(!updates.canCheckForUpdates)
            }
            CommandGroup(replacing: .newItem) {
                Button(
                    String(localized: "command.openRAR", defaultValue: "Open RAR…"),
                    action: controller.chooseArchive
                )
                    .keyboardShortcut("o")
            }
        }
    }
}
