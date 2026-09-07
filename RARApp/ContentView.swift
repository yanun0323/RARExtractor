import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: ArchiveController
    @FocusState private var passwordIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !controller.currentItemName.isEmpty {
                Text(controller.currentItemName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(controller.currentItem)
            }

            if controller.needsPassword {
                HStack(spacing: 12) {
                    SecureField(passwordPrompt, text: $controller.password)
                        .textFieldStyle(.roundedBorder)
                        .focused($passwordIsFocused)
                        .accessibilityLabel(String(
                            localized: "password.accessibilityLabel",
                            defaultValue: "Password"
                        ))
                        .accessibilityHint(passwordHint)
                        .onSubmit(controller.submitPassword)

                    Button(
                        String(localized: "action.extract", defaultValue: "Extract"),
                        action: controller.submitPassword
                    )
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                if controller.totalBytes > 0 {
                    ProgressView(value: controller.progress)
                        .progressViewStyle(.linear)
                        .accessibilityLabel(progressLabel)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .accessibilityLabel(progressLabel)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .frame(width: 340, height: 92)
        .onChange(of: controller.needsPassword) { _, needsPassword in
            passwordIsFocused = needsPassword
        }
        .alert(
            String(localized: "error.title", defaultValue: "Unable to Extract"),
            isPresented: $controller.showsError
        ) {
            Button(String(localized: "action.chooseAnother", defaultValue: "Choose Another RAR…")) {
                controller.chooseArchive()
            }
            Button(String(localized: "action.close", defaultValue: "Close"), role: .cancel) {
                NSApplication.shared.keyWindow?.close()
            }
        } message: {
            Text(controller.errorMessage)
        }
    }

    private var passwordPrompt: String {
        if controller.passwordIsInvalid {
            return String(localized: "password.incorrect", defaultValue: "Incorrect password")
        }
        return String(localized: "password.placeholder", defaultValue: "Password")
    }

    private var progressLabel: String {
        String(localized: "progress.accessibilityLabel", defaultValue: "Extraction progress")
    }

    private var passwordHint: String {
        guard controller.passwordIsInvalid else { return "" }
        return String(localized: "error.badPassword", defaultValue: "The password is incorrect.")
    }
}
