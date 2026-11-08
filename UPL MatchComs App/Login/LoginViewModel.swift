//
//  LoginViewModel.swift
//  UPL MatchComs App
//

import FirebaseAuth
import Foundation
import GoogleSignIn
import Observation
import UIKit

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isSigningIn = false
    private(set) var errorMessage: String?
    private(set) var isAuthenticated: Bool

    init() {
        isAuthenticated = Auth.auth().currentUser != nil
    }

    var canSignInWithPassword: Bool {
        !email.isEmpty && !password.isEmpty
    }

    func signInWithEmailPassword() async {
        guard canSignInWithPassword else {
            errorMessage = "Enter your email address and password."
            return
        }

        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            isAuthenticated = result.user.uid.isEmpty == false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithGoogle(presenting viewController: UIViewController) async {
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)

            guard let idToken = result.user.idToken?.tokenString else {
                throw LoginError.missingGoogleIDToken
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authenticationResult = try await Auth.auth().signIn(with: credential)
            isAuthenticated = authenticationResult.user.uid.isEmpty == false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            email = ""
            password = ""
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }
}

private enum LoginError: LocalizedError {
    case missingGoogleIDToken

    var errorDescription: String? {
        switch self {
        case .missingGoogleIDToken:
            return String(localized: "Google Sign-In did not return an identity token.")
        }
    }
}
