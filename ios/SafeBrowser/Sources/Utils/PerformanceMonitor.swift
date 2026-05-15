import Foundation
import WebKit
import os.log

class PerformanceMonitor {
    static let shared = PerformanceMonitor()

    private let logger = Logger(subsystem: "com.safechrome.browser", category: "performance")

    private var pageLoadTimes: [TimeInterval] = []
    private var memoryUsage: Int = 0
    private var networkRequests: Int = 0
    private var periodicTimer: Timer?

    private init() {
        setupMemoryWarningObserver()
        startPeriodicMonitoring()
    }

    deinit {
        periodicTimer?.invalidate()
    }

    func recordPageLoadTime(_ time: TimeInterval, url: URL) {
        pageLoadTimes.append(time)
        if pageLoadTimes.count > 100 {
            pageLoadTimes.removeFirst()
        }

        logger.info("Page loaded in \(time * 1000)ms: \(url.host ?? "unknown")")
    }

    func getAveragePageLoadTime() -> TimeInterval {
        guard !pageLoadTimes.isEmpty else { return 0 }
        return pageLoadTimes.reduce(0, +) / Double(pageLoadTimes.count)
    }

    func getPageLoadStatistics() -> PageLoadStatistics {
        guard !pageLoadTimes.isEmpty else {
            return PageLoadStatistics(
                average: 0,
                min: 0,
                max: 0,
                median: 0,
                count: 0
            )
        }

        let sorted = pageLoadTimes.sorted()
        let count = Double(pageLoadTimes.count)
        let medianIndex = Int(count / 2)

        return PageLoadStatistics(
            average: getAveragePageLoadTime(),
            min: sorted.first ?? 0,
            max: sorted.last ?? 0,
            median: sorted[medianIndex],
            count: pageLoadTimes.count
        )
    }

    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        logger.warning("Received memory warning - clearing caches")
        clearCaches()
        URLCache.shared.removeAllCachedResponses()
    }

    private func startPeriodicMonitoring() {
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.performPeriodicCleanup()
        }
    }

    private func performPeriodicCleanup() {
        let memoryUsage = getCurrentMemoryUsage()
        logger.debug("Current memory usage: \(memoryUsage / 1024 / 1024) MB")

        if memoryUsage > 200 * 1024 * 1024 {
            logger.warning("High memory usage detected - clearing caches")
            clearCaches()
        }
    }

    func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Int(info.resident_size)
        }

        return 0
    }

    func clearCaches() {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: Date.distantPast
        ) { [weak self] in
            self?.logger.info("Caches cleared successfully")
        }
    }

    func optimizeWebViewConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()

        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true

        config.websiteDataStore = .default()

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = false
        config.preferences = preferences

        let webpagePrefs = WKWebpagePreferences()
        webpagePrefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = webpagePrefs

        return config
    }

    func createOptimizedURLRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30
        return request
    }

    func getPerformanceReport() -> PerformanceReport {
        let memoryUsage = getCurrentMemoryUsage()
        let stats = getPageLoadStatistics()

        return PerformanceReport(
            memoryUsage: memoryUsage,
            memoryUsageMB: Double(memoryUsage) / 1024 / 1024,
            averagePageLoadTime: stats.average,
            pageLoadCount: stats.count,
            isCacheEnabled: true,
            isOptimized: memoryUsage < 300 * 1024 * 1024
        )
    }

    func resetStatistics() {
        pageLoadTimes.removeAll()
        networkRequests = 0
        logger.info("Performance statistics reset")
    }
}

struct PageLoadStatistics {
    let average: TimeInterval
    let min: TimeInterval
    let max: TimeInterval
    let median: TimeInterval
    let count: Int

    var averageMs: Double {
        return average * 1000
    }
}

struct PerformanceReport {
    let memoryUsage: Int
    let memoryUsageMB: Double
    let averagePageLoadTime: TimeInterval
    let pageLoadCount: Int
    let isCacheEnabled: Bool
    let isOptimized: Bool

    var averagePageLoadTimeMs: Double {
        return averagePageLoadTime * 1000
    }
}

class WebViewPerformanceOptimizer {
    private weak var webView: WKWebView?
    private var loadStartTime: Date?

    init(webView: WKWebView) {
        self.webView = webView
    }

    func startMeasurement() {
        loadStartTime = Date()
    }

    func endMeasurement() {
        guard let startTime = loadStartTime else { return }
        let loadTime = Date().timeIntervalSince(startTime)

        if let url = webView?.url {
            PerformanceMonitor.shared.recordPageLoadTime(loadTime, url: url)
        }

        loadStartTime = nil
    }

    func preloadURL(_ url: URL) {
        let configuration = PerformanceMonitor.shared.optimizeWebViewConfiguration()
        let preloadWebView = WKWebView(frame: .zero, configuration: configuration)
        preloadWebView.load(URLRequest(url: url))
    }
}
