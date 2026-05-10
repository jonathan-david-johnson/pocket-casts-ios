import UIKit
import PocketCastsServer

class FavoritesViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var rows: [(stationId: String, curated: CuratedStation?)] = []
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
                let resolved = favorites.map { fav in
                    (stationId: fav.station_id, curated: self.curatedById[fav.station_id])
                }
                await MainActor.run {
                    self.rows = resolved
                    self.tableView.reloadData()
                    if resolved.isEmpty { self.showEmptyState() }
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
        if let curated = row.curated {
            cell.configure(name: curated.name, city: curated.city, logoAsset: curated.logoAsset)
        } else {
            cell.configure(name: row.stationId, city: "", logoAsset: nil)
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
        Task {
            try? await RadioFavoritesManager.shared.removeFavorite(stationId: stationId)
        }
    }
}

extension FavoritesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = rows[indexPath.row]
        let station: RadioStation
        if let curated = row.curated {
            station = curated.toRadioStation()
        } else {
            station = RadioStation(stationId: row.stationId, name: row.stationId, streamUrl: "")
        }
        let detail = StationDetailViewController(station: station, curatedStation: row.curated)
        navigationController?.pushViewController(detail, animated: true)
    }
}
