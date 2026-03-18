import Foundation

@MainActor
final class AppUpdateChecker: ObservableObject {
    static let shared = AppUpdateChecker()

    @Published private(set) var availableVersion: String?
    @Published private(set) var checkFailed = false

    private let repo = "tqmane/film_sims"
    private var lastCheckDate: Date?
    private static let checkInterval: TimeInterval = 60 * 60 * 6 // 6 hours

    var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var hasUpdate: Bool {
        guard let available = availableVersion else { return false }
        return compare(available, isNewerThan: currentVersion)
    }

    func checkIfNeeded() {
        if let last = lastCheckDate, Date().timeIntervalSince(last) < Self.checkInterval {
            return
        }
        Task { await check() }
    }

    func check() async {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            lastCheckDate = Date()
            let tag = release.tag_name.hasPrefix("v")
                ? String(release.tag_name.dropFirst())
                : release.tag_name
            availableVersion = tag
            checkFailed = false
        } catch {
            checkFailed = true
        }
    }

    private func compare(_ a: String, isNewerThan b: String) -> Bool {
        let normalize: (String) -> String = { v in
            v.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        }
        let partsA = normalize(a).split(separator: ".").compactMap { Int($0) }
        let partsB = normalize(b).split(separator: ".").compactMap { Int($0) }
        let count = max(partsA.count, partsB.count)
        for i in 0..<count {
            let va = i < partsA.count ? partsA[i] : 0
            let vb = i < partsB.count ? partsB[i] : 0
            if va > vb { return true }
            if va < vb { return false }
        }
        return false
    }

    private struct GitHubRelease: Decodable {
        let tag_name: String
    }
}
