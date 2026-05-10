import UIKit

class StationDetailViewController: SimpleNotificationsViewController {
    private let station: RadioStation
    private let curatedStation: CuratedStation?

    private let logoView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemBackground
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

    private let cityLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
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

    private lazy var donateButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Donate to \(station.displayableTitle()) ↗"
        config.baseForegroundColor = .systemBlue
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addAction(UIAction { [weak self] _ in self?.openDonate() }, for: .touchUpInside)
        return btn
    }()

    private let nowPlayingSection: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 4
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let nowPlayingHeader: UILabel = {
        let l = UILabel()
        l.text = "NOW PLAYING"
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = .secondaryLabel
        return l
    }()

    private let trackTitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.numberOfLines = 2
        return l
    }()

    private let trackArtistLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = .secondaryLabel
        return l
    }()

    private var pollTimer: Timer?
    private var isFavorited = false
    private var favoriteLoadTask: Task<Void, Never>?

    init(station: RadioStation, curatedStation: CuratedStation? = nil) {
        self.station = station
        self.curatedStation = curatedStation
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = station.displayableTitle()
        view.backgroundColor = .systemBackground
        setupLayout()
        updatePlayButton()

        if let asset = curatedStation?.logoAsset, let image = UIImage(named: asset) {
            logoView.image = image
        } else {
            logoView.image = UIImage(systemName: "radio")
            logoView.tintColor = .secondaryLabel
        }
        nameLabel.text = station.displayableTitle()
        cityLabel.text = station.city

        if station.tracklistUrl != nil {
            setupNowPlayingSection()
            pollTracklist()
        }

        addCustomObserver(Constants.Notifications.playbackStarted, selector: #selector(playbackChanged))
        addCustomObserver(Constants.Notifications.playbackPaused, selector: #selector(playbackChanged))
        addCustomObserver(Constants.Notifications.playbackEnded, selector: #selector(playbackChanged))
        loadFavoriteState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if station.tracklistUrl != nil {
            pollTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.pollTracklist()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pollTimer?.invalidate()
        pollTimer = nil
        removeAllCustomObservers()
    }

    private func setupLayout() {
        let buttonStack = UIStackView(arrangedSubviews: [playButton, favoriteButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let mainStack = UIStackView(arrangedSubviews: [logoView, nameLabel, cityLabel, buttonStack, donateButton])
        mainStack.axis = .vertical
        mainStack.spacing = 12
        mainStack.alignment = .center
        mainStack.setCustomSpacing(20, after: cityLabel)
        mainStack.setCustomSpacing(8, after: buttonStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)
        view.addSubview(nowPlayingSection)

        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 120),
            logoView.heightAnchor.constraint(equalToConstant: 120),

            buttonStack.widthAnchor.constraint(equalTo: mainStack.widthAnchor),

            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            nowPlayingSection.topAnchor.constraint(equalTo: mainStack.bottomAnchor, constant: 32),
            nowPlayingSection.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nowPlayingSection.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func setupNowPlayingSection() {
        nowPlayingSection.addArrangedSubview(nowPlayingHeader)
        nowPlayingSection.addArrangedSubview(trackTitleLabel)
        nowPlayingSection.addArrangedSubview(trackArtistLabel)
    }

    @objc private func playbackChanged() {
        updatePlayButton()
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

    private func openDonate() {
        guard let urlString = station.donateUrl, let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func pollTracklist() {
        guard let urlString = station.tracklistUrl, let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data else { return }
            DispatchQueue.main.async { self.parseTracklist(data: data, stationId: self.station.stationId) }
        }.resume()
    }

    private func parseTracklist(data: Data, stationId: String) {
        switch stationId {
        case "kcrw":
            parseKCRW(data: data)
        case "kexp":
            parseKEXP(data: data)
        default:
            break
        }
    }

    private func parseKCRW(data: Data) {
        struct KCRWResponse: Decodable {
            struct Track: Decodable { let title: String; let artist: String }
            let results: [Track]
        }
        guard let response = try? JSONDecoder().decode(KCRWResponse.self, from: data),
              let track = response.results.first else { return }
        trackTitleLabel.text = track.title
        trackArtistLabel.text = track.artist
    }

    private func parseKEXP(data: Data) {
        struct KEXPResponse: Decodable {
            struct Play: Decodable {
                let play_type: String
                let song: String?
                let artist: String?
            }
            let results: [Play]
        }
        guard let response = try? JSONDecoder().decode(KEXPResponse.self, from: data) else { return }
        if let track = response.results.first(where: { $0.play_type == "trackplay" }) {
            trackTitleLabel.text = track.song ?? ""
            trackArtistLabel.text = track.artist ?? ""
        }
    }
}
