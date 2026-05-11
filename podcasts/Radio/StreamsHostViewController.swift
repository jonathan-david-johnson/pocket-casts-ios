import UIKit

class StreamsHostViewController: UIViewController {
    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Stations", "Favorites", "Browse"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let containerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var stationsNavController: UINavigationController = {
        UINavigationController(rootViewController: StationsViewController())
    }()

    private lazy var favoritesNavController: UINavigationController = {
        UINavigationController(rootViewController: FavoritesViewController())
    }()

    private lazy var browseNavController: UINavigationController = {
        UINavigationController(rootViewController: BrowseViewController())
    }()

    private var currentChild: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Streams"
        view.backgroundColor = .systemBackground
        setupLayout()
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        showChild(stationsNavController)
    }

    private func setupLayout() {
        view.addSubview(segmentedControl)
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            containerView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func segmentChanged() {
        switch segmentedControl.selectedSegmentIndex {
        case 0: showChild(stationsNavController)
        case 1: showChild(favoritesNavController)
        case 2: showChild(browseNavController)
        default: break
        }
    }

    private func showChild(_ newChild: UIViewController) {
        if let old = currentChild {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }
        addChild(newChild)
        newChild.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(newChild.view)
        NSLayoutConstraint.activate([
            newChild.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            newChild.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            newChild.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            newChild.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        newChild.didMove(toParent: self)
        currentChild = newChild
    }

    private func makePlaceholder(message: String) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = message
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -32)
        ])
        return vc
    }
}
