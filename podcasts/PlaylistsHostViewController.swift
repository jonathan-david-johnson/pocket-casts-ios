import UIKit

class PlaylistsHostViewController: UIViewController {
    private let segmentedControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: [L10n.playlists, L10n.upNext])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let containerView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var playlistsNav: UINavigationController = {
        UINavigationController(rootViewController: PlaylistsViewController())
    }()

    private lazy var upNextNav: UINavigationController = {
        UINavigationController(rootViewController: UpNextViewController(source: .tabBar, showingInTab: true))
    }()

    private var currentChild: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        showChild(playlistsNav)
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
        case 0: showChild(playlistsNav)
        case 1: showChild(upNextNav)
        default: break
        }
    }

    func selectPlaylist() {
        segmentedControl.selectedSegmentIndex = 0
        showChild(playlistsNav)
    }

    func selectUpNext() {
        segmentedControl.selectedSegmentIndex = 1
        showChild(upNextNav)
    }

    var playlistsViewController: PlaylistsViewController? {
        playlistsNav.viewControllers.first as? PlaylistsViewController
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
}
