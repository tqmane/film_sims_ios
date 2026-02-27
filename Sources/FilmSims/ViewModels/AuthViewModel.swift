import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

/// iOS equivalent of Android's AuthViewModel.
/// Handles Google Sign-In via Firebase Auth and pro status checking.
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var userName: String? = nil
    @Published var userEmail: String? = nil

    private let proUserRepository = ProUserRepository.shared

    init() {
        restoreSession()
    }

    /// Restore existing Firebase Auth session on app launch.
    private func restoreSession() {
        if let user = Auth.auth().currentUser {
            isSignedIn = true
            userName = user.displayName
            userEmail = user.email
            Task {
                await proUserRepository.checkProStatus(email: user.email)
            }
        }
    }

    /// Sign in with Google using Firebase Auth.
    func signInWithGoogle() {
        guard !isLoading else { return }
        isLoading = true

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("AuthViewModel: Missing Firebase client ID")
            isLoading = false
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            print("AuthViewModel: No root view controller")
            isLoading = false
            return
        }

        Task { @MainActor in
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                guard let idToken = result.user.idToken?.tokenString else {
                    isLoading = false
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )

                let authResult = try await Auth.auth().signIn(with: credential)
                let user = authResult.user

                isSignedIn = true
                userName = user.displayName
                userEmail = user.email
                isLoading = false

                await proUserRepository.checkProStatus(email: user.email)
            } catch {
                print("AuthViewModel: Sign in failed: \(error)")
                isLoading = false
            }
        }
    }

    /// Sign out from both Firebase and Google.
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            print("AuthViewModel: Sign out error: \(error)")
        }

        isSignedIn = false
        userName = nil
        userEmail = nil
        proUserRepository.clearProStatus()
    }
}
