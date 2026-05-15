import XCTest
@testable import SafeBrowser

final class HistoryManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        HistoryManager.shared.clearHistory()
    }

    override func tearDown() {
        HistoryManager.shared.clearHistory()
        super.tearDown()
    }

    func testAddEntry() {
        let url = URL(string: "https://example.com")!
        HistoryManager.shared.addEntry(url: url, title: "Example")

        let history = HistoryManager.shared.getHistory()
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].url, url)
        XCTAssertEqual(history[0].title, "Example")
    }

    func testDuplicateEntryMovesToTop() {
        let url = URL(string: "https://example.com")!
        let url2 = URL(string: "https://example2.com")!

        HistoryManager.shared.addEntry(url: url, title: "First")
        HistoryManager.shared.addEntry(url: url2, title: "Second")
        HistoryManager.shared.addEntry(url: url, title: "Updated")

        let history = HistoryManager.shared.getHistory()
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history[0].url, url)
        XCTAssertEqual(history[0].title, "Updated")
    }

    func testSearchHistory() {
        HistoryManager.shared.addEntry(url: URL(string: "https://apple.com")!, title: "Apple")
        HistoryManager.shared.addEntry(url: URL(string: "https://google.com")!, title: "Google")

        let results = HistoryManager.shared.searchHistory(query: "apple")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].title, "Apple")
    }

    func testDeleteEntry() {
        let url = URL(string: "https://example.com")!
        HistoryManager.shared.addEntry(url: url, title: "Example")

        HistoryManager.shared.deleteEntry(url: url)
        XCTAssertTrue(HistoryManager.shared.getHistory().isEmpty)
    }

    func testClearHistory() {
        HistoryManager.shared.addEntry(url: URL(string: "https://example1.com")!, title: "Test1")
        HistoryManager.shared.addEntry(url: URL(string: "https://example2.com")!, title: "Test2")

        HistoryManager.shared.clearHistory()
        XCTAssertTrue(HistoryManager.shared.getHistory().isEmpty)
    }
}

final class BookmarkManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        BookmarkManager.shared.clearAllBookmarks()
    }

    override func tearDown() {
        BookmarkManager.shared.clearAllBookmarks()
        super.tearDown()
    }

    func testAddBookmark() {
        let url = URL(string: "https://example.com")!
        BookmarkManager.shared.addBookmark(url: url, title: "Example")

        XCTAssertTrue(BookmarkManager.shared.isBookmarked(url: url))
    }

    func testRemoveBookmark() {
        let url = URL(string: "https://example.com")!
        BookmarkManager.shared.addBookmark(url: url, title: "Example")
        BookmarkManager.shared.removeBookmark(url: url)

        XCTAssertFalse(BookmarkManager.shared.isBookmarked(url: url))
    }

    func testDuplicateBookmarkIgnored() {
        let url = URL(string: "https://example.com")!
        BookmarkManager.shared.addBookmark(url: url, title: "First")
        BookmarkManager.shared.addBookmark(url: url, title: "Second")

        let bookmarks = BookmarkManager.shared.allBookmarks
        XCTAssertEqual(bookmarks.count, 1)
    }

    func testSearchBookmarks() {
        BookmarkManager.shared.addBookmark(url: URL(string: "https://apple.com")!, title: "Apple")
        BookmarkManager.shared.addBookmark(url: URL(string: "https://banana.com")!, title: "Banana")

        let results = BookmarkManager.shared.searchBookmarks(query: "apple")
        XCTAssertEqual(results.count, 1)
    }
}

final class SecurityPolicyManagerTests: XCTestCase {

    func testHTTPSConversion() {
        let httpURL = URL(string: "http://example.com")!
        let httpsURL = SecurityPolicyManager.shared.getHTTPSURL(for: httpURL)

        XCTAssertEqual(httpsURL?.scheme, "https")
        XCTAssertEqual(httpsURL?.host, "example.com")
    }

    func testNonHTTPURLReturnsNil() {
        let url = URL(string: "file:///path/to/file")!
        let httpsURL = SecurityPolicyManager.shared.getHTTPSURL(for: url)

        XCTAssertNil(httpsURL)
    }

    func testShouldBlockKnownTracker() {
        let trackerURL = URL(string: "https://doubleclick.net")!
        let isBlocked = SecurityPolicyManager.shared.shouldBlock(url: trackerURL)

        XCTAssertTrue(isBlocked)
    }

    func testShouldNotBlockNormalSite() {
        let normalURL = URL(string: "https://example.com")!
        let isBlocked = SecurityPolicyManager.shared.shouldBlock(url: normalURL)

        XCTAssertFalse(isBlocked)
    }
}

final class VideoDownloadManagerTests: XCTestCase {

    func testSanitizeFileName() {
        let manager = VideoDownloadManager.shared

        let sanitized1 = manager.sanitizeFileName("normal_file.mp4")
        XCTAssertEqual(sanitized1, "normal_file.mp4")

        let sanitized2 = manager.sanitizeFileName("file with spaces.mp4")
        XCTAssertFalse(sanitized2.contains(" "))

        let sanitized3 = manager.sanitizeFileName("")
        XCTAssertFalse(sanitized3.isEmpty)
    }
}
