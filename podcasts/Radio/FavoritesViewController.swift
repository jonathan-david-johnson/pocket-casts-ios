import UIKit
import PocketCastsServer

private struct FavoriteRow {
    let stationId: String
    var curated: CuratedStation?
    var browse: RadioBrowserStation?

    var displayName: String { curated?.name ?? browse?.name ?? stationId }
    var displayCity: String {
        if let c = curated { return c.city }
        if let b = browse { return b.state.isEmpty ? b.country : "\(b.state), \(b.country)" }
        return ""
    }
    var faviconUrl: String? {
        guard let b = browse, !b.favicon.isEmpty else { return nil }
        return b.favicon
    }
    var logoAsset: String? { curated?.logoAsset }

    func toRadioStation() -> RadioStation {
        if let c = curated { return c.toRadioStation() }
        if let b = browse { return b.toRadioStation() }
        return RadioStation(stationId: stationId, name: stationId, streamUrl: "")
    }
}

class FavoritesViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var rows: [FavoriteRow] = []
    private let curatedById: [String: CuratedStation]
    private var loadTask: Task<Void, Never>?

    init() {
        curatedById = Dictionary(uniqueKeysWithValues: CuratedStationsLoader.load().map { ($0.id, $0) })
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTableView()
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
                    FavoriteRow(stationId: fav.station_id, curated: self.curatedById[fav.station_id])
                }

                await MainActor.run {
                    self.rows = resolved
                    self.tableView.reloadData()
                    if resolved.isEmpty { self.showEmptyState() }
                }

                // Fetch radio-browser.info data for non-curated stations
                let browseIndices = resolved.indices.filter { resolved[$0].curated == nil }
                await withTaskGroup(of: (Int, RadioBrowserStation?).self) { group in
                    for i in browseIndices {
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

                if !browseIndices.isEmpty {
                    await MainActor.run {
                        self.rows = resolved
                        self.tableView.reloadData()
                    }
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
        label.textColor = .secondaryLabel
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

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool { true }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let stationId = rows[indexPath.row].stationId
        rows.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        if rows.isEmpty { showEmptyState() }
        Task { try? await RadioFavoritesManager.shared.removeFavorite(stationId: stationId) }
    }
}

extension FavoritesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        let detail = StationDetailViewController(station: row.toRadioStation(), curatedStation: row.curated)
        navigationController?.pushViewController(detail, animated: true)
    }
}
