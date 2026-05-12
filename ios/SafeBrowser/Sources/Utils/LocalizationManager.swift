import Foundation

enum Localized {
    static let language = Bundle.main.preferredLocalizations.first ?? "en"

    static var isChinese: Bool {
        return language.hasPrefix("zh")
    }

    enum App {
        static var name: String {
            return NSLocalizedString("app.name", comment: "")
        }

        static func version(_ ver: String) -> String {
            return String(format: NSLocalizedString("app.version", comment: ""), ver)
        }
    }

    enum Nav {
        static var back: String { NSLocalizedString("nav.back", comment: "") }
        static var forward: String { NSLocalizedString("nav.forward", comment: "") }
        static var reload: String { NSLocalizedString("nav.reload", comment: "") }
        static var share: String { NSLocalizedString("nav.share", comment: "") }
    }

    enum Address {
        static var placeholder: String { NSLocalizedString("address.placeholder", comment: "") }
        static var searching: String { NSLocalizedString("address.searching", comment: "") }
    }

    enum Video {
        static var options: String { NSLocalizedString("video.options", comment: "") }
        static var fullscreen: String { NSLocalizedString("video.fullscreen", comment: "") }
        static var pip: String { NSLocalizedString("video.pip", comment: "") }
        static var download: String { NSLocalizedString("video.download", comment: "") }
        static var openPage: String { NSLocalizedString("video.openPage", comment: "") }
        static var noVideo: String { NSLocalizedString("video.noVideo", comment: "") }
        static var noVideoMessage: String { NSLocalizedString("video.noVideoMessage", comment: "") }
    }

    enum Download {
        static var manager: String { NSLocalizedString("download.manager", comment: "") }
        static var pageVideo: String { NSLocalizedString("download.pageVideo", comment: "") }
        static var currentMedia: String { NSLocalizedString("download.currentMedia", comment: "") }
        static var viewAll: String { NSLocalizedString("download.viewAll", comment: "") }
        static var starting: String { NSLocalizedString("download.starting", comment: "") }
        static var complete: String { NSLocalizedString("download.complete", comment: "") }
        static var failed: String { NSLocalizedString("download.failed", comment: "") }
        static var cancel: String { NSLocalizedString("download.cancel", comment: "") }
        static var noDownloads: String { NSLocalizedString("download.noDownloads", comment: "") }
        static var share: String { NSLocalizedString("download.share", comment: "") }
        static var viewInFiles: String { NSLocalizedString("download.viewInFiles", comment: "") }

        static func progress(_ percent: Int, downloaded: String, total: String) -> String {
            return String(format: NSLocalizedString("download.progress", comment: ""), percent, downloaded, total)
        }

        static func count(_ num: Int) -> String {
            return String(format: NSLocalizedString("download.count", comment: ""), num)
        }

        static func savedTo(_ path: String) -> String {
            return String(format: NSLocalizedString("download.savedTo", comment: ""), path)
        }
    }

    enum Reading {
        static var mode: String { NSLocalizedString("reading.mode", comment: "") }
        static var noArticle: String { NSLocalizedString("reading.noArticle", comment: "") }
        static var noArticleMessage: String { NSLocalizedString("reading.noArticleMessage", comment: "") }
        static var preparing: String { NSLocalizedString("reading.preparing", comment: "") }
        static var exit: String { NSLocalizedString("reading.exit", comment: "") }
        static var theme: String { NSLocalizedString("reading.theme", comment: "") }
        static var fontIncrease: String { NSLocalizedString("reading.fontIncrease", comment: "") }
        static var fontDecrease: String { NSLocalizedString("reading.fontDecrease", comment: "") }
        static var reset: String { NSLocalizedString("reading.reset", comment: "") }

        static func minRead(_ minutes: Int) -> String {
            return String(format: NSLocalizedString("reading.minRead", comment: ""), minutes)
        }

        static func byAuthor(_ author: String) -> String {
            return String(format: NSLocalizedString("reading.byAuthor", comment: ""), author)
        }
    }

    enum Theme {
        static var light: String { NSLocalizedString("theme.light", comment: "") }
        static var sepia: String { NSLocalizedString("theme.sepia", comment: "") }
        static var dark: String { NSLocalizedString("theme.dark", comment: "") }
    }

    enum VideoSites {
        static var title: String { NSLocalizedString("videoSites.title", comment: "") }
        static var choose: String { NSLocalizedString("videoSites.choose", comment: "") }
        static var youtube: String { NSLocalizedString("videoSites.youtube", comment: "") }
        static var vimeo: String { NSLocalizedString("videoSites.vimeo", comment: "") }
        static var dailymotion: String { NSLocalizedString("videoSites.dailymotion", comment: "") }
    }

    enum Error {
        static var invalidURL: String { NSLocalizedString("error.invalidURL", comment: "") }
        static var invalidURLMessage: String { NSLocalizedString("error.invalidURLMessage", comment: "") }
        static var generic: String { NSLocalizedString("error.generic", comment: "") }
        static var ok: String { NSLocalizedString("error.ok", comment: "") }
        static var cancel: String { NSLocalizedString("error.cancel", comment: "") }
    }

    enum Accessibility {
        static var backButton: String { NSLocalizedString("accessibility.backButton", comment: "") }
        static var forwardButton: String { NSLocalizedString("accessibility.forwardButton", comment: "") }
        static var reloadButton: String { NSLocalizedString("accessibility.reloadButton", comment: "") }
        static var videoButton: String { NSLocalizedString("accessibility.videoButton", comment: "") }
        static var pipButton: String { NSLocalizedString("accessibility.pipButton", comment: "") }
        static var downloadButton: String { NSLocalizedString("accessibility.downloadButton", comment: "") }
        static var readingModeButton: String { NSLocalizedString("accessibility.readingModeButton", comment: "") }
        static var shareButton: String { NSLocalizedString("accessibility.shareButton", comment: "") }
        static var addressBar: String { NSLocalizedString("accessibility.addressBar", comment: "") }
        static var webContent: String { NSLocalizedString("accessibility.webContent", comment: "") }
        static var downloading: String { NSLocalizedString("accessibility.downloading", comment: "") }
    }

    enum Share {
        static var title: String { NSLocalizedString("share.title", comment: "") }
        static var cancel: String { NSLocalizedString("share.cancel", comment: "") }
    }
}
