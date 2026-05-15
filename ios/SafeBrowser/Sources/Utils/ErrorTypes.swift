import Foundation

enum BrowserError: LocalizedError {
    case invalidURL
    case invalidURLMessage
    case networkError(String)
    case downloadFailed(String)
    case fileOperationFailed(String)
    case securityBlocked
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("error.invalidURL", comment: "")
        case .invalidURLMessage:
            return NSLocalizedString("error.invalidURLMessage", comment: "")
        case .networkError(let message):
            return message
        case .downloadFailed(let message):
            return message
        case .fileOperationFailed(let message):
            return message
        case .securityBlocked:
            return NSLocalizedString("error.blocked", comment: "")
        case .unknownError:
            return NSLocalizedString("error.generic", comment: "")
        }
    }
}

enum HistoryError: LocalizedError {
    case saveFailed
    case loadFailed
    case entryNotFound

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save history"
        case .loadFailed:
            return "Failed to load history"
        case .entryNotFound:
            return "History entry not found"
        }
    }
}

enum BookmarkError: LocalizedError {
    case duplicateBookmark
    case saveFailed
    case loadFailed
    case entryNotFound

    var errorDescription: String? {
        switch self {
        case .duplicateBookmark:
            return "Bookmark already exists"
        case .saveFailed:
            return "Failed to save bookmark"
        case .loadFailed:
            return "Failed to load bookmarks"
        case .entryNotFound:
            return "Bookmark not found"
        }
    }
}
