import Foundation

@objc protocol ArchiveWorkerProtocol {
    func list(
        archiveBookmark: Data,
        password: String?,
        withReply reply: @escaping (Data?, Int, String?) -> Void
    )

    func test(
        archiveBookmark: Data,
        password: String?,
        withReply reply: @escaping (Int, String?) -> Void
    )

    func extract(
        archiveBookmark: Data,
        destinationBookmark: Data,
        outputDirectoryName: String,
        password: String?,
        withReply reply: @escaping (Int, String?) -> Void
    )

    func cancel()
}

@objc protocol ArchiveWorkerClientProtocol {
    func archiveWorkerDidUpdate(
        completedBytes: Int64,
        totalBytes: Int64,
        currentItem: String
    )
}

struct ArchiveItem: Codable, Identifiable, Sendable {
    let path: String
    let size: UInt64
    let flags: UInt32

    var id: String { path }
    var isEncrypted: Bool { flags & (1 << 1) != 0 }
}

enum ArchiveWorkerErrorCode: Int {
    case workerFailure = -1
    case none = 0
    case invalidArgument = 1
    case openFailed = 2
    case badArchive = 3
    case badPassword = 4
    case passwordRequired = 5
    case missingVolume = 6
    case unsafeEntry = 7
    case resourceLimit = 8
    case cancelled = 9
    case writeFailed = 10
    case unknown = 11
}

func localizedArchiveError(code: Int) -> String {
    switch ArchiveWorkerErrorCode(rawValue: code) {
    case .openFailed:
        return String(localized: "error.openFailed", defaultValue: "Unable to open the RAR archive.")
    case .badArchive:
        return String(localized: "error.badArchive", defaultValue: "The RAR archive is damaged or unsupported.")
    case .badPassword:
        return String(localized: "error.badPassword", defaultValue: "The password is incorrect.")
    case .passwordRequired:
        return String(localized: "error.passwordRequired", defaultValue: "Enter the archive password.")
    case .missingVolume:
        return String(localized: "error.missingVolume", defaultValue: "A RAR volume is missing.")
    case .unsafeEntry:
        return String(localized: "error.unsafeEntry", defaultValue: "The RAR archive contains an unsafe item.")
    case .resourceLimit:
        return String(localized: "error.resourceLimit", defaultValue: "The RAR archive is too large to extract safely.")
    case .cancelled:
        return String(localized: "error.cancelled", defaultValue: "Extraction was canceled.")
    case .writeFailed:
        return String(localized: "error.writeFailed", defaultValue: "Unable to write next to the RAR archive.")
    default:
        return String(localized: "error.generic", defaultValue: "Unable to extract the RAR archive.")
    }
}
