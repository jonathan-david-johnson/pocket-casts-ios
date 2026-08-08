import UIKit
import PocketCastsServer

class FavoritesViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var rows: [CachedFavoriteStation] = []
    private var loadTask: Task<Void, Never>?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        setupTableView()
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Constants.Notifications.themeChanged, object: nil)
    }

    @objc private func themeDidChange() {
        applyTheme()
        tableView.reloadData()
    }

    private func applyTheme() {
        view.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        tableView.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadFavorites()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        loadTask?.cancel()
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(RadioStationCell.self, forCellReuseIdentifier: RadioStationCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 68
        // Permanent edit mode shows the reorder handle on every row (mirrors
        // UpNext's `upNextTable.isEditing = true` pattern). `editingStyle =
        // .none` (see `UITableViewDelegate` extension below) suppresses the
        // delete-style red handle — favourites are removed via the heart
        // toggle on the station detail page, not from this list.
        tableView.isEditing = true
        tableView.allowsSelectionDuringEditing = true
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func reloadFavorites() {
        guard ServerSettings.userId != nil else {
            showNotLoggedIn()
            return
        }
        tableView.backgroundView = nil

        // Cold-start-safe: render the last resolved snapshot immediately,
        // then refresh from Supabase + radio-browser in the background.
        let cached = RadioFavoritesCache.shared.snapshot()
        if !cached.isEmpty {
            rows = cached
            tableView.reloadData()
        }

        loadTask = Task { [weak self] in
            guard let self else { return }
            // Load saved lyric offsets in parallel (best-effort, no UI blocker).
            async let offsetsTask = RadioFavoritesManager.shared.fetchLyricOffsets()
            let resolved = await RadioFavoritesService.shared.resolvedFavorites()
            _ = await offsetsTask

            await MainActor.run {
                self.rows = resolved
                self.tableView.reloadData()
                if resolved.isEmpty { self.showEmptyState() }
            }
        }
    }

    private func showNotLoggedIn() {
        rows = []
        tableView.reloadData()
        tableView.backgroundView = makeLabel("Sign in to Pocket Casts to save favorites across devices.")
    }

    private func showEmptyState() {
        if rows.isEmpty {
            tableView.backgroundView = makeLabel("No favorites yet.\nTap ♥ on any station to save it here.")
        }
    }

    private func makeLabel(_ text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.textColor = AppTheme.colorForStyle(.primaryText02)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        return label
    }
}

extension FavoritesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RadioStationCell.reuseId, for: indexPath) as! RadioStationCell
        let row = rows[indexPath.row]
        if let asset = row.logoAsset {
            cell.configure(name: row.name, city: row.city ?? "", logoAsset: asset)
        } else {
            cell.configure(name: row.name, city: row.city ?? "", faviconUrl: row.faviconUrl)
        }
        return cell
    }

    // canEditRowAt must return true for the row to be reorderable in
    // permanent edit mode; editingStyle below suppresses the delete handle.
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool { rows.count > 1 }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else { return }
        let row = rows.remove(at: sourceIndexPath.row)
        rows.insert(row, at: destinationIndexPath.row)
        // Persist immediately. Order is local-only (UserDefaults keyed on
        // user id) per RadioFavoritesManager's contract — no Supabase round-
        // trip needed for reorder.
        RadioFavoritesManager.shared.setOrder(rows.map(\.stationId))
    }
}

extension FavoritesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        let detail = StationDetailViewController(station: row.toRadioStation())
        navigationController?.pushViewController(detail, animated: true)
    }

    // Suppress the red minus / delete handle that UITableView shows by
    // default in edit mode. Reorder handle remains because `canMoveRowAt`
    // returns true above.
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle { .none }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool { false }
}
