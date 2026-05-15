import XCTest
@testable import SafeBrowser

// MARK: - HistoryManager Edge Cases

final class HistoryManagerEdgeCaseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        HistoryManager.shared.clearHistory()
    }

    override func tearDown() {
        HistoryManager.shared.clearHistory()
        super.tearDown()
    }

    func testEmptyHistorySearch() {
        let results = HistoryManager.shared.searchHistory(query: "anything")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchWithSpecialCharacters() {
        let url = URL(string: "https://example.com/path?query=test&special=<>\"'")!
        HistoryManager.shared.addEntry(url: url, title: "Special & Characters")

        let results1 = HistoryManager.shared.searchHistory(query: "special")
        XCTAssertEqual(results1.count, 1)

        let results2 = HistoryManager.shared.searchHistory(query: "query=test")
        XCTAssertEqual(results2.count, 1)
    }

    func testSearchCaseInsensitive() {
        HistoryManager.shared.addEntry(url: URL(string: "https://apple.com")!, title: "APPLE")

        let results = HistoryManager.shared.searchHistory(query: "apple")
        XCTAssertEqual(results.count, 1)
    }

    func testDeleteNonExistentEntry() {
        let url = URL(string: "https://example.com")!
        HistoryManager.shared.deleteEntry(url: url)
        XCTAssertTrue(HistoryManager.shared.getHistory().isEmpty)
    }

    func testHistoryLimitEnforcement() {
        for i in 0..<600 {
            HistoryManager.shared.addEntry(url: URL(string: "https://example\(i).com")!, title: "Page \(i)")
        }

        let history = HistoryManager.shared.getHistory()
        XCTAssertLessThanOrEqual(history.count, 500)
    }

    func testEmptyURLHandling() {
        let url = URL(string: "https://example.com")!
        HistoryManager.shared.addEntry(url: url, title: "")

        let history = HistoryManager.shared.getHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertFalse(history[0].displayTitle.isEmpty)
    }

    func testDateRangeFiltering() {
        HistoryManager.shared.addEntry(url: URL(string: "https://today.com")!, title: "Today")

        let today = Date()
        let todayHistory = HistoryManager.shared.getHistory(for: today)
        XCTAssertEqual(todayHistory.count, 1)

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let yesterdayHistory = HistoryManager.shared.getHistory(for: yesterday)
        XCTAssertEqual(yesterdayHistory.count, 0)
    }

    func testLargeTitleHandling() {
        let largeTitle = String(repeating: "A", count: 10000)
        let url = URL(string: "https://example.com")!
        HistoryManager.shared.addEntry(url: url, title: largeTitle)

        let history = HistoryManager.shared.getHistory()
        XCTAssertEqual(history.count, 1)
    }

    func testUnicodeTitleHandling() {
        let unicodeTitle = "测试中文 🎉 Emoji 😀 日本語"
        let url = URL(string: "https://example.com")!
        HistoryManager.shared.addEntry(url: url, title: unicodeTitle)

        let history = HistoryManager.shared.getHistory()
        XCTAssertEqual(history[0].title, unicodeTitle)
    }

    func testURLWithPortAndQuery() {
        let url = URL(string: "https://example.com:8080/path?query=value#anchor")!
        HistoryManager.shared.addEntry(url: url, title: "URL with Port")

        let history = HistoryManager.shared.getHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].url.port, 8080)
    }
}

// MARK: - BookmarkManager Edge Cases

final class BookmarkManagerEdgeCaseTests: XCTestCase {

    override func setUp() {
        super.setUp()
        BookmarkManager.shared.clearAllBookmarks()
    }

    override func tearDown() {
        BookmarkManager.shared.clearAllBookmarks()
        super.tearDown()
    }

    func testEmptyBookmarkSearch() {
        let results = BookmarkManager.shared.searchBookmarks(query: "anything")
        XCTAssertTrue(results.isEmpty)
    }

    func testBookmarkWithSpecialCharacters() {
        let url = URL(string: "https://example.com/search?q=special&<>\"'")!
        BookmarkManager.shared.addBookmark(url: url, title: "Special Test")

        XCTAssertTrue(BookmarkManager.shared.isBookmarked(url: url))
    }

    func testBookmarkCaseInsensitiveSearch() {
        BookmarkManager.shared.addBookmark(url: URL(string: "https://Google.com")!, title: "GOOGLE")

        let results = BookmarkManager.shared.searchBookmarks(query: "google")
        XCTAssertEqual(results.count, 1)
    }

    func testRemoveNonExistentBookmark() {
        let url = URL(string: "https://example.com")!
        BookmarkManager.shared.removeBookmark(url: url)
        XCTAssertFalse(BookmarkManager.shared.isBookmarked(url: url))
    }

    func testRemoveByIdNonExistent() {
        BookmarkManager.shared.removeBookmark(id: UUID())
        XCTAssertTrue(BookmarkManager.shared.allBookmarks.isEmpty)
    }

    func testMultipleSameURLTitles() {
        let url = URL(string: "https://example.com")!
        BookmarkManager.shared.addBookmark(url: url, title: "First")
        BookmarkManager.shared.addBookmark(url: url, title: "Second")
        BookmarkManager.shared.addBookmark(url: url, title: "Third")

        let bookmarks = BookmarkManager.shared.allBookmarks
        XCTAssertEqual(bookmarks.count, 1)
        XCTAssertEqual(bookmarks[0].title, "Third")
    }

    func testBookmarkWithUnicode() {
        let url = URL(string: "https://中文.com")!
        BookmarkManager.shared.addBookmark(url: url, title: "中文书签 🚀")

        XCTAssertTrue(BookmarkManager.shared.isBookmarked(url: url))
    }

    func testEmptyURLValidation() {
        BookmarkManager.shared.addBookmark(url: URL(string: "https://")!, title: "Test")
        XCTAssertFalse(BookmarkManager.shared.allBookmarks.isEmpty)
    }

    func testLargeURLBookmarking() {
        let longPath = String(repeating: "a", count: 500)
        let url = URL(string: "https://example.com/\(longPath)")!
        BookmarkManager.shared.addBookmark(url: url, title: "Long URL")

        XCTAssertTrue(BookmarkManager.shared.isBookmarked(url: url))
    }
}

// MARK: - SecurityPolicy Edge Cases

final class SecurityPolicyEdgeCaseTests: XCTestCase {

    func testMalformedURLHandling() {
        let malformedURLs = [
            "not a url",
            "ht://wrong",
            "",
            "   ",
            "javascript:alert(1)",
            "data:text/html,<script>alert(1)</script>"
        ]

        for urlString in malformedURLs {
            if let url = URL(string: urlString) {
                let isBlocked = SecurityPolicyManager.shared.shouldBlock(url: url)
                XCTAssertFalse(isBlocked, "Malformed URL should not be blocked: \(urlString)")
            }
        }
    }

    func testIPAddressURLs() {
        let ipURLs = [
            "http://127.0.0.1",
            "http://192.168.1.1",
            "http://10.0.0.1",
            "http://[::1]"
        ]

        for urlString in ipURLs {
            if let url = URL(string: urlString) {
                let httpsURL = SecurityPolicyManager.shared.getHTTPSURL(for: url)
                XCTAssertNotNil(httpsURL)
                XCTAssertEqual(httpsURL?.scheme, "https")
            }
        }
    }

    func testLocalhostURLs() {
        let url = URL(string: "http://localhost:3000")!
        let httpsURL = SecurityPolicyManager.shared.getHTTPSURL(for: url)
        XCTAssertNotNil(httpsURL)
    }

    func testURLWithSpecialSchemes() {
        let specialURLs = [
            "ftp://example.com",
            "file:///path/to/file",
            "tel:1234567890",
            "mailto:test@example.com",
            "sms:1234567890"
        ]

        for urlString in specialURLs {
            if let url = URL(string: urlString) {
                let httpsURL = SecurityPolicyManager.shared.getHTTPSURL(for: url)
                XCTAssertNil(httpsURL, "Special scheme URL should not convert: \(urlString)")
            }
        }
    }

    func testAdBlockListBoundaries() {
        let settings = SecurityPolicyManager.shared.getSettings()
        XCTAssertTrue(settings.blockAds)
        XCTAssertTrue(settings.blockTrackers)
        XCTAssertTrue(settings.blockMaliciousSites)
    }

    func testEmptyHostURL() {
        let url = URL(string: "https://")!
        let httpsURL = SecurityPolicyManager.shared.getHTTPSURL(for: url)
        XCTAssertNil(httpsURL)
    }

    func testUnicodeDomainURL() {
        let url = URL(string: "https://münchen.de")!
        let httpsURL = SecurityPolicyManager.shared.getHTTPSURL(for: url)
        XCTAssertNotNil(httpsURL)
    }
}

// MARK: - VideoDownloadManager Edge Cases

final class VideoDownloadManagerEdgeCaseTests: XCTestCase {

    func testSanitizeFileNameWithAllSpecialCharacters() {
        let manager = VideoDownloadManager.shared

        let testCases: [(String, Bool)] = [
            ("normal.mp4", true),
            ("file with spaces.mp4", true),
            ("file<with>special*.mp4", true),
            ("file|with|pipes.mp4", true),
            ("file\"with\"quotes.mp4", true),
            ("file/with/slashes.mp4", false),
            ("file\\with\\backslashes.mp4", false),
            ("", false),
            ("noextension", false),
            ("video.mov", true),
            ("audio.mp3", true),
            ("unknown.xyz", false)
        ]

        for (input, shouldHaveExtension) in testCases {
            let sanitized = manager.sanitizeFileName(input)

            if !input.isEmpty && input != "noextension" && input != "unknown.xyz" {
                XCTAssertFalse(sanitized.contains("/"), "Should not contain /: \(input)")
                XCTAssertFalse(sanitized.contains("\\"), "Should not contain \\: \(input)")
                XCTAssertFalse(sanitized.contains("<"), "Should not contain <: \(input)")
                XCTAssertFalse(sanitized.contains(">"), "Should not contain >: \(input)")
            }

            if shouldHaveExtension {
                XCTAssertTrue(sanitized.contains("."), "Should have extension: \(input)")
            }
        }
    }

    func testSanitizeEmptyFileName() {
        let manager = VideoDownloadManager.shared
        let sanitized = manager.sanitizeFileName("")
        XCTAssertFalse(sanitized.isEmpty)
        XCTAssertTrue(sanitized.hasPrefix("video_"))
    }

    func testSanitizeOnlySpecialCharacters() {
        let manager = VideoDownloadManager.shared
        let sanitized = manager.sanitizeFileName("///<<<>>>|||\"\"")
        XCTAssertFalse(sanitized.isEmpty)
        XCTAssertFalse(sanitized.contains("/"))
    }

    func testSanitizeVeryLongFileName() {
        let manager = VideoDownloadManager.shared
        let longName = String(repeating: "a", count: 500) + ".mp4"
        let sanitized = manager.sanitizeFileName(longName)
        XCTAssertFalse(sanitized.isEmpty)
    }

    func testSanitizeUnicodeFileName() {
        let manager = VideoDownloadManager.shared
        let sanitized = manager.sanitizeFileName("视频文件.mp4")
        XCTAssertEqual(sanitized, "视频文件.mp4")
    }

    func testSanitizeMixedContent() {
        let manager = VideoDownloadManager.shared
        let sanitized = manager.sanitizeFileName("My Video <Test> (1).mp4")
        XCTAssertFalse(sanitized.contains("<"))
        XCTAssertFalse(sanitized.contains(">"))
    }
}

// MARK: - ReadingModeManager Edge Cases

final class ReadingModeManagerEdgeCaseTests: XCTestCase {

    func testExtractFromEmptyHTML() {
        let html = ""
        let url = URL(string: "https://example.com")!

        let article = ReadingModeManager.shared.extractArticle(from: html, url: url)

        XCTAssertNil(article)
    }

    func testExtractFromNoContentHTML() {
        let html = "<html><head><title>Empty</title></head><body></body></html>"
        let url = URL(string: "https://example.com")!

        let article = ReadingModeManager.shared.extractArticle(from: html, url: url)

        XCTAssertNil(article)
    }

    func testExtractWithScriptAndStyleTags() {
        let html = """
        <html>
        <head><title>Test</title></head>
        <body>
            <script>alert('test');</script>
            <style>body { color: red; }</style>
            <article><p>Content here</p></article>
        </body>
        </html>
        """
        let url = URL(string: "https://example.com")!

        let article = ReadingModeManager.shared.extractArticle(from: html, url: url)

        XCTAssertNotNil(article)
        XCTAssertEqual(article?.title, "Test")
    }

    func testExtractWithUnicodeContent() {
        let html = """
        <html>
        <head><title>中文测试 🎉</title></head>
        <body>
            <article>
                <p>这是一段中文内容</p>
                <p>Emoji test: 🚀 ⭐ 💻</p>
                <p>日本語テスト</p>
            </article>
        </body>
        </html>
        """
        let url = URL(string: "https://example.com")!

        let article = ReadingModeManager.shared.extractArticle(from: html, url: url)

        XCTAssertNotNil(article)
        XCTAssertTrue(article?.content.contains("中文") ?? false)
    }

    func testHTMLGenerationWithEmptyContent() {
        let article = ArticleContent(
            title: "",
            author: nil,
            publishDate: nil,
            content: "",
            url: URL(string: "https://example.com")!,
            imageURL: nil,
            articleImages: [],
            estimatedReadTime: 0,
            videoURL: nil
        )

        let html = ReadingModeManager.shared.generateHTML(for: article)

        XCTAssertTrue(html.contains("example.com"))
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
    }

    func testHTMLGenerationWithSpecialCharacters() {
        let article = ArticleContent(
            title: "Test <script>alert('xss')</script>",
            author: nil,
            publishDate: nil,
            content: "Content with <b>HTML</b> & \"quotes\" & 'apostrophes'",
            url: URL(string: "https://example.com")!,
            imageURL: nil,
            articleImages: [],
            estimatedReadTime: 1,
            videoURL: nil
        )

        let html = ReadingModeManager.shared.generateHTML(for: article)

        XCTAssertFalse(html.contains("<script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }
}

// MARK: - LocalizationManager Tests

final class LocalizationManagerTests: XCTestCase {

    func testAllAccessibilityStringsExist() {
        let _ = Localized.Accessibility.backButton
        let _ = Localized.Accessibility.forwardButton
        let _ = Localized.Accessibility.reloadButton
        let _ = Localized.Accessibility.homeButton
        let _ = Localized.Accessibility.moreButton
    }

    func testAllMenuStringsExist() {
        let _ = Localized.Menu.download
        let _ = Localized.Menu.history
        let _ = Localized.Menu.bookmarks
        let _ = Localized.Menu.share
        let _ = Localized.Menu.findInPage
        let _ = Localized.Menu.desktopSite
    }

    func testAllErrorStringsExist() {
        let _ = Localized.Error.invalidURL
        let _ = Localized.Error.blocked
        let _ = Localized.Error.cancel
    }

    func testAllHistoryStringsExist() {
        let _ = Localized.History.title
        let _ = Localized.History.empty
        let _ = Localized.History.clear
        let _ = Localized.History.today
        let _ = Localized.History.yesterday
        let _ = Localized.History.thisWeek
        let _ = Localized.History.earlier
    }

    func testAllBookmarkStringsExist() {
        let _ = Localized.Bookmark.title
        let _ = Localized.Bookmark.empty
        let _ = Localized.Bookmark.added
        let _ = Localized.Bookmark.removed
    }
}

// MARK: - URL Processing Tests

final class URLProcessingTests: XCTestCase {

    func testURLNormalization() {
        let testCases: [(String, String)] = [
            ("https://example.com", "https://example.com"),
            ("http://example.com", "http://example.com"),
            ("example.com", "https://example.com"),
            ("  example.com  ", "https://example.com"),
            ("https://www.example.com", "https://www.example.com")
        ]

        for (input, expected) in testCases {
            var processed = input.trimmingCharacters(in: .whitespacesAndNewlines)

            if !processed.contains("://") {
                if processed.contains(".") && !processed.contains(" ") {
                    processed = "https://\(processed)"
                }
            }

            XCTAssertEqual(processed, expected, "Input: \(input)")
        }
    }

    func testSearchQueryGeneration() {
        let query = "hello world"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let searchURL = "https://www.google.com/search?q=\(encoded)"

        XCTAssertTrue(searchURL.contains("hello%20world"))
        XCTAssertTrue(searchURL.contains("google.com/search"))
    }

    func testURLPathPreservation() {
        let url = URL(string: "https://example.com/path/to/page?query=value")!
        XCTAssertEqual(url.path, "/path/to/page")
        XCTAssertEqual(url.query, "query=value")
    }

    func testURLExtraction() {
        let testURLs = [
            "https://example.com/video.mp4",
            "https://example.com/image.jpg",
            "https://example.com/document.pdf",
            "https://example.com/audio.mp3"
        ]

        for urlString in testURLs {
            let url = URL(string: urlString)!
            let lastPathComponent = url.lastPathComponent
            XCTAssertFalse(lastPathComponent.isEmpty)
        }
    }
}
