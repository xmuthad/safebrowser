import Foundation
import WebKit
import os.log

class ReadingModeManager: NSObject {
    static let shared = ReadingModeManager()

    private let logger = Logger(subsystem: "com.safechrome.browser", category: "readingMode")
    private var preferences: ReadingPreferences = .defaultPreferences

    override init() {
        super.init()
        loadPreferences()
    }

    func loadPreferences() {
        if let fontSize = UserDefaults.standard.object(forKey: "readingFontSize") as? Int {
            preferences.fontSize = fontSize
        }
        if let themeName = UserDefaults.standard.string(forKey: "readingTheme"),
           let theme = ReadingPreferences.ReadingTheme(rawValue: themeName) {
            preferences.theme = theme
        }
        if let fontFamily = UserDefaults.standard.string(forKey: "readingFontFamily") {
            preferences.fontFamily = fontFamily
        }
    }

    func savePreferences() {
        UserDefaults.standard.set(preferences.fontSize, forKey: "readingFontSize")
        UserDefaults.standard.set(preferences.theme.rawValue, forKey: "readingTheme")
        UserDefaults.standard.set(preferences.fontFamily, forKey: "readingFontFamily")
    }

    func getPreferences() -> ReadingPreferences {
        return preferences
    }

    func updateFontSize(_ size: Int) {
        preferences.fontSize = max(14, min(28, size))
        savePreferences()
    }

    func updateTheme(_ theme: ReadingPreferences.ReadingTheme) {
        preferences.theme = theme
        savePreferences()
    }

    func extractArticleFromWebView(_ webView: WKWebView, completion: @escaping (ArticleContent?) -> Void) {
        let script = """
        (function() {
            function cleanText(text) {
                return text.replace(/\\s+/g, ' ').trim();
            }

            function getMetaContent(name) {
                var meta = document.querySelector('meta[name="' + name + '"], meta[property="og:' + name + '"]');
                return meta ? meta.getAttribute('content') : null;
            }

            function getArticleImages() {
                var images = [];
                var article = document.querySelector('article, [role="article"], .article, .post, .entry, main');

                if (article) {
                    var imgElements = article.querySelectorAll('img');
                    imgElements.forEach(function(img) {
                        var src = img.src || img.getAttribute('data-src') || img.getAttribute('data-lazy-src');
                        if (src && !src.includes('data:') && !src.includes('base64')) {
                            images.push({
                                src: src,
                                alt: img.alt || '',
                                width: img.naturalWidth || 0,
                                height: img.naturalHeight || 0
                            });
                        }
                    });
                }

                if (images.length === 0) {
                    var allImages = document.querySelectorAll('.content img, .post img, .article img, p img');
                    allImages.forEach(function(img) {
                        var src = img.src || img.getAttribute('data-src');
                        if (src && !src.includes('data:') && !src.includes('base64')) {
                            images.push({
                                src: src,
                                alt: img.alt || '',
                                width: img.naturalWidth || 0,
                                height: img.naturalHeight || 0
                            });
                        }
                    });
                }

                return images;
            }

            var article = document.querySelector('article, [role="article"], .article, .post, .entry, main');
            var content = [];
            var paragraphs = [];

            if (article) {
                paragraphs = Array.from(article.querySelectorAll('p, h2, h3, h4, li'));
            }

            if (paragraphs.length < 3) {
                paragraphs = Array.from(document.querySelectorAll('p, h2, h3, h4'));
            }

            paragraphs.forEach(function(el) {
                var text = cleanText(el.textContent);
                var tagName = el.tagName.toLowerCase();

                if (text.length > 30) {
                    if (tagName === 'li') {
                        content.push('• ' + text);
                    } else if (['h2', 'h3', 'h4'].includes(tagName)) {
                        content.push('\\n## ' + text + '\\n');
                    } else {
                        content.push(text);
                    }
                }
            });

            var title = getMetaContent('title') || getMetaContent('og:title') || document.title || '';
            var author = getMetaContent('author') || getMetaContent('article:author') || null;
            var description = getMetaContent('description') || getMetaContent('og:description') || '';
            var imageURL = getMetaContent('image') || null;
            var articleImages = getArticleImages();

            var videoURL = null;
            var video = document.querySelector('article video, main video, .content video, video[src]');
            if (video) {
                videoURL = video.src || video.currentSrc;
                if (!videoURL) {
                    var source = video.querySelector('source');
                    if (source) videoURL = source.src;
                }
            }

            var bodyContent = content.join('\\n\\n');
            if (bodyContent.length < 200 && description.length > 50) {
                bodyContent = description;
            }

            var wordCount = bodyContent.split(/\\s+/).length;
            var readTime = Math.max(1, Math.ceil(wordCount / 200));

            return {
                title: cleanText(title),
                author: author ? cleanText(author) : null,
                content: bodyContent,
                imageURL: imageURL,
                articleImages: articleImages,
                videoURL: videoURL,
                readTime: readTime,
                url: window.location.href
            };
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else {
                completion(nil)
                return
            }

            if let error = error {
                self.logger.error("Failed to extract article: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let dict = result as? [String: Any],
                  let title = dict["title"] as? String,
                  let content = dict["content"] as? String,
                  content.count > 100 else {
                self.logger.warning("No article content found")
                completion(nil)
                return
            }

            let author = dict["author"] as? String
            let imageURLString = dict["imageURL"] as? String
            let imageURL = imageURLString.flatMap { URL(string: $0) }
            let readTime = dict["readTime"] as? Int ?? 1

            var articleImages: [ArticleImage] = []
            if let imagesArray = dict["articleImages"] as? [[String: Any]] {
                for imageDict in imagesArray {
                    if let src = imageDict["src"] as? String,
                       let url = URL(string: src) {
                        let alt = imageDict["alt"] as? String ?? ""
                        articleImages.append(ArticleImage(url: url, alt: alt))
                    }
                }
            }

            var videoURLString: URL? = nil
            if let videoURL = dict["videoURL"] as? String, !videoURL.isEmpty {
                videoURLString = URL(string: videoURL)
            }

            let article = ArticleContent(
                title: title,
                author: author,
                publishDate: nil,
                content: content,
                url: webView.url ?? URL(string: "about:blank")!,
                imageURL: imageURL,
                articleImages: articleImages,
                estimatedReadTime: readTime,
                videoURL: videoURLString
            )

            self.logger.info("Extracted article: \(title), \(readTime) min read, images: \(articleImages.count), video: \(videoURLString != nil)")
            completion(article)
        }
    }

    func generateHTML(for article: ArticleContent) -> String {
        let prefs = getPreferences()

        let videoSection: String
        if let videoURL = article.videoURL {
            let escapedURL = escapeHTML(videoURL.absoluteString)
            videoSection = """
            <div class="video-container">
                <video controls playsinline preload="metadata" poster="">
                    <source src="\(escapedURL)" type="video/mp4">
                    Your browser does not support the video tag.
                </video>
            </div>
            """
        } else {
            videoSection = ""
        }

        let imagesSection: String
        if !article.articleImages.isEmpty {
            let imagesHTML = article.articleImages.map { image -> String in
                let escapedURL = escapeHTML(image.url.absoluteString)
                let escapedAlt = escapeHTML(image.alt)
                return """
                <figure class="article-image">
                    <img src="\(escapedURL)" alt="\(escapedAlt)" loading="lazy">
                    \(escapedAlt.isEmpty ? "" : "<figcaption>\(escapedAlt)</figcaption>")"
                </figure>
                """
            }.joined(separator: "\n")
            imagesSection = "<div class=\"images-section\">\n\(imagesHTML)\n</div>"
        } else {
            imagesSection = ""
        }

        let formattedContent = article.content
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { paragraph -> String in
                if paragraph.hasPrefix("## ") {
                    let title = String(paragraph.dropFirst(3))
                    return "<h2>\(escapeHTML(title))</h2>"
                } else if paragraph.hasPrefix("• ") {
                    let item = String(paragraph.dropFirst(2))
                    return "<li>\(escapeHTML(item))</li>"
                } else {
                    return "<p>\(escapeHTML(paragraph))</p>"
                }
            }
            .joined(separator: "\n")

        let listContent = article.content.contains("• ") ? "<ul>\(formattedContent)</ul>" : formattedContent

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <title>\(escapeHTML(article.title))</title>
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    font-family: \(prefs.fontFamily), -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
                    font-size: \(prefs.fontSize)px;
                    line-height: 1.8;
                    color: \(prefs.theme.textColor);
                    background-color: \(prefs.theme.backgroundColor);
                    padding: 20px;
                    padding-bottom: 100px;
                    -webkit-text-size-adjust: 100%;
                }
                .container {
                    max-width: 700px;
                    margin: 0 auto;
                }
                .header {
                    margin-bottom: 30px;
                    padding-bottom: 20px;
                    border-bottom: 1px solid rgba(128, 128, 128, 0.3);
                }
                .title {
                    font-size: 1.6em;
                    font-weight: bold;
                    margin-bottom: 15px;
                    line-height: 1.3;
                }
                .meta {
                    font-size: 0.9em;
                    color: rgba(128, 128, 128, 0.8);
                }
                .video-container {
                    margin: 20px 0;
                    position: relative;
                    width: 100%;
                    padding-bottom: 56.25%;
                    background-color: #000;
                    border-radius: 8px;
                    overflow: hidden;
                }
                .video-container video {
                    position: absolute;
                    top: 0;
                    left: 0;
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                }
                .images-section {
                    margin: 20px 0;
                }
                .article-image {
                    margin: 15px 0;
                    text-align: center;
                }
                .article-image img {
                    max-width: 100%;
                    height: auto;
                    border-radius: 8px;
                    display: block;
                    margin: 0 auto;
                }
                .article-image figcaption {
                    margin-top: 8px;
                    font-size: 0.85em;
                    color: rgba(128, 128, 128, 0.8);
                    font-style: italic;
                }
                .content {
                    text-align: justify;
                    margin-bottom: 30px;
                }
                .content h2 {
                    font-size: 1.3em;
                    margin: 1.5em 0 0.8em 0;
                    font-weight: bold;
                }
                .content p {
                    margin-bottom: 1.2em;
                    text-indent: 0;
                }
                .content ul {
                    margin: 1em 0;
                    padding-left: 1.5em;
                }
                .content li {
                    margin-bottom: 0.5em;
                }
                .toolbar {
                    position: fixed;
                    bottom: 0;
                    left: 0;
                    right: 0;
                    background-color: \(prefs.theme.backgroundColor);
                    border-top: 1px solid rgba(128, 128, 128, 0.2);
                    padding: 10px 20px;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    z-index: 1000;
                }
                .toolbar button {
                    background: none;
                    border: 1px solid rgba(128, 128, 128, 0.3);
                    padding: 8px 16px;
                    border-radius: 8px;
                    font-size: 0.9em;
                    cursor: pointer;
                    color: \(prefs.theme.textColor);
                }
                .toolbar button:active {
                    background-color: rgba(128, 128, 128, 0.1);
                }
                .toolbar button.theme-btn {
                    margin-right: 10px;
                }
                .toolbar button.font-btn {
                    margin-left: 10px;
                }
                .footer {
                    margin-top: 40px;
                    padding-top: 20px;
                    border-top: 1px solid rgba(128, 128, 128, 0.3);
                    text-align: center;
                    font-size: 0.85em;
                    color: rgba(128, 128, 128, 0.6);
                }
                @media (max-width: 600px) {
                    body {
                        padding: 15px;
                        font-size: \(max(14, prefs.fontSize - 2))px;
                    }
                    .title {
                        font-size: 1.4em;
                    }
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1 class="title">\(escapeHTML(article.title))</h1>
                    <div class="meta">
                        \(article.author.map { "By \(escapeHTML($0)) • " } ?? "")\(article.estimatedReadTime) min read
                    </div>
                </div>
                \(videoSection)
                \(imagesSection)
                <div class="content">
                    \(listContent)
                </div>
                <div class="footer">
                    <div>Source: \(escapeHTML(article.url.host ?? ""))</div>
                </div>
            </div>
            <div class="toolbar">
                <div>
                    <button class="theme-btn" onclick="toggleTheme()">Theme</button>
                    <button class="theme-btn" onclick="resetSettings()">Reset</button>
                </div>
                <div>
                    <button class="font-btn" onclick="decreaseFont()">A-</button>
                    <button class="font-btn" onclick="increaseFont()">A+</button>
                </div>
            </div>
            <script>
                function increaseFont() {
                    var size = parseInt(getComputedStyle(document.body).fontSize);
                    if (size < 28) {
                        document.body.style.fontSize = (size + 2) + 'px';
                        window.webkit.messageHandlers.fontSizeChanged.postMessage(size + 2);
                    }
                }
                function decreaseFont() {
                    var size = parseInt(getComputedStyle(document.body).fontSize);
                    if (size > 14) {
                        document.body.style.fontSize = (size - 2) + 'px';
                        window.webkit.messageHandlers.fontSizeChanged.postMessage(size - 2);
                    }
                }
                var themes = ['light', 'sepia', 'dark'];
                var currentTheme = 0;
                function toggleTheme() {
                    currentTheme = (currentTheme + 1) % themes.length;
                    var theme = themes[currentTheme];
                    window.webkit.messageHandlers.themeChanged.postMessage(theme);
                }
                function resetSettings() {
                    document.body.style.fontSize = '18px';
                    window.webkit.messageHandlers.fontSizeChanged.postMessage(18);
                }
            </script>
        </body>
        </html>
        """
    }

    private func escapeHTML(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

struct ArticleImage {
    let url: URL
    let alt: String
}

struct ArticleContent {
    let title: String
    let author: String?
    let publishDate: Date?
    let content: String
    let url: URL
    let imageURL: URL?
    let articleImages: [ArticleImage]
    let estimatedReadTime: Int
    let videoURL: URL?
}

struct ReadingPreferences {
    var fontSize: Int
    var theme: ReadingTheme
    var fontFamily: String

    enum ReadingTheme: String, CaseIterable {
        case light = "Light"
        case sepia = "Sepia"
        case dark = "Dark"

        var backgroundColor: String {
            switch self {
            case .light: return "#FFFFFF"
            case .sepia: return "#F4ECD8"
            case .dark: return "#1A1A1A"
            }
        }

        var textColor: String {
            switch self {
            case .light: return "#333333"
            case .sepia: return "#5B4636"
            case .dark: return "#E0E0E0"
            }
        }
    }

    static var defaultPreferences: ReadingPreferences {
        return ReadingPreferences(fontSize: 18, theme: .light, fontFamily: "-apple-system")
    }
}
