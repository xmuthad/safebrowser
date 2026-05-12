import UIKit

class SecuritySettingsViewController: UIViewController {

    private var tableView: UITableView!
    private var settings: SecuritySettings!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localized.Security.title
        settings = SecurityPolicyManager.shared.getSettings()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

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
        SecurityPolicyManager.shared.updateSettings(settings)
        dismiss(animated: true)
    }
}

extension SecuritySettingsViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 3  // HTTPS, JavaScript, Private Mode
        case 1: return 3  // Ads, Trackers, Malicious
        case 2: return 1  // Clear Data
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return Localized.Security.connectionSection
        case 1: return Localized.Security.blockingSection
        case 2: return Localized.Security.privacySection
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return Localized.Security.connectionFooter
        case 1: return Localized.Security.blockingFooter
        case 2: return Localized.Security.privacyFooter
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.selectionStyle = .none

        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = Localized.Security.forceHTTPS
                cell.detailTextLabel?.text = Localized.Security.forceHTTPSDesc
                let toggle = UISwitch()
                toggle.isOn = settings.forceHTTPS
                toggle.tag = 0
                toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            case 1:
                cell.textLabel?.text = Localized.Security.allowJavaScript
                cell.detailTextLabel?.text = Localized.Security.allowJavaScriptDesc
                let toggle = UISwitch()
                toggle.isOn = settings.allowJavaScript
                toggle.tag = 1
                toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            case 2:
                cell.textLabel?.text = Localized.Security.privateMode
                cell.detailTextLabel?.text = Localized.Security.privateModeDesc
                let toggle = UISwitch()
                toggle.isOn = settings.privateBrowsing
                toggle.tag = 2
                toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            default: break
            }

        case 1:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = Localized.Security.blockAds
                cell.detailTextLabel?.text = Localized.Security.blockAdsDesc
                let toggle = UISwitch()
                toggle.isOn = settings.blockAds
                toggle.tag = 3
                toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            case 1:
                cell.textLabel?.text = Localized.Security.blockTrackers
                cell.detailTextLabel?.text = Localized.Security.blockTrackersDesc
                let toggle = UISwitch()
                toggle.isOn = settings.blockTrackers
                toggle.tag = 4
                toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            case 2:
                cell.textLabel?.text = Localized.Security.blockMalicious
                cell.detailTextLabel?.text = Localized.Security.blockMaliciousDesc
                let toggle = UISwitch()
                toggle.isOn = settings.blockMaliciousSites
                toggle.tag = 5
                toggle.addTarget(self, action: #selector(toggleChanged(_:)), for: .valueChanged)
                cell.accessoryView = toggle
            default: break
            }

        case 2:
            cell.textLabel?.text = Localized.Security.clearData
            cell.textLabel?.textColor = .systemRed
            cell.selectionStyle = .default

        default: break
        }

        return cell
    }

    @objc private func toggleChanged(_ sender: UISwitch) {
        switch sender.tag {
        case 0: settings.forceHTTPS = sender.isOn
        case 1: settings.allowJavaScript = sender.isOn
        case 2: settings.privateBrowsing = sender.isOn
        case 3: settings.blockAds = sender.isOn
        case 4: settings.blockTrackers = sender.isOn
        case 5: settings.blockMaliciousSites = sender.isOn
        default: break
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 2 && indexPath.row == 0 {
            showClearDataAlert()
        }
    }

    private func showClearDataAlert() {
        let alert = UIAlertController(
            title: Localized.Security.clearDataConfirm,
            message: Localized.Security.clearDataMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Localized.Security.clear, style: .destructive) { _ in
            SecurityPolicyManager.shared.clearBrowsingData()
            self.showSuccessAlert()
        })

        present(alert, animated: true)
    }

    private func showSuccessAlert() {
        let alert = UIAlertController(
            title: Localized.Security.cleared,
            message: Localized.Security.clearedMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Localized.Error.ok, style: .default))
        present(alert, animated: true)
    }
}

extension Localized {
    enum Security {
        static var title: String { NSLocalizedString("security.title", comment: "") }
        static var connectionSection: String { NSLocalizedString("security.connectionSection", comment: "") }
        static var blockingSection: String { NSLocalizedString("security.blockingSection", comment: "") }
        static var privacySection: String { NSLocalizedString("security.privacySection", comment: "") }
        static var forceHTTPS: String { NSLocalizedString("security.forceHTTPS", comment: "") }
        static var forceHTTPSDesc: String { NSLocalizedString("security.forceHTTPSDesc", comment: "") }
        static var allowJavaScript: String { NSLocalizedString("security.allowJavaScript", comment: "") }
        static var allowJavaScriptDesc: String { NSLocalizedString("security.allowJavaScriptDesc", comment: "") }
        static var privateMode: String { NSLocalizedString("security.privateMode", comment: "") }
        static var privateModeDesc: String { NSLocalizedString("security.privateModeDesc", comment: "") }
        static var blockAds: String { NSLocalizedString("security.blockAds", comment: "") }
        static var blockAdsDesc: String { NSLocalizedString("security.blockAdsDesc", comment: "") }
        static var blockTrackers: String { NSLocalizedString("security.blockTrackers", comment: "") }
        static var blockTrackersDesc: String { NSLocalizedString("security.blockTrackersDesc", comment: "") }
        static var blockMalicious: String { NSLocalizedString("security.blockMalicious", comment: "") }
        static var blockMaliciousDesc: String { NSLocalizedString("security.blockMaliciousDesc", comment: "") }
        static var clearData: String { NSLocalizedString("security.clearData", comment: "") }
        static var clearDataConfirm: String { NSLocalizedString("security.clearDataConfirm", comment: "") }
        static var clearDataMessage: String { NSLocalizedString("security.clearDataMessage", comment: "") }
        static var clear: String { NSLocalizedString("security.clear", comment: "") }
        static var cleared: String { NSLocalizedString("security.cleared", comment: "") }
        static var clearedMessage: String { NSLocalizedString("security.clearedMessage", comment: "") }
        static var connectionFooter: String { NSLocalizedString("security.connectionFooter", comment: "") }
        static var blockingFooter: String { NSLocalizedString("security.blockingFooter", comment: "") }
        static var privacyFooter: String { NSLocalizedString("security.privacyFooter", comment: "") }
    }
}
