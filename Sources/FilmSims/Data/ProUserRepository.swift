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

        let currentVersion = (
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var matchedCurrentVersion = false
        var matchedPermanentLicense = false
        var mismatchedVersion: String? = nil

        // Search both collections for any document containing this email
        let collections = ["pro_users", "ios"]
        for collectionId in collections {
            do {
                let snap = try await firestore.collection(collectionId)
                    .whereField("emails", arrayContains: email)
                    .getDocuments()
                for document in snap.documents {
                    let documentID = document.documentID
                    if documentID == "ID_list" {
                        matchedCurrentVersion = true
                        matchedPermanentLicense = true
                        mismatchedVersion = nil
                        break
                    }

                    if documentID == currentVersion {
                        matchedCurrentVersion = true
                        mismatchedVersion = nil
                    } else if !matchedCurrentVersion && mismatchedVersion == nil {
                        mismatchedVersion = documentID
                    }
                }

                if matchedPermanentLicense {
                    break
                }
            } catch {
                print("ProUserRepository: Error querying \(collectionId): \(error)")
            }
        }

        isProUser = matchedCurrentVersion
        isPermanentLicense = matchedPermanentLicense
        licenseMismatchVersion = matchedCurrentVersion ? nil : mismatchedVersion
        AnalyticsManager.updateProStatus(isProUser: isProUser)
    }

    func clearProStatus() {
        isProUser = false
        isPermanentLicense = false
        licenseMismatchVersion = nil
        AnalyticsManager.updateProStatus(isProUser: false)
    }
}
