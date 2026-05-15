import UIKit

class BookmarkViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {

    private var tableView: UITableView!
    private var searchBar: UISearchBar!
    private var emptyLabel: UILabel!

    private var bookmarks: [BookmarkEntry] = []
    private var filteredBookmarks: [BookmarkEntry] = []
    private var isSearching = false

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localized.Bookmark.title
        view.backgroundColor = .systemBackground

        setupNavigationBar()
        setupSearchBar()
        setupTableView()
        setupEmptyState()
        loadBookmarks()
    }

    private func setupNavigationBar() {
        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.leftBarButtonItem = closeButton
    }

    private func setupSearchBar() {
        searchBar = UISearchBar()
        searchBar.placeholder = Localized.Bookmark.searchPlaceholder
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
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(BookmarkCell.self, forCellReuseIdentifier: "BookmarkCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
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
        emptyLabel.text = Localized.Bookmark.empty
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

    private func loadBookmarks() {
        bookmarks = BookmarkManager.shared.allBookmarks
        filteredBookmarks = bookmarks
        updateUI()
    }

    private func updateUI() {
        let displayBookmarks = isSearching ? filteredBookmarks : bookmarks
        tableView.reloadData()
        emptyLabel.isHidden = !displayBookmarks.isEmpty
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredBookmarks.count : bookmarks.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BookmarkCell", for: indexPath) as! BookmarkCell
        let entries = isSearching ? filteredBookmarks : bookmarks
        let entry = entries[indexPath.row]
        cell.configure(with: entry, dateFormatter: dateFormatter)
        return cell
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let entries = isSearching ? filteredBookmarks : bookmarks
            let entry = entries[indexPath.row]
            BookmarkManager.shared.removeBookmark(id: entry.id)
            bookmarks.removeAll { $0.id == entry.id }
            filteredBookmarks.removeAll { $0.id == entry.id }
            tableView.deleteRows(at: [indexPath], with: .automatic)
            updateUI()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entries = isSearching ? filteredBookmarks : bookmarks
        let entry = entries[indexPath.row]

        NotificationCenter.default.post(
            name: .bookmarkSelected,
            object: nil,
            userInfo: ["url": entry.url]
        )

        dismiss(animated: true)
    }

    // MARK: - UISearchBarDelegate

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
            filteredBookmarks = bookmarks
        } else {
            isSearching = true
            filteredBookmarks = BookmarkManager.shared.searchBookmarks(query: searchText)
        }
        updateUI()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}

extension Notification.Name {
    static let bookmarkSelected = Notification.Name("bookmarkSelected")
}

// MARK: - BookmarkCell

class BookmarkCell: UITableViewCell {

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 1
        return label
    }()

    private let urlLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
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

        faviconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            faviconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            faviconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            faviconImageView.widthAnchor.constraint(equalToConstant: 24),
            faviconImageView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            urlLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    func configure(with entry: BookmarkEntry, dateFormatter: DateFormatter) {
        titleLabel.text = entry.displayTitle
        urlLabel.text = entry.url.host ?? entry.url.absoluteString

        if let faviconData = entry.favicon, let image = UIImage(data: faviconData) {
            faviconImageView.image = image
        } else {
            faviconImageView.image = UIImage(systemName: "star.fill")
            faviconImageView.tintColor = .systemYellow
        }

        accessoryType = .disclosureIndicator
    }
}
