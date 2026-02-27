import Foundation
import FirebaseFirestore

/// iOS equivalent of Android's ProUserRepository.
/// Searches collections `pro_users` and `ios` for any document whose
/// `emails` array field contains the signed-in user's email.
@MainActor
final class ProUserRepository: ObservableObject {
    static let shared = ProUserRepository()

    @Published var isProUser: Bool = false
    @Published var isPermanentLicense: Bool = false
    @Published var licenseMismatchVersion: String? = nil

    private let firestore: Firestore = {
        // Android uses a named Firestore database "login"
        return Firestore.firestore(database: "login")
    }()

    private init() {}

    /// Check if the given email has pro status in Firestore.
    /// Queries collections `pro_users` and `ios` for any document where
    /// the `emails` array contains the user's email.
    func checkProStatus(email: String?) async {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !email.isEmpty else {
            clearProStatus()
            return
        }

        // Security check: deny pro access on untrusted environments (matches Android)
        guard SecurityManager.shared.isEnvironmentTrusted() else {
            clearProStatus()
            return
        }

        // Search both collections for any document containing this email
        let collections = ["pro_users", "ios"]
        for collectionId in collections {
            do {
                let snap = try await firestore.collection(collectionId)
                    .whereField("emails", arrayContains: email)
                    .getDocuments()
                if !snap.documents.isEmpty {
                    isProUser = true
                    isPermanentLicense = true
                    licenseMismatchVersion = nil
                    return
                }
            } catch {
                print("ProUserRepository: Error querying \(collectionId): \(error)")
            }
        }

        clearProStatus()
    }

    func clearProStatus() {
        isProUser = false
        isPermanentLicense = false
        licenseMismatchVersion = nil
    }
}
