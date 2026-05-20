import UIKit

/// Root view controller for the Streams tab.
///
/// Mirrors the M5.1 PlaylistsHostViewController pattern:
/// - Installs a SegmentedTitleView (Favorites / Browse) as navigationItem.titleView.
/// - Hosts FavoritesViewController and BrowseViewController as plain child VCs
///   added directly to its own view (no inner UINavigationController per child).
/// - Routes children's bar buttons via effectiveNavigationItem (already in repo from
///   M5.1). Both child VCs are plain UIViewController subclasses that do not write
///   navigationItem.{left,right}BarButtonItem directly, so no bar-button routing is
///   needed for this milestone. If either child is later promoted to PCViewController,
///   refreshRightButtons() can be added to showChild(_:) exactly as in the playlists host.
///
/// Limitation: FavoritesViewController and BrowseViewController are plain UIViewController
/// subclasses (not PCViewController), so their navigationItem writes do not flow through
/// effectiveNavigationItem automatically. Neither child currently sets bar buttons, so
/// this is a no-op limitation for M6. See milestone "Risks / Edge cases" for the note.
class StreamsHostViewController: UIViewController {
    private var titleView: SegmentedTitleView?
    private var currentChild: UIViewController?

    private lazy var _favoritesViewController: FavoritesViewController = FavoritesViewController()
    private lazy var _browseViewController: BrowseViewController = BrowseViewController()

    /// Optional for API compatibility with callers that guard-let this property.
    var favoritesViewController: FavoritesViewController? { _favoritesViewController }

    override func viewDidLoad() {
        super.viewDidLoad()
        applyTheme()
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Constants.Notifications.themeChanged, object: nil)

        let tv = SegmentedTitleView(leading: .favorites, trailing: .browse)
        tv.onSelect = { [weak self] segment in
            switch segment {
            case .favorites:          self?.selectFavorites()
            case .browse:             self?.selectBrowse()
            case .playlists, .upNext: break
            }
        }
        navigationItem.titleView = tv
        titleView = tv

        showChild(_favoritesViewController)
    }

    // MARK: - Public API

    func selectFavorites() {
        titleView?.setActive(.favorites)
        showChild(_favoritesViewController)
    }

    func selectBrowse() {
        titleView?.setActive(.browse)
        showChild(_browseViewController)
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

        // Re-emit bar buttons for children that are PCViewController subclasses.
        // FavoritesViewController and BrowseViewController are plain UIViewController
        // subclasses in M6, so this block is currently a no-op.
        if let pc = newChild as? PCViewController {
            pc.refreshRightButtons()
        }
    }

    @objc private func themeDidChange() {
        applyTheme()
    }

    private func applyTheme() {
        view.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
    }
}
