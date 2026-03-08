import Foundation
import SwiftUI
import FilmSimsShared

struct IncomingImageRequest: Identifiable, Equatable, Sendable {
    enum Source: Equatable, Sendable {
        case pasteboard(name: String)
        case file(URL)

        var signature: String {
            switch self {
            case .pasteboard(let name):
                return "pasteboard:\(name)"
            case .file(let url):
                return "file:\(url.absoluteString)"
            }
        }
    }

    let id: UUID
    let source: Source

    init(source: Source) {
        id = UUID()
        self.source = source
    }
}

@MainActor
final class IncomingImageCoordinator: ObservableObject {
    static let shared = IncomingImageCoordinator()

    @Published private(set) var pendingRequest: IncomingImageRequest?

    private init() {}

    @discardableResult
    func handle(url: URL) -> Bool {
        if url.isFileURL {
            enqueue(.file(url))
            return true
        }

        if let request = SharedImageImport.parse(url: url) {
            enqueue(.pasteboard(name: request.pasteboardName))
            return true
        }

        return false
    }

    func consume(_ request: IncomingImageRequest) {
        guard pendingRequest?.id == request.id else { return }
        pendingRequest = nil
    }

    private func enqueue(_ source: IncomingImageRequest.Source) {
        if pendingRequest?.source.signature == source.signature {
            return
        }
        pendingRequest = IncomingImageRequest(source: source)
    }
}
