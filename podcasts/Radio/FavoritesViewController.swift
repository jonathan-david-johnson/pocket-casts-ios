import UIKit
import PocketCastsServer

private struct FavoriteRow {
    let stationId: String
    var browse: RadioBrowserStation?

    var displayName: String {
        CuratedStationsLoader.enhancementsByUUID[stationId]?.name ?? browse?.name ?? stationId
    }
    var displayCity: String {
        guard let b = browse else { return "" }
        let state = b.state ?? ""
        let country = b.country ?? ""
        if state.isEmpty && country.isEmpty { return "" }
        if state.isEmpty { return country }
        if country.isEmpty { return state }
        return "\(state), \(country)"
    }
    var faviconUrl: String? {
        guard let b = browse, !(b.favicon ?? "").isEmpty else { return nil }
        return b.favicon
    }
    var logoAsset: String? {
        CuratedStationsLoader.enhancementsByUUID[stationId]?.logoAsset
    }

    func toRadioStation() -> RadioStation {
        if let b = browse { return b.toRadioStation() }
        return RadioStation(stationId: stationId, name: stationId, streamUrl: "")
    }
}

class FavoritesViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var rows: [FavoriteRow] = []
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
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let favorites = try await RadioFavoritesManager.shared.loadFavorites()
                var resolved = favorites.map { fav in
                    FavoriteRow(stationId: fav.station_id)
                }

                await MainActor.run {
                    self.rows = resolved
                    self.tableView.reloadData()
                    if resolved.isEmpty { self.showEmptyState() }
                }

                // Fetch radio-browser.info metadata for all favorited stations (all are radio-browser UUIDs).
                await withTaskGroup(of: (Int, RadioBrowserStation?).self) { group in
                    for i in resolved.indices {
                        let stationId = resolved[i].stationId
                        group.addTask {
                            let station = try? await RadioBrowserAPI.station(uuid: stationId)
                            return (i, station)
                        }
                    }
                    for await (i, station) in group {
                        resolved[i].browse = station
                    }
                }

                await MainActor.run {
                    self.rows = resolved
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run { self.showEmptyState() }
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
            cell.configure(name: row.displayName, city: row.displayCity, logoAsset: asset)
        } else {
            cell.configure(name: row.displayName, city: row.displayCity, faviconUrl: row.faviconUrl)
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
