import Foundation

private enum WorkerError: LocalizedError {
    case busy
    case invalidBookmark(String)
    case staleBookmark
    case accessDenied
    case invalidOutputName

    var errorDescription: String? {
        switch self {
        case .busy:
            return "ArchiveWorker 正在執行另一個操作。"
        case .invalidBookmark(let detail):
            return "ArchiveWorker 無法讀取檔案權限：\(detail)"
        case .staleBookmark:
            return "檔案權限已失效。請重新選取檔案。"
        case .accessDenied:
            return "ArchiveWorker 沒有檔案存取權限。"
        case .invalidOutputName:
            return "輸出資料夾名稱無效。"
        }
    }
}

private struct ArchiveWorkerFailure: LocalizedError {
    let code: Int
    let errorDescription: String?
}

private final class OperationContext {
    let client: ArchiveWorkerClientProtocol?
    var items: [ArchiveItem] = []
    var currentItem = ""
    var lastProgressUpdate = ContinuousClock.now

    init(client: ArchiveWorkerClientProtocol?) {
        self.client = client
    }

    func report(completedBytes: UInt64, totalBytes: UInt64, force: Bool = false) {
        let now = ContinuousClock.now
        guard force || now - lastProgressUpdate >= .milliseconds(100) else { return }
        lastProgressUpdate = now
        client?.archiveWorkerDidUpdate(
            completedBytes: Int64(clamping: completedBytes),
            totalBytes: Int64(clamping: totalBytes),
            currentItem: currentItem
        )
    }
}

private func collectItem(
    _ item: UnsafePointer<RARBridgeItem>?,
    _ rawContext: UnsafeMutableRawPointer?
) -> Int32 {
    guard let item, let rawContext, let path = item.pointee.path else { return 1 }
    let context = Unmanaged<OperationContext>.fromOpaque(rawContext).takeUnretainedValue()
    context.currentItem = String(cString: path)
    context.items.append(
        ArchiveItem(
            path: context.currentItem,
            size: item.pointee.unpacked_size,
            flags: item.pointee.flags
        )
    )
    context.report(completedBytes: 0, totalBytes: 0, force: true)
    return 0
}

private func reportProgress(
    _ completedBytes: UInt64,
    _ totalBytes: UInt64,
    _ rawContext: UnsafeMutableRawPointer?
) -> Int32 {
    guard let rawContext else { return 1 }
    let context = Unmanaged<OperationContext>.fromOpaque(rawContext).takeUnretainedValue()
    context.report(
        completedBytes: completedBytes,
        totalBytes: totalBytes,
        force: completedBytes >= totalBytes
    )
    return 0
}

final class ArchiveWorker: NSObject, ArchiveWorkerProtocol {
    private weak var connection: NSXPCConnection?
    private let queue = DispatchQueue(label: "app.rarextractor.worker")
    private let cancellationLock = NSLock()
    private var activeCancellation: OpaquePointer?

    init(connection: NSXPCConnection) {
        self.connection = connection
    }

    func list(
        archiveBookmark: Data,
        password: String?,
        withReply reply: @escaping (Data?, Int, String?) -> Void
    ) {
        perform(reply: reply) { cancellation in
            let archive = try self.resolve(bookmark: archiveBookmark)
            defer { archive.stopAccessing() }

            let context = self.makeContext()
            let result = self.callBridge(
                operation: .list,
                archiveURL: archive.url,
                destinationURL: nil,
                password: password,
                cancellation: cancellation,
                context: context
            )
            try self.check(result)
            return try JSONEncoder().encode(context.items)
        }
    }

    func test(
        archiveBookmark: Data,
        password: String?,
        withReply reply: @escaping (Int, String?) -> Void
    ) {
        perform(reply: { _, code, error in reply(code, error) }) { cancellation in
            let archive = try self.resolve(bookmark: archiveBookmark)
            defer { archive.stopAccessing() }

            let result = self.callBridge(
                operation: .test,
                archiveURL: archive.url,
                destinationURL: nil,
                password: password,
                cancellation: cancellation,
                context: self.makeContext()
            )
            try self.check(result)
            return nil
        }
    }

    func extract(
        archiveBookmark: Data,
        destinationBookmark: Data,
        outputDirectoryName: String,
        password: String?,
        withReply reply: @escaping (Int, String?) -> Void
    ) {
        perform(reply: { _, code, error in reply(code, error) }) { cancellation in
            guard outputDirectoryName == URL(fileURLWithPath: outputDirectoryName).lastPathComponent,
                  outputDirectoryName != ".",
                  outputDirectoryName != ".."
            else {
                throw WorkerError.invalidOutputName
            }

            let archive = try self.resolve(bookmark: archiveBookmark)
            defer { archive.stopAccessing() }
            let destination = try self.resolve(bookmark: destinationBookmark)
            defer { destination.stopAccessing() }

            let outputURL = destination.url.appendingPathComponent(
                outputDirectoryName,
                isDirectory: true
            )
            let result = self.callBridge(
                operation: .extract,
                archiveURL: archive.url,
                destinationURL: outputURL,
                password: password,
                cancellation: cancellation,
                context: self.makeContext()
            )
            try self.check(result)
            return nil
        }
    }

    func cancel() {
        cancellationLock.withLock {
            if let activeCancellation {
                rar_bridge_cancel(activeCancellation)
            }
        }
    }

    private enum Operation {
        case list
        case test
        case extract
    }

    private func perform(
        reply: @escaping (Data?, Int, String?) -> Void,
        operation: @escaping (OpaquePointer) throws -> Data?
    ) {
        queue.async {
            guard let cancellation = rar_bridge_cancellation_create() else {
                reply(nil, ArchiveWorkerErrorCode.workerFailure.rawValue, "ArchiveWorker 無法建立取消控制。")
                return
            }

            let accepted = self.cancellationLock.withLock {
                guard self.activeCancellation == nil else { return false }
                self.activeCancellation = cancellation
                return true
            }
            guard accepted else {
                rar_bridge_cancellation_destroy(cancellation)
                reply(nil, ArchiveWorkerErrorCode.workerFailure.rawValue, WorkerError.busy.localizedDescription)
                return
            }

            defer {
                self.cancellationLock.withLock { self.activeCancellation = nil }
                rar_bridge_cancellation_destroy(cancellation)
            }

            do {
                reply(try operation(cancellation), ArchiveWorkerErrorCode.none.rawValue, nil)
            } catch let error as ArchiveWorkerFailure {
                reply(nil, error.code, error.localizedDescription)
            } catch {
                reply(nil, ArchiveWorkerErrorCode.workerFailure.rawValue, error.localizedDescription)
            }
        }
    }

    private struct ResolvedURL {
        let url: URL
        let isSecurityScoped: Bool

        func stopAccessing() {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    private func resolve(bookmark: Data) throws -> ResolvedURL {
        var isStale = false
        let url: URL
        do {
            url = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withoutUI, .withoutImplicitStartAccessing],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw WorkerError.invalidBookmark(error.localizedDescription)
        }
        guard !isStale else { throw WorkerError.staleBookmark }
        return ResolvedURL(
            url: url,
            isSecurityScoped: url.startAccessingSecurityScopedResource()
        )
    }

    private func makeContext() -> OperationContext {
        let client = connection?.remoteObjectProxyWithErrorHandler { error in
            NSLog("ArchiveWorker client connection failed: %@", error.localizedDescription)
        } as? ArchiveWorkerClientProtocol
        return OperationContext(client: client)
    }

    private func callBridge(
        operation: Operation,
        archiveURL: URL,
        destinationURL: URL?,
        password: String?,
        cancellation: OpaquePointer,
        context: OperationContext
    ) -> (RARBridgeResult, String) {
        archiveURL.path.withCString { archivePath in
            withOptionalCString(destinationURL?.path) { destinationPath in
                withOptionalCString(password) { passwordPointer in
                    var options = RARBridgeOptions()
                    options.archive_path = archivePath
                    options.destination_path = destinationPath
                    options.password = passwordPointer
                    options.maximum_dictionary_size = 4 * 1_024 * 1_024 * 1_024
                    options.maximum_total_size = 1_024 * 1_024 * 1_024 * 1_024
                    options.maximum_file_size = 256 * 1_024 * 1_024 * 1_024
                    options.maximum_item_count = 1_000_000
                    options.maximum_directory_depth = 128

                    let retainedContext = Unmanaged.passRetained(context)
                    defer { retainedContext.release() }
                    var callbacks = RARBridgeCallbacks()
                    callbacks.item = collectItem
                    callbacks.progress = reportProgress
                    callbacks.context = retainedContext.toOpaque()

                    var error = [CChar](repeating: 0, count: 512)
                    let result = error.withUnsafeMutableBufferPointer { buffer in
                        switch operation {
                        case .list:
                            return rar_bridge_list(
                                &options,
                                &callbacks,
                                cancellation,
                                buffer.baseAddress,
                                buffer.count
                            )
                        case .test:
                            return rar_bridge_test(
                                &options,
                                &callbacks,
                                cancellation,
                                buffer.baseAddress,
                                buffer.count
                            )
                        case .extract:
                            return rar_bridge_extract(
                                &options,
                                &callbacks,
                                cancellation,
                                buffer.baseAddress,
                                buffer.count
                            )
                        }
                    }
                    return (result, String(cString: error))
                }
            }
        }
    }

    private func withOptionalCString<Result>(
        _ string: String?,
        _ body: (UnsafePointer<CChar>?) -> Result
    ) -> Result {
        guard let string else { return body(nil) }
        return string.withCString(body)
    }

    private func check(_ response: (RARBridgeResult, String)) throws {
        guard response.0.rawValue == 0 else {
            throw ArchiveWorkerFailure(
                code: Int(response.0.rawValue),
                errorDescription: response.1
            )
        }
    }
}
