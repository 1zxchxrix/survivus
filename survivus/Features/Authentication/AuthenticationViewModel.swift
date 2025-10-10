import Foundation
import LocalAuthentication

@MainActor
final class AuthenticationViewModel: ObservableObject {
    struct Credential {
        let userId: String
        let passcode: String
    }

    @Published var username: String = ""
    @Published var passcode: String = ""
    @Published var errorMessage: String?
    @Published private(set) var requiresPasscode: Bool = false
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var authenticatedUserID: String?

    private let credentialsByUsername: [String: Credential]
    private var pendingCredential: Credential?

    init() {
        credentialsByUsername = [
            "zac": Credential(userId: "u1", passcode: "8328"),
            "sam": Credential(userId: "u2", passcode: "1514"),
            "chris": Credential(userId: "u3", passcode: "5343"),
            "liz": Credential(userId: "u4", passcode: "5343")
        ]
    }

    func submitUsername() {
        errorMessage = nil
        requiresPasscode = false
        passcode = ""

        let normalizedUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalizedUsername.isEmpty else {
            errorMessage = "Enter a username to continue."
            return
        }

        guard let credential = credentialsByUsername[normalizedUsername] else {
            errorMessage = "We couldn't find that username."
            return
        }

        pendingCredential = credential
        attemptBiometricAuthentication(with: credential)
    }

    func verifyPasscode() {
        guard let credential = pendingCredential else {
            errorMessage = "Select a username before entering a passcode."
            return
        }

        guard passcode == credential.passcode else {
            errorMessage = "The passcode you entered is incorrect."
            return
        }

        completeAuthentication(with: credential)
    }

    private func attemptBiometricAuthentication(with credential: Credential) {
        let context = LAContext()
        context.localizedFallbackTitle = ""

        var biometricError: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &biometricError) {
            let reason = "Authenticate with Face ID to access Survivus."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evaluateError in
                Task { @MainActor in
                    guard !self.isAuthenticated else { return }

                    if success {
                        self.completeAuthentication(with: credential)
                    } else {
                        self.requiresPasscode = true
                        if (evaluateError as? LAError)?.code != .userCancel {
                            self.errorMessage = "Face ID failed. Enter your passcode to continue."
                        }
                    }
                }
            }
        } else {
            requiresPasscode = true
            errorMessage = "Face ID isn't available. Enter your passcode to continue."
        }
    }

    private func completeAuthentication(with credential: Credential) {
        authenticatedUserID = credential.userId
        isAuthenticated = true
        requiresPasscode = false
        errorMessage = nil
    }
}
