import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

/// iOS equivalent of Android's AuthViewModel.
/// Handles Google Sign-In via Firebase Auth and pro status checking.
@MainActor
final class AuthViewModel: ObservableObject {
    /// Shared singleton — initialised on app launch so `restoreSession()` runs
    /// before any view appears and pro status is populated without opening Settings.
    static let shared = AuthViewModel()

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
                NSLog("AuthViewModel: Starting GIDSignIn.signIn(withPresenting:)")
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
                NSLog("AuthViewModel: GIDSignIn succeeded, user=%@", result.user.userID ?? "nil")
                guard let idToken = result.user.idToken?.tokenString else {
                    NSLog("AuthViewModel: No idToken in result")
                    isLoading = false
                    return
                }

                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )

                NSLog("AuthViewModel: Calling Firebase Auth signIn")
                let authResult = try await Auth.auth().signIn(with: credential)
                let user = authResult.user
                NSLog("AuthViewModel: Firebase Auth succeeded, email=%@", user.email ?? "nil")

                isSignedIn = true
                userName = user.displayName
                userEmail = user.email
                isLoading = false
                AnalyticsManager.logSignIn(provider: "google")

                await proUserRepository.checkProStatus(email: user.email)
            } catch {
                NSLog("AuthViewModel: Sign in failed: %@", error.localizedDescription)
                NSLog("AuthViewModel: Full error: %@", String(describing: error))
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
        AnalyticsManager.logSignOut()
    }
}
