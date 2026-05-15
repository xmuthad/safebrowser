import Foundation
import os.log

/// Represents a single browsing history entry
struct HistoryEntry: Codable {
    let url: URL
    let title: String
    let timestamp: Date
    let favicon: Data?

    var displayTitle: String {
        return title.isEmpty ? url.host ?? url.absoluteString : title
    }
}

/// Manages browser browsing history with persistence
/// Supports: adding entries, searching, deleting, and clearing history
class HistoryManager {
    static let shared = HistoryManager()

    private let logger = Logger(subsystem: "com.safechrome.browser", category: "history")
    private let maxHistoryCount = 500
    private var history: [HistoryEntry] = []

    private let historyKey = "BrowsingHistory"

    private init() {
        loadHistory()
    }

    func addEntry(url: URL, title: String, favicon: Data? = nil) {
        let entry = HistoryEntry(url: url, title: title, timestamp: Date(), favicon: favicon)

        if let existingIndex = history.firstIndex(where: { $0.url == url }) {
            history.remove(at: existingIndex)
        }

        history.insert(entry, at: 0)

        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }

        saveHistory()
        logger.info("Added history entry: \(title)")
    }

    func getHistory() -> [HistoryEntry] {
        return history
    }

    func getHistory(limit: Int) -> [HistoryEntry] {
        return Array(history.prefix(limit))
    }

    func getHistory(for date: Date) -> [HistoryEntry] {
        let calendar = Calendar.current
        return history.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    func searchHistory(query: String) -> [HistoryEntry] {
        let lowercasedQuery = query.lowercased()
        return history.filter {
            $0.url.absoluteString.lowercased().contains(lowercasedQuery) ||
            $0.title.lowercased().contains(lowercasedQuery)
        }
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
        logger.info("History cleared")
    }

    func deleteEntry(at index: Int) {
        guard index >= 0 && index < history.count else { return }
        history.remove(at: index)
        saveHistory()
    }

    func deleteEntry(url: URL) {
        history.removeAll { $0.url == url }
        saveHistory()
    }

    func deleteHistory(from startDate: Date, to endDate: Date) {
        history.removeAll { $0.timestamp >= startDate && $0.timestamp <= endDate }
        saveHistory()
    }

    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: historyKey)
        } catch {
            logger.error("Failed to save history: \(error.localizedDescription)")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else {
            logger.info("No history found")
            return
        }

        do {
            self.history = try JSONDecoder().decode([HistoryEntry].self, from: data)
            logger.info("Loaded \(self.history.count) history entries")
        } catch {
            logger.error("Failed to load history: \(error.localizedDescription)")
            history = []
        }
    }
}
