import Foundation

final class ArchiveWorkerListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        let worker = ArchiveWorker(connection: connection)
        connection.exportedInterface = NSXPCInterface(with: ArchiveWorkerProtocol.self)
        connection.exportedObject = worker
        connection.remoteObjectInterface = NSXPCInterface(with: ArchiveWorkerClientProtocol.self)
        connection.resume()
        return true
    }
}

let delegate = ArchiveWorkerListenerDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

