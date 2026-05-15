import Foundation
import os.log

enum DownloadError: Error, LocalizedError {
    case invalidURL
    case downloadFailed(Error)
    case fileOperationFailed(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        case .fileOperationFailed(let error):
            return "File operation failed: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        }
    }
}

enum DownloadResult {
    case success(URL)
    case failure(DownloadError)
}

class VideoDownloadManager: NSObject {
    static let shared = VideoDownloadManager()

    private let logger = Logger(subsystem: "com.safechrome.browser", category: "download")
    private var downloadSession: URLSession!
    private var activeDownloads: [Int: URL] = [:]
    private var downloadProgress: [Int: Float] = [:]
    private var downloadCompletion: [Int: (DownloadResult) -> Void] = [:]
    private let downloadQueue = OperationQueue()

    private override init() {
        super.init()
        let config = URLSessionConfiguration.background(withIdentifier: downloadSessionIdentifier)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        downloadQueue.maxConcurrentOperationCount = 1
        downloadQueue.qualityOfService = .userInitiated
        downloadSession = URLSession(configuration: config, delegate: self, delegateQueue: downloadQueue)
        logger.info("Download manager initialized")
    }

    private var downloadSessionIdentifier: String {
        let identifier = Bundle.main.bundleIdentifier ?? "com.safechrome"
        return "\(identifier).videodownload"
    }

    func downloadVideo(from url: URL, completion: @escaping (DownloadResult) -> Void) {
        guard isValidDownloadURL(url) else {
            logger.error("Invalid download URL attempted: \(url.absoluteString)")
            completion(.failure(.invalidURL))
            return
        }

        let task = downloadSession.downloadTask(with: url)
        activeDownloads[task.taskIdentifier] = url
        downloadCompletion[task.taskIdentifier] = completion
        task.resume()

        logger.info("Started download: \(url.lastPathComponent)")
    }

    func cancelDownload(taskIdentifier: Int) {
        downloadSession.getAllTasks { [weak self] tasks in
            guard let task = tasks.first(where: { $0.taskIdentifier == taskIdentifier }) as? URLSessionDownloadTask else {
                return
            }
            task.cancel()
            self?.activeDownloads.removeValue(forKey: taskIdentifier)
            self?.downloadCompletion.removeValue(forKey: taskIdentifier)
            self?.logger.info("Cancelled download with identifier: \(taskIdentifier)")
        }
    }

    func cancelAllDownloads() {
        downloadSession.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        activeDownloads.removeAll()
        downloadCompletion.removeAll()
    }

    private func isValidDownloadURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }
        let validSchemes = ["http", "https"]
        guard validSchemes.contains(scheme) else {
            return false
        }

        let host = url.host ?? ""
        guard !host.isEmpty, host.count < 255 else {
            return false
        }

        return true
    }

    func getDownloadsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let downloadsPath = paths[0].appendingPathComponent("Downloads", isDirectory: true)

        if !FileManager.default.fileExists(atPath: downloadsPath.path) {
            do {
                try FileManager.default.createDirectory(at: downloadsPath, withIntermediateDirectories: true)
                logger.info("Created downloads directory")
            } catch {
                logger.error("Failed to create downloads directory: \(error.localizedDescription)")
            }
        }

        return downloadsPath
    }

    func getAllDownloads() -> Result<[URL], Error> {
        let downloadsPath = getDownloadsDirectory()
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: downloadsPath,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            let mediaFiles = files.filter {
                let ext = $0.pathExtension.lowercased()
                return ["mp4", "mov", "m4v", "mp3", "m4a", "wav"].contains(ext)
            }.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 > date2
            }
            logger.info("Found \(mediaFiles.count) downloads")
            return .success(mediaFiles)
        } catch {
            logger.error("Failed to get downloads: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    func deleteDownload(at url: URL) -> Result<Void, Error> {
        do {
            try FileManager.default.removeItem(at: url)
            logger.info("Deleted download: \(url.lastPathComponent)")
            return .success(())
        } catch {
            logger.error("Failed to delete download: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    func getDownloadInfo(at url: URL) -> (size: Int64, date: Date)? {
        guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
              let size = resourceValues.fileSize,
              let date = resourceValues.creationDate else {
            return nil
        }
        return (Int64(size), date)
    }
}

extension VideoDownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalURL = downloadTask.originalRequest?.url else {
            downloadCompletion[downloadTask.taskIdentifier]?(.failure(.invalidURL))
            cleanupDownload(taskIdentifier: downloadTask.taskIdentifier)
            return
        }

        let downloadsPath = getDownloadsDirectory()
        let originalFileName = sanitizeFileName(originalURL.lastPathComponent)
        let uniqueFileName = generateUniqueFileName(for: originalFileName, in: downloadsPath)
        let destinationURL = downloadsPath.appendingPathComponent(uniqueFileName)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)

            logger.info("Download completed: \(uniqueFileName)")
            downloadCompletion[downloadTask.taskIdentifier]?(.success(destinationURL))

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .downloadCompleted,
                    object: nil,
                    userInfo: ["url": destinationURL]
                )
            }
        } catch {
            logger.error("Failed to save downloaded file: \(error.localizedDescription)")
            downloadCompletion[downloadTask.taskIdentifier]?(.failure(.fileOperationFailed(error)))
        }

        cleanupDownload(taskIdentifier: downloadTask.taskIdentifier)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }

        let progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        downloadProgress[downloadTask.taskIdentifier] = progress

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .downloadProgressUpdated,
                object: nil,
                userInfo: [
                    "taskId": downloadTask.taskIdentifier,
                    "progress": progress,
                    "bytesWritten": totalBytesWritten,
                    "totalBytes": totalBytesExpectedToWrite
                ]
            )
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                logger.info("Download cancelled: \(task.taskIdentifier)")
            } else {
                logger.error("Download error: \(error.localizedDescription)")
                downloadCompletion[task.taskIdentifier]?(.failure(.downloadFailed(error)))
                cleanupDownload(taskIdentifier: task.taskIdentifier)
            }
        }
    }

    private func cleanupDownload(taskIdentifier: Int) {
        activeDownloads.removeValue(forKey: taskIdentifier)
        downloadCompletion.removeValue(forKey: taskIdentifier)
        downloadProgress.removeValue(forKey: taskIdentifier)
    }

    private func sanitizeFileName(_ fileName: String) -> String {
        var sanitized = fileName
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        sanitized.unicodeScalars.filter { invalidCharacters.contains($0) }.forEach { _ in
            sanitized = sanitized.replacingOccurrences(of: " ", with: "_")
        }

        if sanitized.isEmpty {
            sanitized = "video_\(Int(Date().timeIntervalSince1970)).mp4"
        }

        let validExtensions = ["mp4", "mov", "m4v", "mp3", "m4a", "wav"]
        let fileExtension = (sanitized as NSString).pathExtension.lowercased()
        if !validExtensions.contains(fileExtension) {
            sanitized += ".mp4"
        }

        return sanitized
    }

    private func generateUniqueFileName(for originalFileName: String, in directory: URL) -> String {
        let sanitizedName = sanitizeFileName(originalFileName)
        let baseName = (sanitizedName as NSString).deletingPathExtension
        let fileExtension = (sanitizedName as NSString).pathExtension

        var finalPath = directory.appendingPathComponent(sanitizedName)
        var counter = 1

        while FileManager.default.fileExists(atPath: finalPath.path) {
            let newFileName = "\(baseName)_\(counter).\(fileExtension)"
            finalPath = directory.appendingPathComponent(newFileName)
            counter += 1
        }

        return finalPath.lastPathComponent
    }
}
