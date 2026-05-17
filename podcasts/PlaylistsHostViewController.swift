import UIKit

class PlaylistsHostViewController: UIViewController {
    private var titleView: SegmentedTitleView?
    private var currentChild: UIViewController?

    private lazy var _playlistsViewController: PlaylistsViewController = PlaylistsViewController()
    private lazy var upNextViewController: UpNextViewController = UpNextViewController(source: .tabBar, showingInTab: true)

    /// Optional for API compatibility with callers that guard-let this property.
    var playlistsViewController: PlaylistsViewController? { _playlistsViewController }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let tv = SegmentedTitleView()
        tv.onSelect = { [weak self] segment in
            switch segment {
            case .playlists: self?.selectPlaylist()
            case .upNext:    self?.selectUpNext()
            }
        }
        navigationItem.titleView = tv
        titleView = tv

        showChild(_playlistsViewController)
    }

    // MARK: - Public API

    func selectPlaylist() {
        titleView?.setActive(.playlists)
        showChild(_playlistsViewController)
    }

    func selectUpNext() {
        titleView?.setActive(.upNext)
        showChild(upNextViewController)
    }

    // MARK: - Child management

    private func showChild(_ newChild: UIViewController) {
        guard newChild !== currentChild else { return }

        // Remove old child
        if let old = currentChild {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }

        // Clear stale bar buttons before child's viewDidLoad writes fresh ones
        navigationItem.leftBarButtonItem = nil
        navigationItem.rightBarButtonItem = nil

        // addChild before accessing view so parent is set when viewDidLoad fires
        addChild(newChild)
        newChild.loadViewIfNeeded()

        newChild.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newChild.view)
        NSLayoutConstraint.activate([
            newChild.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            newChild.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newChild.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            newChild.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        newChild.didMove(toParent: self)
        currentChild = newChild

        // Re-emit bar buttons for children whose viewDidLoad has already fired
        // (loadViewIfNeeded is a no-op on second and later swaps).
        if let pc = newChild as? PCViewController {
            pc.refreshRightButtons()
        }
        if let upNext = newChild as? UpNextViewController {
            upNext.updateNavBarButtons()
        }
    }
}
