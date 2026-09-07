import AppKit
import Foundation

@MainActor
final class ArchiveController: NSObject, ObservableObject, ArchiveWorkerClientProtocol {
    @Published var password = ""
    @Published private(set) var completedBytes: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var currentItem = ""
    @Published private(set) var needsPassword = false
    @Published private(set) var passwordIsInvalid = false
    @Published var showsError = false
    @Published private(set) var errorMessage = ""

    private var archiveURL: URL?
    private var connection: NSXPCConnection?
    private var isWorking = false
    private var didOfferArchivePicker = false
#if DEBUG
    private var itemCount = 0
    private let isXPCSmokeTest = ProcessInfo.processInfo.environment["RAR_XPC_SMOKE_TEST"] == "1"
#endif

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(Double(completedBytes) / Double(totalBytes), 1)
    }

    var currentItemName: String {
        currentItem.split { $0 == "/" || $0 == "\\" }.last.map(String.init) ?? ""
    }

    func chooseArchiveIfNeeded() {
        guard archiveURL == nil, !didOfferArchivePicker else { return }
        chooseArchive()
    }

    func chooseArchive() {
        didOfferArchivePicker = true
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(importedAs: "com.rarlab.rar-archive")]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { [weak self] response in
            Task { @MainActor in
                guard let self else { return }
                guard response == .OK, let url = panel.url else {
                    NSApplication.shared.keyWindow?.close()
                    return
                }
                self.selectArchive(url)
            }
        }
    }

    func selectArchive(_ url: URL) {
        guard url.pathExtension.caseInsensitiveCompare("rar") == .orderedSame else {
            showError(String(
                localized: "error.notRAR",
                defaultValue: "Select a file with the .rar extension."
            ))
            return
        }

        archiveURL = url
        password = ""
        passwordIsInvalid = false
        inspectArchive()
    }

    func submitPassword() {
        inspectArchive()
    }

    nonisolated func archiveWorkerDidUpdate(
        completedBytes: Int64,
        totalBytes: Int64,
        currentItem: String
    ) {
        Task { @MainActor in
            self.completedBytes = completedBytes
            self.totalBytes = totalBytes
            self.currentItem = currentItem
        }
    }

    private func inspectArchive() {
        guard let archiveURL, !isWorking else { return }
        startWorking()

        do {
            worker().list(
                archiveBookmark: try makeBookmark(for: archiveURL),
                password: password.nilIfEmpty
            ) { [weak self] data, errorCode, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isWorking = false

                    if self.isPasswordError(errorCode) {
                        self.requestPassword(invalid: !self.password.isEmpty)
                        return
                    }
                    guard errorCode == ArchiveWorkerErrorCode.none.rawValue, let data else {
                        self.showError(localizedArchiveError(code: errorCode))
                        return
                    }

                    do {
                        let items = try JSONDecoder().decode([ArchiveItem].self, from: data)
#if DEBUG
                        self.itemCount = items.count
#endif
                        if items.contains(where: \.isEncrypted), self.password.isEmpty {
                            self.requestPassword(invalid: false)
                        } else {
                            self.extract()
                        }
                    } catch {
                        self.showError(String(
                            localized: "error.workerData",
                            defaultValue: "Unable to read the archive information."
                        ))
                    }
                }
            }
        } catch {
            isWorking = false
            showError(String(
                localized: "error.access",
                defaultValue: "Unable to access the RAR archive."
            ))
        }
    }

    private func extract() {
        guard let archiveURL, !isWorking else { return }
        startWorking()

        let destinationURL = archiveURL.deletingLastPathComponent()
        let outputName = availableOutputName(
            baseName: archiveURL.deletingPathExtension().lastPathComponent,
            in: destinationURL
        )

        do {
            worker().extract(
                archiveBookmark: try makeBookmark(for: archiveURL),
                destinationBookmark: try makeBookmark(for: destinationURL),
                outputDirectoryName: outputName,
                password: password.nilIfEmpty
            ) { [weak self] errorCode, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isWorking = false

                    if self.isPasswordError(errorCode) {
                        self.requestPassword(invalid: true)
                        return
                    }
                    guard errorCode == ArchiveWorkerErrorCode.none.rawValue else {
                        self.showError(localizedArchiveError(code: errorCode))
                        return
                    }

#if DEBUG
                    if self.isXPCSmokeTest {
                        self.finishSmokeTest(error: nil)
                        return
                    }
#endif
                    NSApplication.shared.terminate(nil)
                }
            }
        } catch {
            isWorking = false
            showError(String(
                localized: "error.access",
                defaultValue: "Unable to access the RAR archive."
            ))
        }
    }

    private func requestPassword(invalid: Bool) {
        isWorking = false
        needsPassword = true
        passwordIsInvalid = invalid
        if currentItem.isEmpty {
            currentItem = archiveURL?.lastPathComponent ?? ""
        }
        if invalid {
            password = ""
        }
    }

    private func isPasswordError(_ code: Int) -> Bool {
        code == ArchiveWorkerErrorCode.passwordRequired.rawValue ||
            code == ArchiveWorkerErrorCode.badPassword.rawValue
    }

    private func worker() -> ArchiveWorkerProtocol {
        if connection == nil {
            let connection = NSXPCConnection(serviceName: "app.rarextractor.ArchiveWorker")
            connection.remoteObjectInterface = NSXPCInterface(with: ArchiveWorkerProtocol.self)
            connection.exportedInterface = NSXPCInterface(with: ArchiveWorkerClientProtocol.self)
            connection.exportedObject = self
            connection.invalidationHandler = { [weak self] in
                Task { @MainActor in
                    guard let self, self.isWorking else { return }
                    self.connection = nil
                    self.isWorking = false
                    self.showError(String(
                        localized: "error.workerConnection",
                        defaultValue: "The extraction service stopped."
                    ))
                }
            }
            connection.resume()
            self.connection = connection
        }

        return connection!.remoteObjectProxyWithErrorHandler { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isWorking = false
                self.showError(String(
                    localized: "error.workerConnection",
                    defaultValue: "The extraction service stopped."
                ))
            }
        } as! ArchiveWorkerProtocol
    }

    private func makeBookmark(for url: URL) throws -> Data {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess { url.stopAccessingSecurityScopedResource() }
        }
        return try url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    private func availableOutputName(baseName: String, in directory: URL) -> String {
        var candidate = baseName
        var suffix = 2
        while FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(candidate).path
        ) {
            candidate = "\(baseName) \(suffix)"
            suffix += 1
        }
        return candidate
    }

    private func startWorking() {
        isWorking = true
        needsPassword = false
        completedBytes = 0
        totalBytes = 0
        currentItem = ""
    }

    private func showError(_ message: String) {
        errorMessage = message
        showsError = true
#if DEBUG
        finishSmokeTest(error: message)
#endif
    }

#if DEBUG
    private func finishSmokeTest(error: String?) {
        guard isXPCSmokeTest else { return }
        if let error {
            print("RAR_XPC_SMOKE_TEST: failed: \(error)")
        } else {
            print("RAR_XPC_SMOKE_TEST: passed: \(itemCount) items")
        }
        fflush(stdout)
        NSApplication.shared.terminate(nil)
    }
#endif
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
