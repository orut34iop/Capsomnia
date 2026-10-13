import Foundation

/// Release downloads belong to this fork, including redirects through GitHub's asset CDN.
final class ForkToolsSource: NSObject, URLSessionTaskDelegate {
    static let repository = "orut34iop/Capsomnia"
    static let packageURL = URL(string: "https://github.com/\(repository)/releases/latest/download/Capsomnia-Tools.pkg")!

    static func allowsReleaseURL(_ url: URL) -> Bool {
        url.scheme == "https" && url.host == "github.com"
            && url.user == nil && url.password == nil && url.port == nil
            && url.path.hasPrefix("/\(repository)/releases/")
            && url.lastPathComponent == "Capsomnia-Tools.pkg"
    }

    static func allowsDownloadURL(_ url: URL) -> Bool {
        allowsReleaseURL(url) || (
            url.scheme == "https" && url.host == "release-assets.githubusercontent.com"
                && url.user == nil && url.password == nil && url.port == nil
        )
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.map(Self.allowsDownloadURL) == true ? request : nil)
    }
}
