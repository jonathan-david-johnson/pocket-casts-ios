import UIKit

class StationDetailViewController: SimpleNotificationsViewController {
    private let station: RadioStation

    private let logoView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.backgroundColor = AppTheme.colorForStyle(.primaryUi02)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let bitrateLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = AppTheme.colorForStyle(.primaryText02)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nowPlayingTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textAlignment = .center
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isHidden = true
        return l
    }()

    private let nowPlayingArtistLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = AppTheme.colorForStyle(.primaryText02)
        l.textAlignment = .center
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        l.isHidden = true
        return l
    }()

    private lazy var playButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Play"
        config.image = UIImage(systemName: "play.fill")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addAction(UIAction { [weak self] _ in self?.togglePlay() }, for: .touchUpInside)
        return btn
    }()

    private lazy var favoriteButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "Favorite"
        config.image = UIImage(systemName: "heart")
        config.imagePadding = 8
        config.cornerStyle = .capsule
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addAction(UIAction { [weak self] _ in self?.toggleFavorite() }, for: .touchUpInside)
        return btn
    }()

    // MARK: - Tracklist

    private let tracklistTable: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .singleLine
        tv.estimatedRowHeight = 76
        tv.rowHeight = UITableView.automaticDimension
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var entries: [TracklistEntry] = []
    private var icyTitle: String = ""
    private var icyArtist: String = ""
    private var pendingTracklistTask: Task<Void, Never>?

    private var hasAnyICY: Bool { !icyTitle.isEmpty }

    private var isFavorited = false
    private var favoriteLoadTask: Task<Void, Never>?

    init(station: RadioStation) {
        self.station = station
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = station.displayableTitle()
        applyTheme()
        setupLayout()
        updatePlayButton()

        if let asset = station.logoAsset, let image = UIImage(named: asset) {
            logoView.image = image
        } else {
            logoView.image = UIImage(systemName: "radio")
            logoView.tintColor = AppTheme.colorForStyle(.primaryIcon02)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Constants.Notifications.themeChanged, object: nil)
        nameLabel.text = station.displayableTitle()

        if let bitrate = station.bitrate {
            bitrateLabel.text = "\(bitrate) kbps"
            bitrateLabel.isHidden = false
        } else {
            bitrateLabel.isHidden = true
        }

        tracklistTable.register(TracklistCell.self, forCellReuseIdentifier: TracklistCell.reuseIdentifier)
        tracklistTable.dataSource = self
        tracklistTable.delegate = self
        tracklistTable.isHidden = (station.tracklistUrl == nil)

        if let cached = RadioTracklistService.shared.cached(stationId: station.uuid) {
            self.entries = Array(cached.prefix(5))
            self.tracklistTable.reloadData()
        }

        addCustomObserver(Constants.Notifications.playbackStarted, selector: #selector(playbackChanged))
        addCustomObserver(Constants.Notifications.playbackPaused, selector: #selector(playbackChanged))
        addCustomObserver(Constants.Notifications.playbackEnded, selector: #selector(playbackChanged))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNowPlayingChange(_:)),
            name: .radioStationNowPlayingDidChange,
            object: nil
        )

        loadFavoriteState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Reapply theme — user may have changed theme in Settings while this
        // VC was off-screen; the persistent themeChanged observer covers the
        // on-screen case.
        themeDidChange()
        if station.tracklistUrl != nil {
            Task { await refetchTracklist() }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        pendingTracklistTask?.cancel()
        pendingTracklistTask = nil
    }

    deinit {
        MainActor.assumeIsolated {
            pendingTracklistTask?.cancel()
            pendingTracklistTask = nil
        }
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        removeAllCustomObservers()
    }

    @objc private func themeDidChange() {
        applyTheme()
        logoView.backgroundColor = AppTheme.colorForStyle(.primaryUi02)
        bitrateLabel.textColor = AppTheme.colorForStyle(.primaryText02)
        nowPlayingArtistLabel.textColor = AppTheme.colorForStyle(.primaryText02)
        tracklistTable.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        tracklistTable.reloadData()
    }

    private func applyTheme() {
        view.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        tracklistTable.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        nameLabel.textColor = AppTheme.colorForStyle(.primaryText01)
        nowPlayingTitleLabel.textColor = AppTheme.colorForStyle(.primaryText01)
    }

    private func setupLayout() {
        let buttonStack = UIStackView(arrangedSubviews: [playButton, favoriteButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        // Layout: logo → name → ICY title → ICY artist → bitrate → buttons
        let mainStack = UIStackView(arrangedSubviews: [logoView, nameLabel, nowPlayingTitleLabel, nowPlayingArtistLabel, bitrateLabel, buttonStack])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.alignment = .center
        mainStack.setCustomSpacing(4, after: nameLabel)
        mainStack.setCustomSpacing(2, after: nowPlayingTitleLabel)
        mainStack.setCustomSpacing(12, after: nowPlayingArtistLabel)
        mainStack.setCustomSpacing(20, after: bitrateLabel)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)
        view.addSubview(tracklistTable)

        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 120),
            logoView.heightAnchor.constraint(equalToConstant: 120),

            buttonStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            tracklistTable.topAnchor.constraint(equalTo: mainStack.bottomAnchor, constant: 16),
            tracklistTable.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            tracklistTable.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            tracklistTable.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    @objc private func playbackChanged() {
        updatePlayButton()
    }

    @objc private func handleNowPlayingChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let info = notification.userInfo,
                  let stationId = info[RadioMetadataNotificationKey.stationId] as? String,
                  stationId == station.uuid else { return }
            let title = (info[RadioMetadataNotificationKey.title] as? String) ?? ""
            let artist = (info[RadioMetadataNotificationKey.artist] as? String) ?? ""
            self.icyTitle = title
            self.icyArtist = artist
            self.updateNowPlayingLabels()

            // Debounced tracklist refetch: cancel previous pending task, start a new one
            // that waits 2 seconds before fetching (coalesces rapid ICY frame bursts).
            self.pendingTracklistTask?.cancel()
            self.pendingTracklistTask = Task { [weak self] in
                do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                guard !Task.isCancelled, let self else { return }
                await self.refetchTracklist()
            }
        }
    }

    private func updateNowPlayingLabels() {
        let hasTitle = !icyTitle.isEmpty
        let hasArtist = !icyArtist.isEmpty
        nowPlayingTitleLabel.text = icyTitle
        nowPlayingTitleLabel.isHidden = !hasTitle
        nowPlayingArtistLabel.text = icyArtist
        nowPlayingArtistLabel.isHidden = !hasArtist
    }

    @MainActor
    private func refetchTracklist() async {
        guard let url = station.tracklistUrl, !url.isEmpty else { return }
        do {
            let fresh = try await RadioTracklistService.shared.fetch(stationId: station.uuid, url: url)
            self.entries = Array(fresh.prefix(5))
            self.tracklistTable.reloadData()
        } catch {
            // Surface one toast per session per station. The service tracks
            // the dedupe state itself.
            if RadioTracklistService.shared.shouldShowFailureToast(stationId: station.uuid) {
                Toast.show("Couldn't load tracklist for \(station.displayableTitle())")
            }
        }
    }

    private func updatePlayButton() {
        let isCurrentStation = PlaybackManager.shared.currentEpisode()?.uuid == station.uuid
        let playing = isCurrentStation && PlaybackManager.shared.playing()
        var config = playButton.configuration
        config?.title = playing ? "Pause" : "Play"
        config?.image = UIImage(systemName: playing ? "pause.fill" : "play.fill")
        playButton.configuration = config
    }

    private func togglePlay() {
        let isCurrentStation = PlaybackManager.shared.currentEpisode()?.uuid == station.uuid
        if isCurrentStation && PlaybackManager.shared.playing() {
            PlaybackManager.shared.pause()
        } else {
            RadioStationRegistry.shared.register(station)
            PlaybackManager.shared.load(episode: station, autoPlay: true, overrideUpNext: false)
        }
        updatePlayButton()
    }

    private func loadFavoriteState() {
        favoriteLoadTask = Task { [weak self] in
            guard let self else { return }
            let faved = (try? await RadioFavoritesManager.shared.isFavorite(stationId: station.stationId)) ?? false
            guard !Task.isCancelled else { return }
            await MainActor.run { self.setFavoriteUI(faved) }
        }
    }

    private func setFavoriteUI(_ favorited: Bool) {
        isFavorited = favorited
        var config = favoriteButton.configuration
        config?.image = UIImage(systemName: favorited ? "heart.fill" : "heart")
        config?.title = favorited ? "Favorited" : "Favorite"
        favoriteButton.configuration = config
    }

    private func toggleFavorite() {
        favoriteLoadTask?.cancel()
        let newState = !isFavorited
        setFavoriteUI(newState)
        Task {
            do {
                if newState {
                    try await RadioFavoritesManager.shared.addFavorite(stationId: station.stationId)
                } else {
                    try await RadioFavoritesManager.shared.removeFavorite(stationId: station.stationId)
                }
            } catch {
                await MainActor.run { self.setFavoriteUI(!newState) }
            }
        }
    }

}

// MARK: - UITableViewDataSource

extension StationDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TracklistCell.reuseIdentifier, for: indexPath) as! TracklistCell
        let fallback = logoView.image
        cell.configure(with: entries[indexPath.row], fallbackArt: fallback)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension StationDetailViewController: UITableViewDelegate {}
