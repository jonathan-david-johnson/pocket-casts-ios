import UIKit

class BrowseViewController: UIViewController {
    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search stations..."
        sb.searchBarStyle = .minimal
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var stations: [RadioBrowserStation] = []
    private var searchTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var isShowingTopStations = true

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        setupLayout()
        loadTopStations()
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchTask?.cancel()
        loadTask?.cancel()
    }

    private func setupLayout() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(RadioStationCell.self, forCellReuseIdentifier: RadioStationCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 68
        tableView.keyboardDismissMode = .onDrag
        searchBar.delegate = self

        view.addSubview(searchBar)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadTopStations() {
        showMessage("Loading...")
        loadTask = Task { [weak self] in
            do {
                let results = try await RadioBrowserAPI.topStations()
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.stations = results
                    self?.isShowingTopStations = true
                    self?.tableView.backgroundView = nil
                    self?.tableView.reloadData()
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.showMessage("Couldn't reach station directory. Check your connection.", retry: true)
                }
            }
        }
    }

    private func search(query: String) async {
        do {
            let results = try await RadioBrowserAPI.search(query: query)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.stations = results
                self.isShowingTopStations = false
                if results.isEmpty {
                    self.showMessage("No stations found for \"\(query)\"")
                } else {
                    self.tableView.backgroundView = nil
                }
                self.tableView.reloadData()
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.showMessage("Couldn't reach station directory. Check your connection.", retry: true)
            }
        }
    }

    private func showMessage(_ text: String, retry: Bool = false) {
        stations = []
        tableView.reloadData()
        let container = UIView()
        let label = UILabel()
        label.text = text
        label.textColor = AppTheme.colorForStyle(.primaryText02)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 15)
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: -40),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -32)
        ])
        if retry {
            let btn = UIButton(type: .system)
            btn.setTitle("Retry", for: .normal)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.addAction(UIAction { [weak self] _ in self?.loadTopStations() }, for: .touchUpInside)
            container.addSubview(btn)
            NSLayoutConstraint.activate([
                btn.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
                btn.centerXAnchor.constraint(equalTo: container.centerXAnchor)
            ])
        }
        tableView.backgroundView = container
    }
}

extension BrowseViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchTask?.cancel()
        guard searchText.count >= 2 else {
            if searchText.isEmpty { loadTopStations() }
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.search(query: searchText)
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        loadTopStations()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        if searchBar.text?.isEmpty ?? true {
            searchBar.setShowsCancelButton(false, animated: true)
        }
    }
}

extension BrowseViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RadioStationCell.reuseId, for: indexPath) as! RadioStationCell
        let s = stations[indexPath.row]
        let state = s.state ?? ""
        let country = s.country ?? ""
        let city: String
        if state.isEmpty && country.isEmpty { city = "" }
        else if state.isEmpty { city = country }
        else if country.isEmpty { city = state }
        else { city = "\(state), \(country)" }
        cell.configure(name: s.name, city: city, faviconUrl: (s.favicon ?? "").isEmpty ? nil : s.favicon)
        return cell
    }
}

extension BrowseViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let s = stations[indexPath.row]
        let detail = StationDetailViewController(station: s.toRadioStation())
        navigationController?.pushViewController(detail, animated: true)
    }
}
