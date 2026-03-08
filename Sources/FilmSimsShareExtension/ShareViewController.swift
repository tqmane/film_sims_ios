import UIKit
import UniformTypeIdentifiers
import FilmSimsShared

final class ShareViewController: UIViewController {
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private var didStartProcessing = false

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.startAnimating()
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didStartProcessing else { return }
        didStartProcessing = true

        Task {
            await processShare()
        }
    }

    @MainActor
    private func processShare() async {
        do {
            guard let provider = firstImageProvider() else {
                throw ShareError.missingImage
            }

            let imageData = try await loadImageData(from: provider)
            let pasteboardName = UIPasteboard.Name("com.tqmane.filmsim.share.\(UUID().uuidString)")
            guard let pasteboard = UIPasteboard(name: pasteboardName, create: true) else {
                throw ShareError.failedToCreatePasteboard
            }

            pasteboard.setItems(
                [[UTType.data.identifier: imageData]],
                options: [
                    .expirationDate: Date().addingTimeInterval(300),
                    .localOnly: true,
                ]
            )

            guard let url = SharedImageImport.makeURL(for: .init(pasteboardName: pasteboardName.rawValue)) else {
                throw ShareError.failedToCreateLaunchURL
            }

            guard let extensionContext else {
                throw ShareError.missingExtensionContext
            }

            let success = await extensionContext.open(url)
            if success {
                extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
            } else {
                extensionContext.cancelRequest(withError: ShareError.failedToOpenHostApp.nsError)
            }
        } catch let error as ShareError {
            extensionContext?.cancelRequest(withError: error.nsError)
        } catch {
            extensionContext?.cancelRequest(withError: ShareError.failedToLoadImage.nsError)
        }
    }

    private func firstImageProvider() -> NSItemProvider? {
        let inputItems = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []

        for item in inputItems {
            guard let attachments = item.attachments else { continue }
            if let provider = attachments.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) {
                return provider
            }
        }

        return nil
    }

    @MainActor
    private func loadImageData(from provider: NSItemProvider) async throws -> Data {
        if let fileData = try? await provider.loadImageFileData() {
            return fileData
        }

        if let dataRepresentation = try? await provider.loadImageDataRepresentation() {
            return dataRepresentation
        }

        if let image = try? await provider.loadImageObject(),
           let imageData = image.jpegData(compressionQuality: 0.98) {
            return imageData
        }

        throw ShareError.failedToLoadImage
    }
}

private enum ShareError: Int, Error {
    case missingImage = 1
    case failedToLoadImage = 2
    case failedToCreatePasteboard = 3
    case failedToCreateLaunchURL = 4
    case missingExtensionContext = 5
    case failedToOpenHostApp = 6

    var nsError: NSError {
        NSError(domain: "com.tqmane.filmsim.share-extension", code: rawValue)
    }
}

private extension NSItemProvider {
    @MainActor
    func loadImageFileData() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }

                do {
                    continuation.resume(returning: try Data(contentsOf: url))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @MainActor
    func loadImageDataRepresentation() async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    @MainActor
    func loadImageObject() async throws -> UIImage? {
        try await withCheckedThrowingContinuation { continuation in
            loadObject(ofClass: UIImage.self) { object, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: object as? UIImage)
            }
        }
    }
}
