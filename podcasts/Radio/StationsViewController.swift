import UIKit

class StationsViewController: UIViewController {
    private var stations: [CuratedStation] = []
    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        stations = CuratedStationsLoader.load()
        setupTableView()
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
}

extension StationsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        stations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RadioStationCell.reuseId, for: indexPath) as! RadioStationCell
        let s = stations[indexPath.row]
        cell.configure(name: s.name, city: s.city, logoAsset: s.logoAsset)
        return cell
    }
}

extension StationsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let s = stations[indexPath.row]
        let detail = StationDetailViewController(station: s.toRadioStation(), curatedStation: s)
        navigationController?.pushViewController(detail, animated: true)
    }
}
