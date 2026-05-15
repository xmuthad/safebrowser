import UIKit

class PerformanceSettingsViewController: UIViewController {

    private var tableView: UITableView!
    private var performanceReport: PerformanceReport!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localized.Performance.title
        view.backgroundColor = .systemBackground
        setupUI()
        loadPerformanceData()
    }

    private func setupUI() {
        tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    private func loadPerformanceData() {
        performanceReport = PerformanceMonitor.shared.getPerformanceReport()
        tableView.reloadData()
    }

    @objc private func clearCachesTapped() {
        let alert = UIAlertController(
            title: Localized.Performance.clearCaches,
            message: Localized.Performance.clearCachesMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Localized.Performance.clearCaches, style: .destructive) { _ in
            PerformanceMonitor.shared.clearCaches()
            self.showSuccessAlert()
        })

        present(alert, animated: true)
    }

    private func showSuccessAlert() {
        let alert = UIAlertController(
            title: Localized.Performance.cleared,
            message: Localized.Performance.clearedMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Localized.Error.ok, style: .default) { _ in
            self.loadPerformanceData()
        })
        present(alert, animated: true)
    }

    @objc private func resetStatisticsTapped() {
        let alert = UIAlertController(
            title: Localized.Performance.resetStats,
            message: Localized.Performance.resetStatsMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Localized.Performance.reset, style: .destructive) { _ in
            PerformanceMonitor.shared.resetStatistics()
            self.loadPerformanceData()
            self.showSuccessAlert()
        })

        present(alert, animated: true)
    }
}

extension PerformanceSettingsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3  // Memory, Page Load, Status
        case 1: return 1  // Actions
        case 2: return 1  // Tips
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return Localized.Performance.currentStatus
        case 1: return Localized.Performance.actions
        case 2: return Localized.Performance.tips
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 1: return Localized.Performance.actionsFooter
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)

        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = Localized.Performance.memoryUsage
                cell.detailTextLabel?.text = String(format: "%.1f MB", performanceReport.memoryUsageMB)
                cell.imageView?.image = UIImage(systemName: "memorychip")
                cell.selectionStyle = .none
            case 1:
                cell.textLabel?.text = Localized.Performance.avgLoadTime
                cell.detailTextLabel?.text = String(format: "%.0f ms", performanceReport.averagePageLoadTimeMs)
                cell.imageView?.image = UIImage(systemName: "speedometer")
                cell.selectionStyle = .none
            case 2:
                cell.textLabel?.text = Localized.Performance.status
                cell.detailTextLabel?.text = performanceReport.isOptimized ?
                    Localized.Performance.statusGood : Localized.Performance.statusPoor
                cell.detailTextLabel?.textColor = performanceReport.isOptimized ? .systemGreen : .systemOrange
                cell.imageView?.image = UIImage(systemName: "checkmark.circle")
                cell.selectionStyle = .none
            default: break
            }

        case 1:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = Localized.Performance.clearCaches
                cell.textLabel?.textColor = .systemBlue
                cell.imageView?.image = UIImage(systemName: "trash")
                cell.accessoryType = .disclosureIndicator
            default: break
            }

        case 2:
            cell.textLabel?.text = Localized.Performance.tip1
            cell.textLabel?.numberOfLines = 0
            cell.textLabel?.font = .systemFont(ofSize: 13)
            cell.selectionStyle = .none
            cell.textLabel?.textColor = .secondaryLabel

        default: break
        }

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 1 && indexPath.row == 0 {
            showClearOptions()
        }
    }

    private func showClearOptions() {
        let alert = UIAlertController(
            title: Localized.Performance.clearOptions,
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: Localized.Performance.clearCaches, style: .destructive) { _ in
            self.clearCachesTapped()
        })

        alert.addAction(UIAlertAction(title: Localized.Performance.resetStats, style: .destructive) { _ in
            self.resetStatisticsTapped()
        })

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }

        present(alert, animated: true)
    }
}

extension Localized {
    enum Performance {
        static var title: String { NSLocalizedString("performance.title", comment: "") }
        static var currentStatus: String { NSLocalizedString("performance.currentStatus", comment: "") }
        static var actions: String { NSLocalizedString("performance.actions", comment: "") }
        static var tips: String { NSLocalizedString("performance.tips", comment: "") }
        static var memoryUsage: String { NSLocalizedString("performance.memoryUsage", comment: "") }
        static var avgLoadTime: String { NSLocalizedString("performance.avgLoadTime", comment: "") }
        static var status: String { NSLocalizedString("performance.status", comment: "") }
        static var statusGood: String { NSLocalizedString("performance.statusGood", comment: "") }
        static var statusPoor: String { NSLocalizedString("performance.statusPoor", comment: "") }
        static var clearCaches: String { NSLocalizedString("performance.clearCaches", comment: "") }
        static var clearCachesMessage: String { NSLocalizedString("performance.clearCachesMessage", comment: "") }
        static var cleared: String { NSLocalizedString("performance.cleared", comment: "") }
        static var clearedMessage: String { NSLocalizedString("performance.clearedMessage", comment: "") }
        static var resetStats: String { NSLocalizedString("performance.resetStats", comment: "") }
        static var resetStatsMessage: String { NSLocalizedString("performance.resetStatsMessage", comment: "") }
        static var reset: String { NSLocalizedString("performance.reset", comment: "") }
        static var clearOptions: String { NSLocalizedString("performance.clearOptions", comment: "") }
        static var actionsFooter: String { NSLocalizedString("performance.actionsFooter", comment: "") }
        static var tip1: String { NSLocalizedString("performance.tip1", comment: "") }
    }
}
