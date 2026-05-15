import UIKit

extension Notification.Name {
    static let historyEntrySelected = Notification.Name("historyEntrySelected")
}

enum HistorySection {
    case today
    case yesterday
    case thisWeek
    case earlier

    var title: String {
        switch self {
        case .today: return Localized.History.today
        case .yesterday: return Localized.History.yesterday
        case .thisWeek: return Localized.History.thisWeek
        case .earlier: return Localized.History.earlier
        }
    }
}

struct HistoryGroup {
    let section: HistorySection
    var entries: [HistoryEntry]
}

class HistoryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    private var tableView: UITableView!
    private var searchBar: UISearchBar!
    private var emptyLabel: UILabel!
    private var clearButton: UIBarButtonItem!

    private var historyGroups: [HistoryGroup] = []
    private var filteredGroups: [HistoryGroup] = []
    private var isSearching = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let calendar = Calendar.current

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localized.History.title
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupSearchBar()
        setupTableView()
        setupEmptyState()
        loadHistory()
    }

    private func setupNavigationBar() {
        clearButton = UIBarButtonItem(
            title: Localized.History.clear,
            style: .plain,
            target: self,
            action: #selector(clearHistoryTapped)
        )
        clearButton.tintColor = .systemRed

        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )

        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItem = clearButton
    }

    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.placeholder = Localized.History.searchPlaceholder
        searchBar.delegate = self
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        view.addSubview(searchBar)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(HistoryCell.self, forCellReuseIdentifier: "HistoryCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 70
        tableView.sectionHeaderTopPadding = 0
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        emptyLabel = UILabel()
        emptyLabel.text = Localized.History.empty
        emptyLabel.textAlignment = .center
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .systemFont(ofSize: 17)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.isHidden = true
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func loadHistory() {
        let entries = HistoryManager.shared.getHistory()
        historyGroups = groupEntriesByDate(entries)
        filteredGroups = historyGroups
        updateUI()
    }

    private func groupEntriesByDate(_ entries: [HistoryEntry]) -> [HistoryGroup] {
        var todayEntries: [HistoryEntry] = []
        var yesterdayEntries: [HistoryEntry] = []
        var thisWeekEntries: [HistoryEntry] = []
        var earlierEntries: [HistoryEntry] = []

        let now = Date()

        for entry in entries {
            if calendar.isDateInToday(entry.timestamp) {
                todayEntries.append(entry)
            } else if calendar.isDateInYesterday(entry.timestamp) {
                yesterdayEntries.append(entry)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      entry.timestamp > weekAgo {
                thisWeekEntries.append(entry)
            } else {
                earlierEntries.append(entry)
            }
        }

        var groups: [HistoryGroup] = []
        if !todayEntries.isEmpty {
            groups.append(HistoryGroup(section: .today, entries: todayEntries))
        }
        if !yesterdayEntries.isEmpty {
            groups.append(HistoryGroup(section: .yesterday, entries: yesterdayEntries))
        }
        if !thisWeekEntries.isEmpty {
            groups.append(HistoryGroup(section: .thisWeek, entries: thisWeekEntries))
        }
        if !earlierEntries.isEmpty {
            groups.append(HistoryGroup(section: .earlier, entries: earlierEntries))
        }

        return groups
    }

    private func updateUI() {
        let groups = isSearching ? filteredGroups : historyGroups
        let totalEntries = groups.reduce(0) { $0 + $1.entries.count }
        tableView.reloadData()
        emptyLabel.isHidden = totalEntries > 0
        clearButton.isEnabled = totalEntries > 0
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func clearHistoryTapped() {
        let alert = UIAlertController(
            title: Localized.History.clearConfirm,
            message: Localized.History.clearConfirmMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: Localized.Error.cancel, style: .cancel))
        alert.addAction(UIAlertAction(title: Localized.History.clear, style: .destructive) { [weak self] _ in
            HistoryManager.shared.clearHistory()
            self?.historyGroups.removeAll()
            self?.filteredGroups.removeAll()
            self?.updateUI()
        })

        present(alert, animated: true)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return isSearching ? filteredGroups.count : historyGroups.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let groups = isSearching ? filteredGroups : historyGroups
        return groups[section].entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath) as! HistoryCell
        let groups = isSearching ? filteredGroups : historyGroups
        let entry = groups[indexPath.section].entries[indexPath.row]
        cell.configure(with: entry, dateFormatter: dateFormatter)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let groups = isSearching ? filteredGroups : historyGroups
        return groups[section].section.title
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let groups = isSearching ? filteredGroups : historyGroups
            let entry = groups[indexPath.section].entries[indexPath.row]

            HistoryManager.shared.deleteEntry(url: entry.url)

            if isSearching {
                filteredGroups[indexPath.section].entries.remove(at: indexPath.row)
                if filteredGroups[indexPath.section].entries.isEmpty {
                    filteredGroups.remove(at: indexPath.section)
                }
            }

            historyGroups[indexPath.section].entries.remove(at: indexPath.row)
            if historyGroups[indexPath.section].entries.isEmpty {
                historyGroups.remove(at: indexPath.section)
            }

            tableView.deleteRows(at: [indexPath], with: .automatic)
            updateUI()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let groups = isSearching ? filteredGroups : historyGroups
        let entry = groups[indexPath.section].entries[indexPath.row]

        NotificationCenter.default.post(
            name: .historyEntrySelected,
            object: nil,
            userInfo: ["url": entry.url]
        )

        dismiss(animated: true)
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredGroups = historyGroups
        } else {
            isSearching = true
            let results = HistoryManager.shared.searchHistory(query: searchText)
            filteredGroups = groupEntriesByDate(results)
        }
        updateUI()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

// MARK: - HistoryCell

class HistoryCell: UITableViewCell {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 2
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()

    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        return label
    }()

    private let faviconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 4
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray5
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(faviconImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(urlLabel)
        contentView.addSubview(dateLabel)

        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            faviconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            faviconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            faviconImageView.widthAnchor.constraint(equalToConstant: 32),
            faviconImageView.heightAnchor.constraint(equalToConstant: 32),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            dateLabel.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 2),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(with entry: HistoryEntry, dateFormatter: DateFormatter) {
        titleLabel.text = entry.displayTitle
        urlLabel.text = entry.url.host ?? entry.url.absoluteString
        dateLabel.text = dateFormatter.string(from: entry.timestamp)

        if let faviconData = entry.favicon, let image = UIImage(data: faviconData) {
            faviconImageView.image = image
        } else {
            faviconImageView.image = UIImage(systemName: "globe")
            faviconImageView.tintColor = .systemGray
        }

        accessoryType = .disclosureIndicator
    }
}
