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

class BrowserViewController: UIViewController {

    private let logger = Logger(subsystem: "com.safechrome.browser", category: "browser")

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var urlTextField: UITextField!
    private var toolBar: UIToolbar!
    private var backButton: UIBarButtonItem!
    private var forwardButton: UIBarButtonItem!
    private var refreshButton: UIBarButtonItem!
    private var videoButton: UIBarButtonItem!
    private var pictureInPictureButton: UIBarButtonItem!
    private var downloadButton: UIBarButtonItem!
    private var readingModeButton: UIBarButtonItem!

    private var progressObservation: NSKeyValueObservation?
    private var mediaPlaybackObservation: NSKeyValueObservation?
    private var currentVideoView: AVPlayerViewController?
    private var isVideoPlaying = false

    private var downloadProgressView: UIProgressView?
    private var downloadStatusLabel: UILabel?
    private var currentDownloadTaskId: Int?

    deinit {
        logger.info("BrowserViewController deinit - cleaning up")
        progressObservation?.invalidate()
        mediaPlaybackObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
        VideoDownloadManager.shared.cancelAllDownloads()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logger.info("BrowserViewController viewDidLoad")
        setupUI()
        setupWebView()
        setupConstraints()
        loadHomePage()
        setupNotifications()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logger.debug("BrowserViewController will appear")
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        setupToolbar()
    }

    private func setupToolbar() {
        toolBar = UIToolbar()
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolBar)

        backButton = createBarButton(
            systemName: "chevron.left",
            action: #selector(goBack),
            accessibilityLabel: "Go Back"
        )
        backButton.isEnabled = false

        forwardButton = createBarButton(
            systemName: "chevron.right",
            action: #selector(goForward),
            accessibilityLabel: "Go Forward"
        )
        forwardButton.isEnabled = false

        refreshButton = createBarButton(
            systemName: "arrow.clockwise",
            action: #selector(reload),
            accessibilityLabel: "Reload Page"
        )

        videoButton = createBarButton(
            systemName: "play.rectangle",
            action: #selector(showVideoOptions),
            accessibilityLabel: "Video Options"
        )
        videoButton.isEnabled = false

        pictureInPictureButton = createBarButton(
            systemName: "pip.enter",
            action: #selector(togglePictureInPicture),
            accessibilityLabel: "Picture in Picture"
        )
        pictureInPictureButton.isEnabled = false

        downloadButton = createBarButton(
            systemName: "arrow.down.to.line",
            action: #selector(showDownloadOptions),
            accessibilityLabel: "Download Media"
        )
        downloadButton.isEnabled = false

        readingModeButton = createBarButton(
            systemName: "doc.text",
            action: #selector(toggleReadingMode),
            accessibilityLabel: "Reading Mode"
        )
        readingModeButton.isEnabled = false

        let shareButton = createBarButton(
            systemName: "square.and.arrow.up",
            action: #selector(sharePage),
            accessibilityLabel: "Share Page"
        )

        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolBar.items = [
            backButton,
            flexibleSpace,
            forwardButton,
            flexibleSpace,
            refreshButton,
            flexibleSpace,
            videoButton,
            flexibleSpace,
            pictureInPictureButton,
            flexibleSpace,
            downloadButton,
            flexibleSpace,
            readingModeButton,
            flexibleSpace,
            shareButton
        ]

        toolBar.accessibilityIdentifier = "MainToolbar"
    }

    private func createBarButton(systemName: String, action: Selector, accessibilityLabel: String) -> UIBarButtonItem {
        let button = UIBarButtonItem(image: UIImage(systemName: systemName), style: .plain, target: self, action: action)
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityTraits = .button
        return button
    }

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsPictureInPictureVideoPlayback = true
        webView.accessibilityLabel = "Web Content"
        webView.accessibilityIdentifier = "MainWebView"
        view.addSubview(webView)

        setupObservers()

        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.accessibilityIdentifier = "PageProgressView"
        view.addSubview(progressView)

        urlTextField = UITextField()
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlTextField.borderStyle = .roundedRect
        urlTextField.placeholder = "Enter URL or search"
        urlTextField.returnKeyType = .go
        urlTextField.autocapitalizationType = .none
        urlTextField.autocorrectionType = .no
        urlTextField.keyboardType = .URL
        urlTextField.clearButtonMode = .whileEditing
        urlTextField.delegate = self
        urlTextField.accessibilityLabel = "Address Bar"
        urlTextField.accessibilityIdentifier = "URLTextField"
        view.addSubview(urlTextField)

        logger.info("WebView configured successfully")
    }

    private func setupObservers() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, change in
            guard let progress = change.newValue else { return }
            DispatchQueue.main.async {
                self?.progressView.progress = Float(progress)
                self?.progressView.isHidden = progress >= 1.0
            }
        }

        mediaPlaybackObservation = webView.observe(\.mediaPlaybackState, options: [.new]) { [weak self] webView, _ in
            let state = webView.mediaPlaybackState
            DispatchQueue.main.async {
                self?.handleMediaPlaybackStateChange(state)
            }
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            urlTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: LayoutConstant.urlFieldMargin),
            urlTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: LayoutConstant.urlFieldMargin),
            urlTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -LayoutConstant.urlFieldMargin),
            urlTextField.heightAnchor.constraint(equalToConstant: LayoutConstant.urlFieldHeight),

            progressView.topAnchor.constraint(equalTo: urlTextField.bottomAnchor, constant: LayoutConstant.urlFieldMargin / 2),
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

    @objc private func handleDownloadProgress(_ notification: Notification) {
        guard let taskId = notification.userInfo?["taskId"] as? Int,
              taskId == currentDownloadTaskId,
              let progress = notification.userInfo?["progress"] as? Float,
              let bytesWritten = notification.userInfo?["bytesWritten"] as? Int64,
              let totalBytes = notification.userInfo?["totalBytes"] as? Int64 else {
            return
        }

        DispatchQueue.main.async {
            self.downloadProgressView?.progress = progress
            let percentage = Int(progress * 100)
            let downloadedSize = self.formatFileSize(bytesWritten)
            let totalSize = self.formatFileSize(totalBytes)
            self.downloadStatusLabel?.text = "Downloading: \(percentage)% (\(downloadedSize) / \(totalSize))"
        }
    }

    @objc private func handleDownloadCompleted(_ notification: Notification) {
        DispatchQueue.main.async {
            self.hideDownloadProgress()
            if let url = notification.userInfo?["url"] as? URL {
                self.showDownloadSuccess(url: url)
            }
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func loadHomePage() {
        if let url = URL(string: "https://www.google.com") {
            webView.load(URLRequest(url: url))
            logger.info("Loading homepage: \(url.absoluteString)")
        }
    }

    private func loadURL(_ string: String) {
        var urlString = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard urlString.count <= LayoutConstant.maxURLLength else {
            logger.warning("URL too long, truncated")
            urlString = String(urlString.prefix(LayoutConstant.maxURLLength))
        }

        if !urlString.contains("://") && !urlString.hasPrefix("localhost") {
            if urlString.contains(".") && !urlString.contains(" ") {
                urlString = "https://" + urlString
            } else {
                let query = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? urlString
                urlString = "https://www.google.com/search?q=" + query
            }
        }

        guard let url = URL(string: urlString), isValidNavigationURL(url) else {
            logger.error("Invalid URL: \(string)")
            showInvalidURLAlert()
            return
        }

        webView.load(URLRequest(url: url))
        logger.info("Loading URL: \(url.absoluteString)")
    }

    private func isValidNavigationURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        let validSchemes = ["http", "https"]
        return validSchemes.contains(scheme)
    }

    @objc private func goBack() {
        webView.goBack()
        logger.debug("Navigation: back")
    }

    @objc private func goForward() {
        webView.goForward()
        logger.debug("Navigation: forward")
    }

    @objc private func reload() {
        webView.reload()
        logger.debug("Navigation: reload")
    }

    @objc private func sharePage() {
        guard let url = webView.url else {
            logger.warning("Share attempted with no URL")
            return
        }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        present(activityVC, animated: true)
        logger.info("Sharing page: \(url.absoluteString)")
    }

    private var isReadingModeActive = false
    private var readerWebView: WKWebView?
    private var originalWebViewSnapshot: Bool = false

    @objc private func toggleReadingMode() {
        if isReadingModeActive {
            exitReadingMode()
        } else {
            enterReadingMode()
        }
    }

    private func enterReadingMode() {
        logger.info("Entering reading mode")
        originalWebViewSnapshot = true
        isReadingModeActive = true
        readingModeButton.image = UIImage(systemName: "doc.plaintext.fill")

        let loadingAlert = UIAlertController(title: nil, message: "Preparing reading mode...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true)

        ReadingModeManager.shared.extractArticleFromWebView(webView) { [weak self] article in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    guard let self = self else { return }

                    if let article = article {
                        self.showReadingModeView(with: article)
                        self.logger.info("Article extracted successfully")
                    } else {
                        self.showNoArticleAlert()
                        self.isReadingModeActive = false
                        self.readingModeButton.image = UIImage(systemName: "doc.text.fill")
                    }
                }
            }
        }
    }

    private func showReadingModeView(with article: ArticleContent) {
        let html = ReadingModeManager.shared.generateHTML(for: article)

        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = self
        webView.uiDelegate = self

        let contentController = webView.configuration.userContentController
        contentController.add(self, name: "fontSizeChanged")
        contentController.add(self, name: "themeChanged")

        self.readerWebView = webView

        webView.loadHTMLString(html, baseURL: article.url)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .systemGray
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(exitReadingMode), for: .touchUpInside)
        closeButton.accessibilityLabel = "Exit Reading Mode"

        view.addSubview(webView)
        view.addSubview(closeButton)

        webView.topAnchor.constraint(equalTo: progressView.bottomAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: toolBar.topAnchor).isActive = true

        closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8).isActive = true
        closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8).isActive = true
        closeButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        closeButton.heightAnchor.constraint(equalToConstant: 44).isActive = true

        webView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.webView.alpha = 0.3
            webView.alpha = 1
        }
    }

    @objc private func exitReadingMode() {
        logger.info("Exiting reading mode")
        isReadingModeActive = false
        readingModeButton.image = UIImage(systemName: "doc.text")

        if let readerWebView = readerWebView {
            let contentController = readerWebView.configuration.userContentController
            contentController.removeScriptMessageHandler(forName: "fontSizeChanged")
            contentController.removeScriptMessageHandler(forName: "themeChanged")

            UIView.animate(withDuration: 0.3, animations: {
                readerWebView.alpha = 0
            }) { _ in
                readerWebView.removeFromSuperview()
                if let closeButton = self.view.subviews.first(where: { $0.accessibilityLabel == "Exit Reading Mode" }) {
                    closeButton.removeFromSuperview()
                }
                self.readerWebView = nil
            }
        }
    }

    private func showNoArticleAlert() {
        let alert = UIAlertController(
            title: "No Article Found",
            message: "Reading mode couldn't find article content on this page. Try a news article or blog post.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }


    @objc private func showVideoOptions() {
        let alertController = UIAlertController(
            title: "Video Options",
            message: "Choose video playback mode",
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "Full Screen", style: .default) { [weak self] _ in
            self?.checkForVideoAndPlayFullScreen()
        })

        alertController.addAction(UIAlertAction(title: "Picture in Picture", style: .default) { [weak self] _ in
            self?.togglePictureInPicture()
        })

        alertController.addAction(UIAlertAction(title: "Download Video", style: .default) { [weak self] _ in
            self?.downloadCurrentVideo()
        })

        alertController.addAction(UIAlertAction(title: "Open Video Page", style: .default) { [weak self] _ in
            self?.openVideoPageInNewTab()
        })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alertController.popoverPresentationController?.barButtonItem = videoButton
        present(alertController, animated: true)
    }

    @objc private func showDownloadOptions() {
        let alertController = UIAlertController(
            title: "Download Manager",
            message: "Manage your downloads",
            preferredStyle: .actionSheet
        )

        alertController.addAction(UIAlertAction(title: "Download Page Video", style: .default) { [weak self] _ in
            self?.downloadCurrentVideo()
        })

        alertController.addAction(UIAlertAction(title: "Download Current Media", style: .default) { [weak self] _ in
            self?.downloadCurrentMedia()
        })

        alertController.addAction(UIAlertAction(title: "View Downloads", style: .default) { [weak self] _ in
            self?.showDownloadsList()
        })

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alertController.popoverPresentationController?.barButtonItem = downloadButton
        present(alertController, animated: true)
    }

    private func downloadCurrentVideo() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            if (video) {
                var src = video.src || video.currentSrc;
                if (!src) {
                    var source = video.querySelector('source');
                    if (source) src = source.src;
                }
                if (src && src.length < \(LayoutConstant.maxURLLength)) {
                    return {
                        found: true,
                        src: src,
                        duration: video.duration,
                        currentTime: video.currentTime
                    };
                }
            }
            return { found: false };
        })();
        """

        evaluateJavaScriptAndDownload(script: script, fallbackHandler: { [weak self] in
            self?.showNoVideoAlert()
        })
    }

    private func downloadCurrentMedia() {
        let script = """
        (function() {
            var video = document.querySelector('video');
            var audio = document.querySelector('audio');
            var media = video || audio;

            if (media) {
                var src = media.src || media.currentSrc;
                if (!src) {
                    var source = media.querySelector('source');
                    if (source) src = source.src;
                }
                if (src && src.length < \(LayoutConstant.maxURLLength)) {
                    return {
                        found: true,
                        type: video ? 'video' : 'audio',
                        src: src,
                        duration: media.duration
                    };
                }
            }
            return { found: false };
        })();
        """

        evaluateJavaScriptAndDownload(script: script, fallbackHandler: { [weak self] in
            self?.showNoMediaAlert()
        })
    }

    private func evaluateJavaScriptAndDownload(script: String, fallbackHandler: @escaping () -> Void) {
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("JavaScript evaluation failed: \(error.localizedDescription)")
                fallbackHandler()
                return
            }

            guard let dict = result as? [String: Any],
                  let found = dict["found"] as? Bool,
                  found,
                  let src = dict["src"] as? String,
                  !src.isEmpty,
                  let url = URL(string: src),
                  self.isValidDownloadURL(url) else {
                fallbackHandler()
                return
            }

            let mediaType = dict["type"] as? String ?? "media"
            let fileName = "\(mediaType)_\(Int(Date().timeIntervalSince1970)).mp4"
            self.startDownload(url: url, fileName: fileName)
        }
    }

    private func isValidDownloadURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        let validSchemes = ["http", "https"]
        return validSchemes.contains(scheme) && url.host?.isEmpty == false
    }

    private func startDownload(url: URL, fileName: String) {
        showDownloadProgress()
        logger.info("Starting download: \(fileName)")

        VideoDownloadManager.shared.downloadVideo(from: url) { [weak self] result in
            DispatchQueue.main.async {
                self?.hideDownloadProgress()

                switch result {
                case .success(let downloadedURL):
                    self?.logger.info("Download success: \(downloadedURL.lastPathComponent)")
                    self?.showDownloadSuccess(url: downloadedURL)
                case .failure(let error):
                    self?.logger.error("Download failed: \(error.localizedDescription)")
                    self?.showDownloadError(error)
                }
            }
        }
    }

    private func showDownloadProgress() {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.accessibilityIdentifier = "DownloadOverlay"
        view.addSubview(containerView)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(stackView)

        let iconImageView = UIImageView(image: UIImage(systemName: "arrow.down.circle.fill"))
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.widthAnchor.constraint(equalToConstant: LayoutConstant.iconSize).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: LayoutConstant.iconSize).isActive = true
        iconImageView.accessibilityLabel = "Downloading"
        stackView.addArrangedSubview(iconImageView)

        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.progressTintColor = .systemBlue
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.widthAnchor.constraint(equalToConstant: LayoutConstant.progressWidth).isActive = true
        stackView.addArrangedSubview(progressView)
        self.downloadProgressView = progressView

        let statusLabel = UILabel()
        statusLabel.text = "Preparing download..."
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        stackView.addArrangedSubview(statusLabel)
        self.downloadStatusLabel = statusLabel

        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.accessibilityLabel = "Cancel Download"
        cancelButton.addTarget(self, action: #selector(cancelDownload), for: .touchUpInside)
        stackView.addArrangedSubview(cancelButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])

        containerView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            containerView.alpha = 1
        }
    }

    @objc private func cancelDownload() {
        logger.info("Cancelling download")
        hideDownloadProgress()
    }

    private func hideDownloadProgress() {
        guard let containerView = view.subviews.first(where: { $0.accessibilityIdentifier == "DownloadOverlay" }) else {
            return
        }

        UIView.animate(withDuration: 0.3) {
            containerView.alpha = 0
        } completion: { _ in
            containerView.removeFromSuperview()
        }
        downloadProgressView = nil
        downloadStatusLabel = nil
        currentDownloadTaskId = nil
    }

    private func showDownloadSuccess(url: URL) {
        let alert = UIAlertController(
            title: "Download Complete!",
            message: "Video saved to:\n\(url.lastPathComponent)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in
            self?.shareDownloadedFile(url: url)
        })

        alert.addAction(UIAlertAction(title: "View in Files", style: .default) { [weak self] _ in
            self?.openInFiles(url: url)
        })

        alert.addAction(UIAlertAction(title: "OK", style: .cancel))

        present(alert, animated: true)
    }

    private func showDownloadError(_ error: Error) {
        let alert = UIAlertController(
            title: "Download Failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showInvalidURLAlert() {
        let alert = UIAlertController(
            title: "Invalid URL",
            message: "Please enter a valid web address.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showNoVideoAlert() {
        let alert = UIAlertController(
            title: "No Video Found",
            message: "This page doesn't contain any detectable video. Try loading a video website like YouTube.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showNoMediaAlert() {
        let alert = UIAlertController(
            title: "No Media Found",
            message: "This page doesn't contain any playable media.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showDownloadsList() {
        let result = VideoDownloadManager.shared.getAllDownloads()

        switch result {
        case .success(let downloads):
            let alert = UIAlertController(
                title: "Downloads",
                message: "\(downloads.count) video(s) downloaded",
                preferredStyle: .actionSheet
            )

            if downloads.isEmpty {
                alert.message = "No downloads yet"
            } else {
                for (index, url) in downloads.prefix(5).enumerated() {
                    let fileName = url.lastPathComponent
                    alert.addAction(UIAlertAction(title: "\(index + 1). \(fileName)", style: .default) { [weak self] _ in
                        self?.shareDownloadedFile(url: url)
                    })
                }
            }

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.popoverPresentationController?.barButtonItem = downloadButton
            present(alert, animated: true)

        case .failure(let error):
            showDownloadError(error)
        }
    }

    private func shareDownloadedFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = view
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        present(activityVC, animated: true)
    }

    private func openInFiles(url: URL) {
        let documentController = UIDocumentInteractionController(url: url)
        documentController.delegate = self
        documentController.presentPreview(animated: true)
    }

    @objc private func togglePictureInPicture() {
        if #available(iOS 15.0, *) {
            if webView.isPictureInPictureActive {
                webView.stopPictureInPicture()
                logger.debug("PiP stopped")
            } else {
                webView.startPictureInPicture()
                logger.debug("PiP started")
            }
        }
    }

    private func checkForVideoAndPlayFullScreen() {
        let script = """
        (function() {
            var videos = document.querySelectorAll('video');
            if (videos.length > 0) {
                var video = videos[0];
                return {
                    found: true,
                    playing: !video.paused,
                    duration: video.duration,
                    currentTime: video.currentTime,
                    src: video.src || video.currentSrc
                };
            }
            return { found: false };
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Fullscreen check failed: \(error.localizedDescription)")
                return
            }

            guard let dict = result as? [String: Any],
                  let found = dict["found"] as? Bool,
                  found else {
                self.showNoVideoAlert()
                return
            }

            self.webView.enterFullScreen()
            self.logger.debug("Entered fullscreen")
        }
    }

    private func openVideoPageInNewTab() {
        let alert = UIAlertController(
            title: "Video Websites",
            message: "Choose a video platform to open:",
            preferredStyle: .actionSheet
        )

        let videoSites = [
            ("YouTube", "youtube.com"),
            ("Vimeo", "vimeo.com"),
            ("Dailymotion", "dailymotion.com")
        ]

        for (name, url) in videoSites {
            alert.addAction(UIAlertAction(title: name, style: .default) { [weak self] _ in
                self?.loadURL(url)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = videoButton
        present(alert, animated: true)
    }

    private func detectVideoInPage() {
        let script = """
        (function() {
            var videos = document.querySelectorAll('video');
            var audios = document.querySelectorAll('audio');
            var hasMedia = (videos.length > 0 || audios.length > 0);

            var hasArticle = !!(
                document.querySelector('article') ||
                document.querySelector('[role="article"]') ||
                document.querySelector('.article') ||
                document.querySelector('.post') ||
                document.querySelector('.entry-content') ||
                document.querySelector('main')
            );

            return {
                hasMedia: hasMedia,
                hasArticle: hasArticle
            };
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Content detection failed: \(error.localizedDescription)")
                return
            }

            if let dict = result as? [String: Any] {
                let hasMedia = dict["hasMedia"] as? Bool ?? false
                let hasArticle = dict["hasArticle"] as? Bool ?? false

                self.videoButton.isEnabled = hasMedia
                self.downloadButton.isEnabled = hasMedia
                self.readingModeButton.isEnabled = hasArticle

                if hasMedia {
                    self.videoButton.image = UIImage(systemName: "play.rectangle.fill")
                    self.downloadButton.image = UIImage(systemName: "arrow.down.to.line.circle.fill")
                } else {
                    self.videoButton.image = UIImage(systemName: "play.rectangle")
                    self.downloadButton.image = UIImage(systemName: "arrow.down.to.line")
                }

                if hasArticle {
                    self.readingModeButton.image = UIImage(systemName: "doc.text.fill")
                } else {
                    self.readingModeButton.image = UIImage(systemName: "doc.text")
                }
            }
        }
    }

    private func updateNavigationButtons() {
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
    }

    private func handleMediaPlaybackStateChange(_ state: WKWebView.MediaPlaybackState) {
        isVideoPlaying = (state == .playing)

        if isVideoPlaying {
            videoButton.image = UIImage(systemName: "pause.rectangle.fill")
            pictureInPictureButton.isEnabled = true
        } else if state == .paused {
            videoButton.image = UIImage(systemName: "play.rectangle.fill")
            pictureInPictureButton.isEnabled = true
        }
    }

    override var supportedInterfaceOrientationsForChild: UIViewController {
        return .all
    }

    override var shouldAutorotate: Bool {
        return true
    }
}

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.progressView.isHidden = false
            self.progressView.progress = 0
            self.isVideoPlaying = false
            self.videoButton.isEnabled = false
            self.pictureInPictureButton.isEnabled = false
            self.downloadButton.isEnabled = false
        }
        logger.info("Started navigation")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async {
            self.urlTextField.text = self.webView.url?.absoluteString
            self.updateNavigationButtons()
            self.progressView.isHidden = true
            self.detectVideoInPage()
        }
        logger.info("Navigation finished: \(self.webView.url?.absoluteString ?? "unknown")")
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        DispatchQueue.main.async {
            self.progressView.isHidden = true
            self.updateNavigationButtons()
        }
        logger.error("Navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        guard isValidNavigationURL(url) else {
            logger.warning("Blocked navigation to invalid URL: \(url.absoluteString)")
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
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            completionHandler(false)
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(true)
        })
        present(alert, animated: true)
    }
}

extension BrowserViewController: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
}

extension BrowserViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? String else { return }

        switch message.name {
        case "fontSizeChanged":
            if let fontSize = Int(body) {
                ReadingModeManager.shared.updateFontSize(fontSize)
                logger.info("Font size changed to: \(fontSize)")
            }
        case "themeChanged":
            let themeName = body.lowercased()
            if let theme = ReadingPreferences.ReadingTheme.allCases.first(where: { $0.rawValue.lowercased() == themeName }) {
                ReadingModeManager.shared.updateTheme(theme)
                logger.info("Theme changed to: \(theme.rawValue)")
            }
        default:
            break
        }
    }
}

extension BrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text, !text.isEmpty {
            loadURL(text)
        }
        return true
    }
}

extension WKWebView {
    func enterFullScreen() {
        evaluateJavaScript("document.querySelector('video')?.requestFullscreen()") { _, error in
            if let error = error {
                print("Failed to enter fullscreen: \(error.localizedDescription)")
            }
        }
    }

    func exitFullScreen() {
        evaluateJavaScript("document.exitFullscreen()") { _, error in
            if let error = error {
                print("Failed to exit fullscreen: \(error.localizedDescription)")
            }
        }
    }
}
