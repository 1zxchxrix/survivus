import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var viewModel: AuthenticationViewModel
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case username
        case passcode
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome to Survivus")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Enter your username to get started. We'll try Face ID first and fall back to your passcode if needed.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        TextField("zac", text: $viewModel.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .submitLabel(.continue)
                            .focused($focusedField, equals: .username)
                            .onSubmit { viewModel.submitUsername() }
                            .textFieldStyle(.roundedBorder)
                    }

                    Button("Continue") {
                        viewModel.submitUsername()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }

                if viewModel.requiresPasscode {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Passcode")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        SecureField("••••", text: $viewModel.passcode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .focused($focusedField, equals: .passcode)
                            .onSubmit { viewModel.verifyPasscode() }
                            .textFieldStyle(.roundedBorder)

                        Button("Sign In") {
                            viewModel.verifyPasscode()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }
            .padding(24)
            .frame(maxWidth: 480)
            .multilineTextAlignment(.leading)
            .navigationTitle("Sign In")
            .onAppear {
                focusedField = .username
            }
            .onChange(of: viewModel.requiresPasscode) { requiresPasscode in
                focusedField = requiresPasscode ? .passcode : .username
            }
            .animation(.easeInOut, value: viewModel.requiresPasscode)
            .animation(.easeInOut, value: viewModel.errorMessage)
        }
    }
}

#Preview {
    AuthenticationView(viewModel: AuthenticationViewModel())
}
