import Foundation
import WebKit
import os.log

struct SecuritySettings {
    var forceHTTPS: Bool
    var blockAds: Bool
    var privateBrowsing: Bool
    var blockTrackers: Bool
    var blockMaliciousSites: Bool
    var clearOnExit: Bool
    var allowJavaScript: Bool

    static var defaultSettings: SecuritySettings {
        return SecuritySettings(
            forceHTTPS: true,
            blockAds: true,
            privateBrowsing: false,
            blockTrackers: true,
            blockMaliciousSites: true,
            clearOnExit: false,
            allowJavaScript: true
        )
    }
}

class SecurityPolicyManager {
    static let shared = SecurityPolicyManager()

    private let logger = Logger(subsystem: "com.safechrome.browser", category: "security")
    private var settings: SecuritySettings = .defaultSettings
    private var adBlockRules: Set<String> = []
    private var trackerBlockRules: Set<String> = []
    private var maliciousSiteList: Set<String> = []

    private init() {
        loadSettings()
        loadAdBlockList()
        loadTrackerBlockList()
        loadMaliciousSiteList()
    }

    func getSettings() -> SecuritySettings {
        return settings
    }

    func updateSettings(_ newSettings: SecuritySettings) {
        settings = newSettings
        saveSettings()
        logger.info("Security settings updated")
    }

    func togglePrivateBrowsing() {
        settings.privateBrowsing.toggle()
        saveSettings()
        logger.info("Private browsing: \(self.settings.privateBrowsing)")
    }

    func isPrivateBrowsing() -> Bool {
        return settings.privateBrowsing
    }

    func shouldForceHTTPS(for url: URL) -> Bool {
        guard settings.forceHTTPS else { return false }
        guard url.scheme == "http" else { return false }
        guard isHTTPSAvailable(for: url) else { return false }
        return true
    }

    func getHTTPSURL(for httpURL: URL) -> URL? {
        guard var components = URLComponents(url: httpURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.scheme = "https"
        return components.url
    }

    private func isHTTPSAvailable(for url: URL) -> Bool {
        guard let host = url.host else { return false }
        let httpsHost = "https://\(host)"
        let testURL = URL(string: httpsHost) ?? URL(string: "https://\(host)/")

        var request = URLRequest(url: testURL ?? httpURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5

        let semaphore = DispatchSemaphore(value: 0)
        var httpsAvailable = false

        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse {
                httpsAvailable = (200...299).contains(httpResponse.statusCode)
            }
            semaphore.signal()
        }.resume()

        _ = semaphore.wait(timeout: .now() + 5)
        return httpsAvailable
    }

    func shouldBlock(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        if settings.blockAds && shouldBlockAd(for: host) {
            logger.warning("Blocked ad: \(host)")
            return true
        }

        if settings.blockTrackers && shouldBlockTracker(for: host) {
            logger.warning("Blocked tracker: \(host)")
            return true
        }

        if settings.blockMaliciousSites && shouldBlockMaliciousSite(for: host) {
            logger.warning("Blocked malicious site: \(host)")
            return true
        }

        return false
    }

    private func shouldBlockAd(for host: String) -> Bool {
        for rule in adBlockRules {
            if host.contains(rule) || rule.contains(host) {
                return true
            }
        }
        return false
    }

    private func shouldBlockTracker(for host: String) -> Bool {
        for rule in trackerBlockRules {
            if host.contains(rule) || rule.contains(host) {
                return true
            }
        }
        return false
    }

    private func shouldBlockMaliciousSite(for host: String) -> Bool {
        for rule in maliciousSiteList {
            if host.contains(rule) || rule.contains(host) {
                return true
            }
        }
        return false
    }

    func getContentBlockerRules() -> String {
        var rules: [String] = []

        if settings.blockAds {
            rules.append(contentsOf: getAdBlockerRules())
        }

        if settings.blockTrackers {
            rules.append(contentsOf: getTrackerBlockerRules())
        }

        let jsonRules = rules.map { rule -> [String: Any] in
            return [
                "trigger": ["url-filter": ".*"],
                "action": ["type": "block"]
            ]
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonRules, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "[]"
    }

    private func getAdBlockerRules() -> [String] {
        return [
            "doubleclick.net",
            "googlesyndication.com",
            "googleadservices.com",
            "facebook.com/plugins",
            "adservice.google.com",
            "ads.yahoo.com",
            "advertising.com",
            "adnxs.com",
            "adsrvr.org",
            "adform.net",
            "criteo.com",
            "outbrain.com",
            "taboola.com",
            "moatads.com",
            "scorecardresearch.com"
        ]
    }

    private func getTrackerBlockerRules() -> [String] {
        return [
            "google-analytics.com",
            "googletagmanager.com",
            "facebook.net",
            "hotjar.com",
            "mixpanel.com",
            "amplitude.com",
            "segment.io",
            "optimizely.com",
            "quantserve.com",
            "newrelic.com",
            "bugsnag.com",
            "sentry.io",
            "fullstory.com",
            "mouseflow.com",
            "crazyegg.com"
        ]
    }

    private func loadAdBlockList() {
        adBlockRules = Set(getAdBlockerRules())
        logger.info("Loaded \(self.adBlockRules.count) ad block rules")
    }

    private func loadTrackerBlockList() {
        trackerBlockRules = Set(getTrackerBlockerRules())
        logger.info("Loaded \(self.trackerBlockRules.count) tracker block rules")
    }

    private func loadMaliciousSiteList() {
        maliciousSiteList = Set([
            "malware.com",
            "phishing-site.com",
            "suspicious-site.com"
        ])
        logger.info("Loaded \(self.maliciousSiteList.count) malicious site rules")
    }

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: "securitySettings"),
           let loadedSettings = try? JSONDecoder().decode(SecuritySettings.self, from: data) {
            settings = loadedSettings
        }
        logger.info("Loaded security settings")
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "securitySettings")
        }
    }

    func clearBrowsingData() {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.removeData(ofTypes: types, modifiedSince: Date.distantPast) { [weak self] in
            self?.logger.info("Browsing data cleared")
        }

        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    func getSecurityReport(for url: URL) -> SecurityReport {
        let report = SecurityReport(
            url: url,
            isHTTPS: url.scheme == "https",
            hasMixedContent: false,
            isBlocked: shouldBlock(url: url),
            isTracker: settings.blockTrackers && shouldBlockTracker(for: url.host ?? ""),
            isAd: settings.blockAds && shouldBlockAd(for: url.host ?? ""),
            isMalicious: settings.blockMaliciousSites && shouldBlockMaliciousSite(for: url.host ?? "")
        )
        return report
    }
}

struct SecurityReport {
    let url: URL
    let isHTTPS: Bool
    let hasMixedContent: Bool
    let isBlocked: Bool
    let isTracker: Bool
    let isAd: Bool
    let isMalicious: Bool

    var securityLevel: SecurityLevel {
        if isMalicious || isBlocked {
            return .dangerous
        } else if !isHTTPS {
            return .warning
        } else {
            return .secure
        }
    }

    enum SecurityLevel {
        case secure
        case warning
        case dangerous

        var description: String {
            switch self {
            case .secure: return "Secure"
            case .warning: return "Not Secure"
            case .dangerous: return "Dangerous"
            }
        }

        var iconName: String {
            switch self {
            case .secure: return "lock.shield.fill"
            case .warning: return "exclamationmark.shield.fill"
            case .dangerous: return "xmark.shield.fill"
            }
        }
    }
}

extension SecuritySettings: Codable {}
