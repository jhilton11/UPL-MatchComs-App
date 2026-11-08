//
//  LoginView.swift
//  UPL MatchComs App
//

import SwiftUI
import UIKit

struct LoginView: View {
    let viewModel: LoginViewModel
    @State private var isPasswordVisible = false

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(spacing: 24) {
                LoginHeader()

                EmailPasswordForm(
                    email: $viewModel.email,
                    password: $viewModel.password,
                    isPasswordVisible: $isPasswordVisible,
                    isSigningIn: viewModel.isSigningIn,
                    canSignIn: viewModel.canSignInWithPassword,
                    signIn: {
                        Task {
                            await viewModel.signInWithEmailPassword()
                        }
                    }
                )

                LoginDivider()

                GoogleSignInButton(isSigningIn: viewModel.isSigningIn) {
                    guard let viewController = activeViewController else {
                        return
                    }

                    Task {
                        await viewModel.signInWithGoogle(presenting: viewController)
                    }
                }
            }
            .frame(maxWidth: 440)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .alert(
            "Unable to sign in",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var activeViewController: UIViewController? {
        let activeScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        return activeScene?.keyWindow?.rootViewController
    }
}

private enum LoginControlMetrics {
    static let height: CGFloat = 52
    static let cornerRadius: CGFloat = 12
}

private struct LoginHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Image("login_app_icon")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: LoginControlMetrics.cornerRadius,
                        style: .continuous
                    )
                )

            Text("Welcome back")
                .font(.largeTitle.bold())

            Text("Sign in to manage your match communications.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct EmailPasswordForm: View {
    @Binding var email: String
    @Binding var password: String
    @Binding var isPasswordVisible: Bool
    let isSigningIn: Bool
    let canSignIn: Bool
    let signIn: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email address", text: $email)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: LoginControlMetrics.height)
                .background(
                    .quaternary,
                    in: RoundedRectangle(
                        cornerRadius: LoginControlMetrics.cornerRadius,
                        style: .continuous
                    )
                )

            HStack {
                Group {
                    if isPasswordVisible {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textContentType(.password)

                Button("Show password") {
                    isPasswordVisible.toggle()
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPasswordVisible ? "Hide password" : "Show password")
            }
            .padding(.leading, 14)
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity)
            .frame(height: LoginControlMetrics.height)
            .background(
                .quaternary,
                in: RoundedRectangle(
                    cornerRadius: LoginControlMetrics.cornerRadius,
                    style: .continuous
                )
            )

            Button(action: signIn) {
                if isSigningIn {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign in")
                        .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: LoginControlMetrics.height)
            .background(
                Color.accentColor,
                in: RoundedRectangle(
                    cornerRadius: LoginControlMetrics.cornerRadius,
                    style: .continuous
                )
            )
            .opacity(!canSignIn || isSigningIn ? 0.5 : 1)
            .disabled(!canSignIn || isSigningIn)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LoginDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(.separator)
                .frame(height: 1)

            Text("OR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(.separator)
                .frame(height: 1)
        }
    }
}

private struct GoogleSignInButton: View {
    let isSigningIn: Bool
    let signIn: () -> Void

    var body: some View {
        Button(action: signIn) {
            Label("Continue with Google", systemImage: "g.circle")
                .frame(maxWidth: .infinity)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity)
        .frame(height: LoginControlMetrics.height)
        .background(
            .quaternary,
            in: RoundedRectangle(
                cornerRadius: LoginControlMetrics.cornerRadius,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: LoginControlMetrics.cornerRadius,
                style: .continuous
            )
            .stroke(.separator, lineWidth: 1)
        }
        .opacity(isSigningIn ? 0.5 : 1)
        .disabled(isSigningIn)
    }
}

#Preview {
    LoginView(viewModel: LoginViewModel())
}
