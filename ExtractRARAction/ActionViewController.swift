import AppKit
import UniformTypeIdentifiers

@MainActor
final class ActionViewController: NSViewController, ArchiveWorkerClientProtocol {
    private let passwordField = NSSecureTextField()
    private let currentItemLabel = NSTextField(labelWithString: "")
    private let progressIndicator = NSProgressIndicator()
    private let extractButton = NSButton(
        title: String(localized: "action.extract", defaultValue: "Extract"),
        target: nil,
        action: nil
    )

    private var passwordRow: NSStackView!
    private var archiveURL: URL?
    private var outputURL: URL?
    private var connection: NSXPCConnection?
    private var inputAccessActive = false
    private var didLoadInput = false
    private var isWorking = false

    override func loadView() {
        let rootView = NSView()

        passwordField.placeholderString = String(
            localized: "password.placeholder",
            defaultValue: "Password"
        )
        passwordField.setAccessibilityLabel(String(
            localized: "password.accessibilityLabel",
            defaultValue: "Password"
        ))
        passwordField.target = self
        passwordField.action = #selector(submitPassword)

        extractButton.target = self
        extractButton.action = #selector(submitPassword)
        extractButton.keyEquivalent = "\r"

        passwordRow = NSStackView(views: [passwordField, extractButton])
        passwordRow.orientation = .horizontal
        passwordRow.alignment = .centerY
        passwordRow.spacing = 12
        passwordField.setContentHuggingPriority(.defaultLow, for: .horizontal)

        progressIndicator.isIndeterminate = true
        progressIndicator.style = .bar
        progressIndicator.setAccessibilityLabel(String(
            localized: "progress.accessibilityLabel",
            defaultValue: "Extraction progress"
        ))

        currentItemLabel.lineBreakMode = .byTruncatingMiddle
        currentItemLabel.maximumNumberOfLines = 1
        currentItemLabel.isHidden = true
        currentItemLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let content = NSStackView(views: [currentItemLabel, passwordRow, progressIndicator])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        passwordRow.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        currentItemLabel.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        progressIndicator.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true

        rootView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            content.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            rootView.widthAnchor.constraint(greaterThanOrEqualToConstant: 340),
            rootView.heightAnchor.constraint(greaterThanOrEqualToConstant: 92)
        ])

        preferredContentSize = NSSize(width: 380, height: 92)
        view = rootView
        showProgress()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !didLoadInput else { return }
        didLoadInput = true
        loadInput()
    }

    @objc private func submitPassword() {
        inspectArchive()
    }

    nonisolated func archiveWorkerDidUpdate(
        completedBytes: Int64,
        totalBytes: Int64,
        currentItem: String
    ) {
        Task { @MainActor in
            self.showCurrentItem(currentItem)
            guard totalBytes > 0 else { return }
            self.progressIndicator.isIndeterminate = false
            self.progressIndicator.maxValue = Double(totalBytes)
            self.progressIndicator.doubleValue = Double(completedBytes)
            let percent = Int((Double(completedBytes) / Double(totalBytes)) * 100)
            self.progressIndicator.setAccessibilityValue("\(percent)%")
        }
    }

    private func loadInput() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first
        else {
            fail(String(
                localized: "error.noFinderInput",
                defaultValue: "Finder did not provide a RAR archive."
            ))
            return
        }

        let rarType = UTType(importedAs: "com.rarlab.rar-archive")
        guard let identifier = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: rarType) == true
        }) else {
            fail(String(
                localized: "error.notRAR",
                defaultValue: "Select a file with the .rar extension."
            ))
            return
        }

        provider.loadInPlaceFileRepresentation(forTypeIdentifier: identifier) { [weak self] url, _, _ in
            Task { @MainActor in
                guard let self else { return }
                guard let url else {
                    self.fail(String(
                        localized: "error.access",
                        defaultValue: "Unable to access the RAR archive."
                    ))
                    return
                }
                self.archiveURL = url
                self.inputAccessActive = url.startAccessingSecurityScopedResource()
                self.inspectArchive()
            }
        }
    }

    private func inspectArchive() {
        guard let archiveURL, !isWorking else { return }
        isWorking = true
        showProgress()

        do {
            worker().list(
                archiveBookmark: try makeBookmark(for: archiveURL),
                password: passwordField.stringValue.nilIfEmpty
            ) { [weak self] data, errorCode, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isWorking = false

                    if self.isPasswordError(errorCode) {
                        self.requestPassword(invalid: !self.passwordField.stringValue.isEmpty)
                        return
                    }
                    guard errorCode == ArchiveWorkerErrorCode.none.rawValue, let data else {
                        self.fail(localizedArchiveError(code: errorCode))
                        return
                    }

                    do {
                        let items = try JSONDecoder().decode([ArchiveItem].self, from: data)
                        if items.contains(where: \.isEncrypted), self.passwordField.stringValue.isEmpty {
                            self.requestPassword(invalid: false)
                        } else {
                            self.extract()
                        }
                    } catch {
                        self.fail(String(
                            localized: "error.workerData",
                            defaultValue: "Unable to read the archive information."
                        ))
                    }
                }
            }
        } catch {
            isWorking = false
            fail(String(
                localized: "error.access",
                defaultValue: "Unable to access the RAR archive."
            ))
        }
    }

    private func extract() {
        guard let archiveURL, !isWorking else { return }
        isWorking = true
        showProgress()

        do {
            let replacementDirectory = try FileManager.default.url(
                for: .itemReplacementDirectory,
                in: .userDomainMask,
                appropriateFor: archiveURL,
                create: true
            )
            let outputName = archiveURL.deletingPathExtension().lastPathComponent
            outputURL = replacementDirectory.appendingPathComponent(outputName, isDirectory: true)

            worker().extract(
                archiveBookmark: try makeBookmark(for: archiveURL),
                destinationBookmark: try makeBookmark(for: replacementDirectory),
                outputDirectoryName: outputName,
                password: passwordField.stringValue.nilIfEmpty
            ) { [weak self] errorCode, _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.isWorking = false

                    if self.isPasswordError(errorCode) {
                        self.requestPassword(invalid: true)
                        return
                    }
                    guard errorCode == ArchiveWorkerErrorCode.none.rawValue else {
                        self.fail(localizedArchiveError(code: errorCode))
                        return
                    }
                    self.completeRequest()
                }
            }
        } catch {
            isWorking = false
            fail(String(
                localized: "error.access",
                defaultValue: "Unable to access the RAR archive."
            ))
        }
    }

    private func requestPassword(invalid: Bool) {
        isWorking = false
        progressIndicator.stopAnimation(nil)
        progressIndicator.isHidden = true
        if currentItemLabel.stringValue.isEmpty {
            showCurrentItem(archiveURL?.lastPathComponent ?? "")
        }
        passwordRow.isHidden = false

        if invalid {
            passwordField.stringValue = ""
            passwordField.placeholderString = String(
                localized: "password.incorrect",
                defaultValue: "Incorrect password"
            )
            passwordField.setAccessibilityHelp(String(
                localized: "error.badPassword",
                defaultValue: "The password is incorrect."
            ))
        } else {
            passwordField.placeholderString = String(
                localized: "password.placeholder",
                defaultValue: "Password"
            )
        }
        view.window?.makeFirstResponder(passwordField)
    }

    private func showProgress() {
        passwordRow?.isHidden = true
        showCurrentItem("")
        progressIndicator.isHidden = false
        progressIndicator.isIndeterminate = true
        progressIndicator.doubleValue = 0
        progressIndicator.startAnimation(nil)
    }

    private func showCurrentItem(_ item: String) {
        let name = item.split { $0 == "/" || $0 == "\\" }.last.map(String.init) ?? ""
        currentItemLabel.stringValue = name
        currentItemLabel.toolTip = item.nilIfEmpty
        currentItemLabel.isHidden = name.isEmpty
    }

    private func isPasswordError(_ code: Int) -> Bool {
        code == ArchiveWorkerErrorCode.passwordRequired.rawValue ||
            code == ArchiveWorkerErrorCode.badPassword.rawValue
    }

    private func completeRequest() {
        guard let outputURL, let context = extensionContext else {
            fail(String(
                localized: "error.finderOutput",
                defaultValue: "Unable to return the extracted files to Finder."
            ))
            return
        }

        let provider = NSItemProvider()
        provider.registerFileRepresentation(
            forTypeIdentifier: UTType.folder.identifier,
            fileOptions: [.openInPlace],
            visibility: .all
        ) { completion in
            completion(outputURL, false, nil)
            return nil
        }
        let outputItem = NSExtensionItem()
        outputItem.attachments = [provider]
        context.completeRequest(returningItems: [outputItem]) { [weak self] _ in
            Task { @MainActor in self?.releaseInputAccess() }
        }
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
                    self.fail(String(
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
                self.fail(String(
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

    private func fail(_ message: String) {
        releaseInputAccess()
        let error = NSError(
            domain: "app.rarextractor.ExtractRARAction",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        extensionContext?.cancelRequest(withError: error)
    }

    private func releaseInputAccess() {
        if inputAccessActive {
            archiveURL?.stopAccessingSecurityScopedResource()
            inputAccessActive = false
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
