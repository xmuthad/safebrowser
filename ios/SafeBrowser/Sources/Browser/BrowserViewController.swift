import UIKit
import WebKit
import AVKit
import MediaPlayer
import os.log

extension Notification.Name {
    static let downloadProgressUpdated = Notification.Name("downloadProgressUpdated")
    static let downloadCompleted = Notification.Name("downloadCompleted")
}

private enum LayoutTag {
    static let toolBar = 100
    static let urlTextField = 101
    static let downloadOverlay = 200
}

private enum LayoutConstant {
    static let toolbarHeight: CGFloat = 44
    static let urlFieldHeight: CGFloat = 44
    static let urlFieldMargin: CGFloat = 8
    static let progressViewHeight: CGFloat = 2
    static let iconSize: CGFloat = 50
    static let progressWidth: CGFloat = 250
    static let maxURLLength = 2048
}

/// Main browser view controller providing web browsing functionality
/// Features: URL navigation, video playback, downloads, reading mode, bookmarks, history
class BrowserViewController: UIViewController {

    private let logger = Logger(subsystem: "com.safechrome.browser", category: "browser")

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var urlTextField: UITextField!
    private var toolBar: UIToolbar!
    private var backButton: UIBarButtonItem!
    private var forwardButton: UIBarButtonItem!
    private var refreshButton: UIBarButtonItem!
    private var homeButton: UIBarButtonItem!
    private var videoButton: UIBarButtonItem!
    private var pictureInPictureButton: UIBarButtonItem!
    private var downloadButton: UIBarButtonItem!
    private var downloadsListButton: UIBarButtonItem!
    private var historyButton: UIBarButtonItem!
    private var readingModeButton: UIBarButtonItem!
    private var moreButton: UIBarButtonItem!
    private var securityIcon: UIImageView!
    private var addressBarContainer: UIView!

    private var progressObservation: NSKeyValueObservation?

    private var currentVideoView: AVPlayerViewController?
    private var isVideoPlaying = false
    private var downloadProgressView: UIProgressView?
    private var downloadStatusLabel: UILabel?
    private var currentDownloadTaskId: Int?

    private var isReadingModeActive = false
    private var readerWebView: WKWebView?

    deinit {
        logger.info("BrowserViewController deinit - cleaning up")
        cleanup()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("BrowserViewController viewDidLoad")
        
        // 确保视图有正确的背景色和层级
        view.backgroundColor = .systemBackground
        
        setupUI()
        setupWebView()
        setupConstraints()
        loadHomePage()
        setupNotifications()
        
        logger.info("BrowserViewController setup complete")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logger.debug("BrowserViewController will appear")
    }

    private func setupUI() {
        // setupUI 不再设置背景色，已在 viewDidLoad 中设置
        setupToolbar()
    }

    private func setupToolbar() {
        toolBar = UIToolbar()
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolBar)

        backButton = createBarButton(
            systemName: "chevron.left",
            action: { [weak self] in self?.goBack() },
            accessibilityLabel: Localized.Accessibility.backButton,
            accessibilityHint: Localized.Accessibility.backHint
        )
        backButton.isEnabled = false

        forwardButton = createBarButton(
            systemName: "chevron.right",
            action: { [weak self] in self?.goForward() },
            accessibilityLabel: Localized.Accessibility.forwardButton,
            accessibilityHint: Localized.Accessibility.forwardHint
        )
        forwardButton.isEnabled = false

        refreshButton = createBarButton(
            systemName: "arrow.clockwise",
            action: { [weak self] in self?.reload() },
            accessibilityLabel: Localized.Accessibility.reloadButton,
            accessibilityHint: Localized.Accessibility.reloadHint
        )

        homeButton = createBarButton(
            systemName: "house",
            action: { [weak self] in self?.goHome() },
            accessibilityLabel: Localized.Accessibility.homeButton,
            accessibilityHint: Localized.Accessibility.homeHint
        )

        videoButton = createBarButton(
            systemName: "play.rectangle",
            action: { [weak self] in self?.showVideoOptions() },
            accessibilityLabel: Localized.Accessibility.videoButton,
            accessibilityHint: Localized.Accessibility.videoHint
        )
        videoButton.isEnabled = false

        pictureInPictureButton = createBarButton(
            systemName: "pip.enter",
            action: { [weak self] in self?.togglePictureInPicture() },
            accessibilityLabel: Localized.Accessibility.pipButton,
            accessibilityHint: Localized.Accessibility.pipHint
        )
        pictureInPictureButton.isEnabled = false

        downloadButton = createBarButton(
            systemName: "arrow.down.to.line",
            action: { [weak self] in self?.showDownloadOptions() },
            accessibilityLabel: Localized.Accessibility.downloadButton,
            accessibilityHint: Localized.Accessibility.downloadHint
        )

        readingModeButton = createBarButton(
            systemName: "doc.text",
            action: { [weak self] in self?.toggleReadingMode() },
            accessibilityLabel: Localized.Accessibility.readingModeButton,
            accessibilityHint: Localized.Accessibility.readingModeHint
        )
        readingModeButton.isEnabled = false

        let shareButton = createBarButton(
            systemName: "square.and.arrow.up",
            action: { [weak self] in self?.sharePage() },
            accessibilityLabel: Localized.Accessibility.shareButton,
            accessibilityHint: Localized.Accessibility.shareHint
        )

        downloadsListButton = createBarButton(
            systemName: "folder",
            action: { [weak self] in self?.showAllDownloads() },
            accessibilityLabel: Localized.Accessibility.downloadsListButton,
            accessibilityHint: Localized.Accessibility.downloadsListHint
        )

        historyButton = createBarButton(
            systemName: "clock",
            action: { [weak self] in self?.showHistory() },
            accessibilityLabel: Localized.Accessibility.historyButton,
            accessibilityHint: Localized.Accessibility.historyHint
        )

        moreButton = createBarButton(
            systemName: "ellipsis",
            action: { [weak self] in self?.showMoreMenu() },
            accessibilityLabel: Localized.Accessibility.moreButton,
            accessibilityHint: Localized.Accessibility.moreHint
        )

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixedSpace.width = 15

        toolBar.items = [
            backButton,
            forwardButton,
            fixedSpace,
            refreshButton,
            flexibleSpace,
            homeButton,
            flexibleSpace,
            moreButton
        ]

        toolBar.accessibilityIdentifier = "MainToolbar"

        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        toolBar.addGestureRecognizer(longPressGesture)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        showQuickActionsMenu()
    }

    private func showQuickActionsMenu() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: Localized.Menu.backHistory, style: .default) { [weak self] _ in
            self?.showBackHistoryList()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.forwardHistory, style: .default) { [weak self] _ in
            self?.showForwardHistoryList()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.bookmarks, style: .default) { [weak self] _ in
            self?.showBookmarks()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.addCurrentPage, style: .default) { [weak self] _ in
            self?.toggleBookmark()
        })

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = toolBar
            popover.sourceRect = CGRect(x: view.bounds.midX, y: 0, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showBackHistoryList() {
        let recentURLs = webView.backForwardList.backList
        guard !recentURLs.isEmpty else { return }

        let alert = UIAlertController(title: Localized.Menu.backHistory, message: nil, preferredStyle: .actionSheet)

        for (index, item) in recentURLs.prefix(10).enumerated() {
            let title = item.title ?? item.url.host ?? item.url.absoluteString
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.webView.go(to: self?.webView.backForwardList.backList[recentURLs.count - 1 - index] ?? item)
            })
        }

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = toolBar
            popover.sourceRect = CGRect(x: 20, y: 0, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func showForwardHistoryList() {
        let recentURLs = webView.backForwardList.forwardList
        guard !recentURLs.isEmpty else { return }

        let alert = UIAlertController(title: Localized.Menu.forwardHistory, message: nil, preferredStyle: .actionSheet)

        for item in recentURLs.prefix(10) {
            let title = item.title ?? item.url.host ?? item.url.absoluteString
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                self?.webView.go(to: item)
            })
        }

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = toolBar
            popover.sourceRect = CGRect(x: 60, y: 0, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    private func goHome() {
        let homeURL = URL(string: "https://www.google.com")!
        webView.load(URLRequest(url: homeURL))
    }

    private func createBarButton(systemName: String, action: @escaping () -> Void, accessibilityLabel: String, accessibilityHint: String) -> UIBarButtonItem {
        let uiAction = UIAction(title: accessibilityLabel) { _ in
            action()
        }
        uiAction.accessibilityLabel = accessibilityLabel
        uiAction.accessibilityHint = accessibilityHint
        
        let item = UIBarButtonItem(image: UIImage(systemName: systemName), primaryAction: uiAction)
        item.accessibilityLabel = accessibilityLabel
        item.accessibilityHint = accessibilityHint
        return item
    }

    private func setupWebView() {
        let configuration = PerformanceMonitor.shared.optimizeWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true

        let preferences = WKPreferences()
        preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences = preferences

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.accessibilityLabel = Localized.Accessibility.webContent
        webView.accessibilityIdentifier = "MainWebView"
        view.addSubview(webView)

        setupObservers()

        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.accessibilityIdentifier = "PageProgressView"
        view.addSubview(progressView)

        addressBarContainer = UIView()
        addressBarContainer.translatesAutoresizingMaskIntoConstraints = false
        addressBarContainer.backgroundColor = .secondarySystemBackground
        addressBarContainer.layer.cornerRadius = 10
        view.addSubview(addressBarContainer)

        securityIcon = UIImageView()
        securityIcon.translatesAutoresizingMaskIntoConstraints = false
        securityIcon.image = UIImage(systemName: "lock.fill")
        securityIcon.tintColor = .systemGreen
        securityIcon.contentMode = .scaleAspectFit
        addressBarContainer.addSubview(securityIcon)

        urlTextField = UITextField()
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.borderStyle = .none
        urlTextField.placeholder = Localized.Address.placeholder
        urlTextField.returnKeyType = .go
        urlTextField.autocapitalizationType = .none
        urlTextField.autocorrectionType = .no
        urlTextField.keyboardType = .URL
        urlTextField.clearButtonMode = .whileEditing
        urlTextField.delegate = self
        urlTextField.accessibilityLabel = Localized.Accessibility.addressBar
        urlTextField.accessibilityIdentifier = "URLTextField"
        addressBarContainer.addSubview(urlTextField)

        NSLayoutConstraint.activate([
            addressBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            addressBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            addressBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            addressBarContainer.heightAnchor.constraint(equalToConstant: 44),

            securityIcon.leadingAnchor.constraint(equalTo: addressBarContainer.leadingAnchor, constant: 12),
            securityIcon.centerYAnchor.constraint(equalTo: addressBarContainer.centerYAnchor),
            securityIcon.widthAnchor.constraint(equalToConstant: 20),
            securityIcon.heightAnchor.constraint(equalToConstant: 20),

            urlTextField.leadingAnchor.constraint(equalTo: securityIcon.trailingAnchor, constant: 8),
            urlTextField.trailingAnchor.constraint(equalTo: addressBarContainer.trailingAnchor, constant: -12),
            urlTextField.topAnchor.constraint(equalTo: addressBarContainer.topAnchor),
            urlTextField.bottomAnchor.constraint(equalTo: addressBarContainer.bottomAnchor)
        ])

        updateSecurityIcon(url: nil)

        logger.info("WebView configured successfully")
    }

    private func updateSecurityIcon(url: URL?) {
        guard let url = url else {
            securityIcon.isHidden = true
            return
        }

        securityIcon.isHidden = false

        if url.scheme == "https" {
            securityIcon.image = UIImage(systemName: "lock.fill")
            securityIcon.tintColor = .systemGreen
            urlTextField.textColor = .label
        } else {
            securityIcon.image = UIImage(systemName: "lock.open.fill")
            securityIcon.tintColor = .systemOrange
            urlTextField.textColor = .label
        }
    }

    private func setupObservers() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, change in
            guard let progress = change.newValue else { return }
            DispatchQueue.main.async {
                self?.progressView.progress = Float(progress)
                self?.progressView.isHidden = progress >= 1.0
                self?.updateNavigationButtonsViaJS()
            }
        }
    }

    private func updateNavigationButtonsViaJS() {
        let script = "window.history.length > 1"
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            let canGoBack = result as? Bool ?? false
            DispatchQueue.main.async {
                self?.backButton.isEnabled = canGoBack
            }
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: addressBarContainer.bottomAnchor, constant: LayoutConstant.urlFieldMargin / 2),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: LayoutConstant.progressViewHeight),

            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: toolBar.topAnchor),

            toolBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolBar.heightAnchor.constraint(equalToConstant: LayoutConstant.toolbarHeight)
        ])
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDownloadProgress(_:)),
            name: .downloadProgressUpdated,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDownloadCompleted(_:)),
            name: .downloadCompleted,
            object: nil
        )
        logger.info("Notifications setup complete")
    }

    private func cleanup() {
        progressObservation?.invalidate()
        progressObservation = nil
        NotificationCenter.default.removeObserver(self)
        VideoDownloadManager.shared.cancelAllDownloads()
        exitReadingModeInternal()
    }

    private func loadHomePage() {
        let homeURL = URL(string: "https://www.google.com")!
        webView.load(URLRequest(url: homeURL))
    }

    private func loadURL(_ urlString: String) {
        var processedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)

        if !processedURL.contains("://") {
            if processedURL.contains(".") && !processedURL.contains(" ") {
                processedURL = "https://\(processedURL)"
            } else {
                let searchQuery = processedURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? processedURL
                processedURL = "https://www.google.com/search?q=\(searchQuery)"
            }
        }

        guard let url = URL(string: processedURL) else {
            showError(title: Localized.Error.invalidURL, message: Localized.Error.invalidURLMessage)
            return
        }

        guard url.scheme == "http" || url.scheme == "https" else {
            showError(title: Localized.Error.invalidURL, message: Localized.Error.invalidURLMessage)
            return
        }

        if SecurityPolicyManager.shared.shouldBlock(url: url) {
            showError(title: Localized.Error.blocked, message: Localized.Error.blockedMessage)
            return
        }

        if SecurityPolicyManager.shared.shouldForceHTTPS(for: url),
           let httpsURL = SecurityPolicyManager.shared.getHTTPSURL(for: url) {
            webView.load(URLRequest(url: httpsURL))
        } else {
            webView.load(URLRequest(url: url))
        }

        urlTextField.resignFirstResponder()
    }

    private func updateNavigationButtons() {
        updateNavigationButtonsViaJS()
        forwardButton.isEnabled = webView.canGoForward
    }

    @objc private func goBack() {
        if isReadingModeActive {
            exitReadingMode()
        } else {
            webView.goBack()
        }
    }

    @objc private func goForward() {
        webView.goForward()
    }

    @objc private func reload() {
        if isReadingModeActive {
            reloadReadingModeContent()
        } else {
            webView.reload()
        }
    }

    @objc private func showMoreMenu() {
        let alert = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: Localized.Menu.download, style: .default) { [weak self] _ in
            self?.downloadCurrentVideo()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.downloadList, style: .default) { [weak self] _ in
            self?.showAllDownloads()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.bookmarks, style: .default) { [weak self] _ in
            self?.showBookmarks()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.history, style: .default) { [weak self] _ in
            self?.showHistory()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.addBookmark, style: .default) { [weak self] _ in
            self?.toggleBookmark()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.findInPage, style: .default) { [weak self] _ in
            self?.showFindInPage()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.desktopSite, style: .default) { [weak self] _ in
            self?.toggleDesktopSite()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.readingMode, style: .default) { [weak self] _ in
            self?.toggleReadingMode()
        })

        alert.addAction(UIAlertAction(title: Localized.Menu.share, style: .default) { [weak self] _ in
            self?.sharePage()
        })

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.maxX - 50, y: view.bounds.maxY - 50, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    @objc private func showVideoOptions() {
        let alert = UIAlertController(
            title: Localized.Video.options,
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: Localized.Video.fullscreen, style: .default) { [weak self] _ in
            self?.enterFullscreenVideo()
        })

        alert.addAction(UIAlertAction(title: Localized.Video.pip, style: .default) { [weak self] _ in
            self?.togglePictureInPicture()
        })

        alert.addAction(UIAlertAction(title: Localized.Video.download, style: .default) { [weak self] _ in
            self?.downloadCurrentVideo()
        })

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    @objc private func togglePictureInPicture() {
        logger.info("Picture in Picture toggled")
    }

    @objc private func showDownloadOptions() {
        let alert = UIAlertController(
            title: Localized.Download.manager,
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: Localized.Download.pageVideo, style: .default) { [weak self] _ in
            self?.downloadCurrentVideo()
        })

        alert.addAction(UIAlertAction(title: Localized.Download.currentMedia, style: .default) { [weak self] _ in
            self?.downloadCurrentMedia()
        })

        alert.addAction(UIAlertAction(title: Localized.Download.viewAll, style: .default) { [weak self] _ in
            self?.showAllDownloads()
        })

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }

    @objc private func toggleReadingMode() {
        if isReadingModeActive {
            exitReadingMode()
        } else {
            enterReadingMode()
        }
    }

    private func enterReadingMode() {
        guard !isReadingModeActive else { return }

        ReadingModeManager.shared.extractArticleFromWebView(webView) { [weak self] article in
            guard let self = self, let article = article else {
                DispatchQueue.main.async {
                    self?.showError(title: Localized.Reading.noArticle, message: Localized.Reading.noArticleMessage)
                }
                return
            }

            DispatchQueue.main.async {
                self.displayReadingMode(article: article)
            }
        }
    }

    private func displayReadingMode(article: ArticleContent) {
        isReadingModeActive = true
        readingModeButton.isEnabled = true

        let config = WKWebViewConfiguration()
        readerWebView = WKWebView(frame: .zero, configuration: config)
        readerWebView?.translatesAutoresizingMaskIntoConstraints = false
        readerWebView?.navigationDelegate = self

        let html = ReadingModeManager.shared.generateHTML(for: article)
        readerWebView?.loadHTMLString(html, baseURL: article.url)

        if let readerView = readerWebView {
            view.addSubview(readerView)

            NSLayoutConstraint.activate([
                readerView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
                readerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                readerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                readerView.bottomAnchor.constraint(equalTo: toolBar.topAnchor)
            ])

            readerView.isHidden = true
            webView.isHidden = true
            readerView.isHidden = false

            setupReaderMessageHandlers()
        }

        logger.info("Entered reading mode for article: \(article.title)")
    }

    private func setupReaderMessageHandlers() {
        let contentController = userContentController
        contentController.add(self, name: "fontSizeChanged")
        contentController.add(self, name: "themeChanged")
    }

    private var userContentController: WKUserContentController {
        return readerWebView?.configuration.userContentController ?? WKUserContentController()
    }

    private func exitReadingMode() {
        guard isReadingModeActive else { return }

        cleanupReaderWebView()
        webView.isHidden = false
        readingModeButton.isEnabled = false

        logger.info("Exited reading mode")
    }

    private func exitReadingModeInternal() {
        cleanupReaderWebView()
    }

    private func cleanupReaderWebView() {
        isReadingModeActive = false
        readerWebView?.stopLoading()
        readerWebView?.navigationDelegate = nil
        readerWebView?.uiDelegate = nil
        readerWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "fontSizeChanged")
        readerWebView?.configuration.userContentController.removeScriptMessageHandler(forName: "themeChanged")
        readerWebView?.removeFromSuperview()
        readerWebView = nil
    }

    private func reloadReadingModeContent() {
        guard isReadingModeActive else { return }

        readerWebView?.reload()
    }

    @objc private func sharePage() {
        guard let url = webView.url else { return }

        let activityVC = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(activityVC, animated: true)
    }

    private func enterFullscreenVideo() {
        logger.info("Entering fullscreen video mode")
    }

    private func downloadCurrentVideo() {
        guard let url = webView.url else {
            showError(title: Localized.Download.failed, message: Localized.Error.invalidURLMessage)
            return
        }

        showDownloadProgress()
        VideoDownloadManager.shared.downloadVideo(from: url) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideDownloadProgress()

                switch result {
                case .success(let savedURL):
                    self?.showDownloadSuccess(url: savedURL)
                case .failure(let error):
                    self?.showError(title: Localized.Download.failed, message: error.localizedDescription)
                }
            }
        }
    }

    private func downloadCurrentMedia() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                return video.src || video.currentSrc;
            }
            var source = document.querySelector('source');
            if (source) {
                return source.src;
            }
            return null;
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    self.showError(title: Localized.Download.failed, message: error.localizedDescription)
                }
                return
            }

            guard let urlString = result as? String, let url = URL(string: urlString) else {
                DispatchQueue.main.async {
                    self.showError(title: Localized.Video.noVideo, message: Localized.Video.noVideoMessage)
                }
                return
            }

            DispatchQueue.main.async {
                self.showDownloadProgress()
            }

            VideoDownloadManager.shared.downloadVideo(from: url) { result in
                DispatchQueue.main.async {
                    self.hideDownloadProgress()

                    switch result {
                    case .success(let savedURL):
                        self.showDownloadSuccess(url: savedURL)
                    case .failure(let error):
                        self.showError(title: Localized.Download.failed, message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func showAllDownloads() {
        let downloadsVC = DownloadsViewController()
        let navController = UINavigationController(rootViewController: downloadsVC)
        present(navController, animated: true)
    }

    private func showHistory() {
        let historyVC = HistoryViewController()
        let navController = UINavigationController(rootViewController: historyVC)
        present(navController, animated: true)
    }

    private func showBookmarks() {
        let bookmarkVC = BookmarkViewController()
        let navController = UINavigationController(rootViewController: bookmarkVC)
        present(navController, animated: true)
    }

    private func toggleBookmark() {
        guard let url = webView.url else { return }

        if BookmarkManager.shared.isBookmarked(url: url) {
            BookmarkManager.shared.removeBookmark(url: url)
            showToast(message: Localized.Bookmark.removed)
        } else {
            let title = webView.title ?? url.host ?? url.absoluteString
            BookmarkManager.shared.addBookmark(url: url, title: title)
            showToast(message: Localized.Bookmark.added)
        }
    }

    private func showFindInPage() {
        let alert = UIAlertController(
            title: Localized.FindInPage.title,
            message: nil,
            preferredStyle: .alert
        )

        alert.addTextField { textField in
            textField.placeholder = Localized.FindInPage.placeholder
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Localized.FindInPage.search, style: .default) { [weak self] _ in
            if let query = alert.textFields?.first?.text, !query.isEmpty {
                self?.findInPage(query: query)
            }
        })

        present(alert, animated: true)
    }

    private func findInPage(query: String) {
        let escapedQuery = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let script = "window.find('\(escapedQuery)', false, false, true, false, true, false)"
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private var isDesktopSite = false

    private func toggleDesktopSite() {
        isDesktopSite.toggle()

        let ua = isDesktopSite ?
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15" :
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        webView.customUserAgent = ua
        webView.reload()

        let message = isDesktopSite ? Localized.Menu.desktopSiteOn : Localized.Menu.desktopSiteOff
        showToast(message: message)
    }

    private func showToast(message: String) {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textAlignment = .center
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        toastLabel.textColor = .white
        toastLabel.font = .systemFont(ofSize: 14)
        toastLabel.layer.cornerRadius = 10
        toastLabel.clipsToBounds = true
        toastLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toastLabel)

        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: toolBar.topAnchor, constant: -20),
            toastLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),
            toastLabel.heightAnchor.constraint(equalToConstant: 40)
        ])

        toastLabel.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }

    private func showDownloadProgress() {
        guard downloadProgressView == nil else { return }

        let container = UIView()
        container.backgroundColor = .systemBackground
        container.layer.cornerRadius = 12
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.2
        container.layer.shadowOffset = CGSize(width: 0, height: 2)
        container.layer.shadowRadius = 4
        container.translatesAutoresizingMaskIntoConstraints = false
        container.tag = LayoutTag.downloadOverlay

        let label = UILabel()
        label.text = Localized.Download.starting
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let progress = UIProgressView(progressViewStyle: .bar)
        progress.progressTintColor = .systemBlue
        progress.translatesAutoresizingMaskIntoConstraints = false
        progress.tag = 201

        container.addSubview(label)
        container.addSubview(progress)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: LayoutConstant.progressWidth),

            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),

            progress.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            progress.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            progress.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            progress.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16)
        ])

        downloadProgressView = progress
        downloadStatusLabel = label
    }

    private func hideDownloadProgress() {
        view.viewWithTag(LayoutTag.downloadOverlay)?.removeFromSuperview()
        downloadProgressView = nil
        downloadStatusLabel = nil
    }

    @objc private func handleDownloadProgress(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let progress = userInfo["progress"] as? Float,
              let bytesWritten = userInfo["bytesWritten"] as? Int64,
              let totalBytes = userInfo["totalBytes"] as? Int64 else { return }

        DispatchQueue.main.async { [weak self] in
            self?.downloadProgressView?.progress = progress
            let percent = Int(progress * 100)
            self?.downloadStatusLabel?.text = Localized.Download.progress(
                percent,
                downloaded: ByteCountFormatter.string(fromByteCount: bytesWritten, countStyle: .file),
                total: ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
            )
        }
    }

    @objc private func handleDownloadCompleted(_ notification: Notification) {
        logger.info("Download completed notification received")
    }

    private func showDownloadSuccess(url: URL) {
        let alert = UIAlertController(
            title: Localized.Download.complete,
            message: Localized.Download.savedTo(url.lastPathComponent),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: Localized.Download.share, style: .default) { [weak self] _ in
            let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            self?.present(activityVC, animated: true)
        })

        alert.addAction(UIAlertAction(title: Localized.Download.viewInFiles, style: .default) { _ in
            if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                UIApplication.shared.open(documentsURL)
            }
        })

        alert.addAction(UIAlertAction(title: Localized.Error.ok, style: .cancel))

        present(alert, animated: true)
    }

    private func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.Error.ok, style: .default))
        present(alert, animated: true)
    }
}

extension BrowserViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        logger.info("Started loading: \(webView.url?.absoluteString ?? "unknown")")
        progressView.isHidden = false
        progressView.progress = 0
        urlTextField.text = webView.url?.absoluteString
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        logger.info("Finished loading: \(webView.url?.absoluteString ?? "unknown")")
        updateNavigationButtons()
        urlTextField.text = webView.url?.absoluteString
        updateSecurityIcon(url: webView.url)

        if let url = webView.url {
            webView.evaluateJavaScript("document.title") { [weak self] result, _ in
                let title = result as? String ?? ""
                HistoryManager.shared.addEntry(url: url, title: title)
            }
        }

        readingModeButton.isEnabled = true
        downloadButton.isEnabled = true

        checkForVideo()

        // 延迟更新一次，确保 canGoBack 状态正确
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateNavigationButtons()
        }
    }

    private func checkForVideo() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video && video.src) return true;
            var videos = document.querySelectorAll('video');
            return videos.length > 0;
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            let hasVideo = result as? Bool ?? false
            DispatchQueue.main.async {
                self?.videoButton.isEnabled = hasVideo
                self?.pictureInPictureButton.isEnabled = hasVideo
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        logger.error("Failed to load: \(error.localizedDescription)")
        updateNavigationButtons()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

        if let url = navigationAction.request.url,
           SecurityPolicyManager.shared.shouldBlock(url: url) {
            logger.warning("Blocked navigation to: \(url.host ?? "unknown")")
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        decisionHandler(.allow)
    }
}

extension BrowserViewController: WKUIDelegate {

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.Error.ok, style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: Localized.Error.ok, style: .default) { _ in
            completionHandler(true)
        })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = defaultText
        }
        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel) { _ in
            completionHandler(nil)
        })
        alert.addAction(UIAlertAction(title: Localized.Error.ok, style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        present(alert, animated: true)
    }
}

extension BrowserViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.isEmpty else { return false }
        loadURL(text)
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= LayoutConstant.maxURLLength
    }
}

extension BrowserViewController: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "fontSizeChanged":
            if let size = message.body as? Int {
                ReadingModeManager.shared.updateFontSize(size)
                logger.info("Font size changed to: \(size)")
            }
        case "themeChanged":
            if let themeName = message.body as? String,
               let theme = ReadingPreferences.ReadingTheme(rawValue: themeName.capitalized) {
                ReadingModeManager.shared.updateTheme(theme)
                logger.info("Theme changed to: \(themeName)")
            }
        default:
            break
        }
    }
}

class DownloadsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private var tableView: UITableView!
    private var downloads: [URL] = []
    private var emptyLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localized.Download.manager
        view.backgroundColor = .systemBackground

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        setupUI()
        loadDownloads()
    }

    private func setupUI() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)

        emptyLabel = UILabel()
        emptyLabel.text = Localized.Download.noDownloads
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func loadDownloads() {
        let result = VideoDownloadManager.shared.getAllDownloads()
        switch result {
        case .success(let urls):
            downloads = urls
        case .failure:
            downloads = []
        }

        tableView.reloadData()
        emptyLabel.isHidden = !downloads.isEmpty
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloads.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "DownloadCell")
        let url = downloads[indexPath.row]

        cell.textLabel?.text = url.lastPathComponent
        cell.textLabel?.numberOfLines = 1

        if let info = VideoDownloadManager.shared.getDownloadInfo(at: url) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            cell.detailTextLabel?.text = "\(ByteCountFormatter.string(fromByteCount: info.size, countStyle: .file)) - \(dateFormatter.string(from: info.date))"
        }

        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let url = downloads[indexPath.row]
            let result = VideoDownloadManager.shared.deleteDownload(at: url)

            switch result {
            case .success:
                downloads.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
            case .failure(let error):
                showError(error.localizedDescription)
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let url = downloads[indexPath.row]
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(activityVC, animated: true)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: Localized.Error.generic, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Localized.Error.ok, style: .default))
        present(alert, animated: true)
    }
}
