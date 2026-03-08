import Foundation

public enum SharedImageImport {
    public static let urlScheme = "filmsims"

    private static let urlHost = "share-image"
    private static let pasteboardQueryItem = "pasteboard"

    public struct Request: Equatable, Sendable {
        public let pasteboardName: String

        public init(pasteboardName: String) {
            self.pasteboardName = pasteboardName
        }
    }

    public static func makeURL(for request: Request) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = urlHost
        components.queryItems = [
            URLQueryItem(name: pasteboardQueryItem, value: request.pasteboardName)
        ]
        return components.url
    }

    public static func parse(url: URL) -> Request? {
        guard url.scheme?.caseInsensitiveCompare(urlScheme) == .orderedSame,
              url.host?.caseInsensitiveCompare(urlHost) == .orderedSame,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let pasteboardName = components.queryItems?.first(where: { $0.name == pasteboardQueryItem })?.value,
              !pasteboardName.isEmpty else {
            return nil
        }

        return Request(pasteboardName: pasteboardName)
    }
}
