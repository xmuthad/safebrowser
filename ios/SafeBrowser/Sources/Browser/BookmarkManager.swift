import Foundation
import os.log

/// Represents a bookmark entry with unique identifier
struct BookmarkEntry: Codable, Identifiable {
    let id: UUID
    let url: URL
    let title: String
    let dateAdded: Date
    var favicon: Data?

    var displayTitle: String {
        return title.isEmpty ? url.host ?? url.absoluteString : title
    }

    init(url: URL, title: String, favicon: Data? = nil) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.dateAdded = Date()
        self.favicon = favicon
    }
}

/// Manages user bookmarks with persistent storage
/// Supports: adding, removing, searching, and organizing bookmarks
class BookmarkManager {
    static let shared = BookmarkManager()

    private let logger = Logger(subsystem: "com.safechrome.browser", category: "bookmark")
    private var bookmarks: [BookmarkEntry] = []
    private let bookmarksKey = "Bookmarks"

    private init() {
        loadBookmarks()
    }

    var allBookmarks: [BookmarkEntry] {
        return bookmarks.sorted { $0.dateAdded > $1.dateAdded }
    }

    var recentBookmarks: [BookmarkEntry] {
        return Array(bookmarks.sorted { $0.dateAdded > $1.dateAdded }.prefix(5))
    }

    func addBookmark(url: URL, title: String, favicon: Data? = nil) {
        guard !isBookmarked(url: url) else { return }

        let entry = BookmarkEntry(url: url, title: title, favicon: favicon)
        bookmarks.append(entry)
        saveBookmarks()
        logger.info("Bookmark added: \(title)")
    }

    func removeBookmark(url: URL) {
        bookmarks.removeAll { $0.url == url }
        saveBookmarks()
        logger.info("Bookmark removed")
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        saveBookmarks()
    }

    func isBookmarked(url: URL) -> Bool {
        return bookmarks.contains { $0.url == url }
    }

    func searchBookmarks(query: String) -> [BookmarkEntry] {
        let lowercasedQuery = query.lowercased()
        return bookmarks.filter {
            $0.url.absoluteString.lowercased().contains(lowercasedQuery) ||
            $0.title.lowercased().contains(lowercasedQuery)
        }
    }

    func clearAllBookmarks() {
        bookmarks.removeAll()
        saveBookmarks()
        logger.info("All bookmarks cleared")
    }

    private func saveBookmarks() {
        do {
            let data = try JSONEncoder().encode(bookmarks)
            UserDefaults.standard.set(data, forKey: bookmarksKey)
        } catch {
            logger.error("Failed to save bookmarks: \(error.localizedDescription)")
        }
    }

    private func loadBookmarks() {
        guard let data = UserDefaults.standard.data(forKey: bookmarksKey) else {
            logger.info("No bookmarks found")
            return
        }

        do {
            self.bookmarks = try JSONDecoder().decode([BookmarkEntry].self, from: data)
            logger.info("Loaded \(self.bookmarks.count) bookmarks")
        } catch {
            logger.error("Failed to load bookmarks: \(error.localizedDescription)")
            bookmarks = []
        }
    }
}
