import Foundation
import PocketCastsDataModel
import PocketCastsServer
import PocketCastsUtils
import UIKit
import Kingfisher

class MiniPlayerViewController: SimpleNotificationsViewController {
    enum PlayerOpenState {
        case closed, beingDragged, open, animating
    }

    var playerOpenState = PlayerOpenState.closed

    @IBOutlet var playPauseBtn: PlayPauseButton!
    @IBOutlet var skipBackBtn: UIButton!
    @IBOutlet var skipFwdBtn: UIButton!

    @IBOutlet var skipBackBtnWidthConstraint: NSLayoutConstraint!
    @IBOutlet var playPauseBtnWidthConstraint: NSLayoutConstraint!
    @IBOutlet var skipFwdBtnWidthConstraint: NSLayoutConstraint!

    @IBOutlet var upNextBtn: UpNextButton!

    @IBOutlet var playbackProgressView: ProgressLine!

    @IBOutlet var podcastArtwork: PodcastImageView!
    @IBOutlet var podcastArtworkWidthConstraint: NSLayoutConstraint!
    @IBOutlet var podcastArtworkHeightConstraint: NSLayoutConstraint!
    @IBOutlet var mainView: UIView!
    @IBOutlet var shadowView: UIView!

    @IBOutlet var gradientView: MiniPlayerGradientView!

    private var lastEpisodeUuidImageLoaded = ""
    private var lastEpisodeUuidAutoOpened = ""
    var fullScreenPlayer: PlayerContainerViewController?

    /// Carries the upward pan velocity from the open-gesture recognizer to
    /// the transition delegate so the present animation can match the flick's
    /// momentum. Negative = upward (the gesture direction). Reset to 0 after
    /// the delegate consumes it so a subsequent tap-driven open starts at rest.
    var pendingPresentVelocity: CGFloat = 0

    var panUpRecognizer: UIPanGestureRecognizer!
    var longPressRecognizer: UILongPressGestureRecognizer!

    var heightConstraint: NSLayoutConstraint?

    var upNextViewController: UpNextViewController?

    private let analyticsPlaybackHelper = AnalyticsPlaybackHelper.shared

    private var episodeTitleLabel: MiniPlayerScrollingTitleView?
    private var episodeTimeLeftLabel: UILabel?
    private var glassProgressView: MiniPlayerGlassProgressView?

    private var glassButtonStack: UIStackView?
    private var accessoryEnvironmentConstraints: [NSLayoutConstraint] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        addGestureRecognizers()

        view.isHidden = false

        if FeatureFlag.liquidGlass.enabled, #available(iOS 26.0, *) {
            setupLiquidGlassLayout()
        } else {
            setupCorners()
        }
        addUINotificationObservers()
        playbackStateDidChange()
        themeChanged()
    }

    private func setupCorners() {
        mainView.layer.cornerRadius = MiniPlayerShadowView.Constants.shadowCornerRadius
        mainView.layer.masksToBounds = true
    }

    @available(iOS 26.0, *)
    private func setupLiquidGlassLayout() {
        gradientView.isHidden = true
        shadowView.isHidden = true
        mainView.isHidden = true
        playbackProgressView.isHidden = true
        upNextBtn.isHidden = true

        view.backgroundColor = .clear

        podcastArtwork.removeFromSuperview()
        skipBackBtn.removeFromSuperview()
        playPauseBtn.removeFromSuperview()
        skipFwdBtn.removeFromSuperview()

        podcastArtworkWidthConstraint.constant = 32
        podcastArtworkHeightConstraint.constant = 32

        podcastArtwork.translatesAutoresizingMaskIntoConstraints = false
        skipBackBtn.translatesAutoresizingMaskIntoConstraints = false
        playPauseBtn.translatesAutoresizingMaskIntoConstraints = false
        skipFwdBtn.translatesAutoresizingMaskIntoConstraints = false

        podcastArtwork.layer.cornerRadius = 6
        podcastArtwork.layer.masksToBounds = true

        playPauseBtn.visualSize = 28

        let title = MiniPlayerScrollingTitleView()
        title.translatesAutoresizingMaskIntoConstraints = false
        title.font = .font(ofSize: 13, weight: .medium, scalingWith: .subheadline)
        episodeTitleLabel = title

        let timeLeft = UILabel()
        timeLeft.translatesAutoresizingMaskIntoConstraints = false
        timeLeft.font = .font(ofSize: 10, weight: .regular, scalingWith: .footnote)
        timeLeft.numberOfLines = 1
        timeLeft.adjustsFontForContentSizeCategory = false
        episodeTimeLeftLabel = timeLeft

        let progressView = MiniPlayerGlassProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        glassProgressView = progressView

        let bottomRow = UIStackView(arrangedSubviews: [progressView, timeLeft])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center
        bottomRow.spacing = 8

        let textStack = UIStackView(arrangedSubviews: [title, bottomRow])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let buttonStack = UIStackView(arrangedSubviews: [skipBackBtn, playPauseBtn, skipFwdBtn])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.alignment = .center
        glassButtonStack = buttonStack

        view.addSubview(podcastArtwork)
        view.addSubview(textStack)
        view.addSubview(buttonStack)

        NSLayoutConstraint.activate([
            podcastArtwork.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            podcastArtwork.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: podcastArtwork.trailingAnchor, constant: 10),
            textStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: buttonStack.leadingAnchor, constant: 2),

            progressView.heightAnchor.constraint(equalToConstant: 5),

            buttonStack.topAnchor.constraint(equalTo: view.topAnchor),
            buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: 56),
        ])

        view.registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { (view: UIView, _) in
            view.setNeedsUpdateConstraints()
        }
    }

    override func updateViewConstraints() {
        if #available(iOS 26.0, *), let glassButtonStack, let glassProgressView {
            let isInline = view.traitCollection.tabAccessoryEnvironment == .inline
            let buttonWidth: CGFloat = isInline ? 40 : 44
            skipBackBtnWidthConstraint.constant = buttonWidth
            playPauseBtnWidthConstraint.constant = buttonWidth
            skipFwdBtnWidthConstraint.constant = buttonWidth

            NSLayoutConstraint.deactivate(accessoryEnvironmentConstraints)
            accessoryEnvironmentConstraints = [
                glassProgressView.widthAnchor.constraint(equalToConstant: isInline ? 34 : 40),
                glassButtonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: isInline ? -4 : -8),
            ]
            NSLayoutConstraint.activate(accessoryEnvironmentConstraints)
        }
        super.updateViewConstraints()
    }

    deinit {
        removeAllCustomObservers()
    }

    @IBAction func playPauseTapped(_ sender: Any) {
        analyticsPlaybackHelper.currentSource = analyticsSource
        HapticsHelper.triggerPlayPauseHaptic()
        PlaybackManager.shared.playPause()
    }

    @IBAction func upNextTapped(_ sender: Any) {
        showUpNext(from: .miniPlayer)
    }

    @IBAction func skipBackTapped(_ sender: Any) {
        analyticsPlaybackHelper.currentSource = analyticsSource

        if PlaybackManager.shared.shouldUseMuteControls() {
            PlaybackManager.shared.toggleMute()
            updateSkipMuteSwap()
            return
        }

        HapticsHelper.triggerSkipBackHaptic()
        PlaybackManager.shared.skipBack()
        animateSkipButton(skipBackBtn, clockwise: false)
    }

    @IBAction func skipForwardTapped(_ sender: Any) {
        analyticsPlaybackHelper.currentSource = analyticsSource

        #if !APPCLIP
        if PlaybackManager.shared.shouldUseMuteControls() {
            presentStationDetailIfPossible()
            return
        }
        #endif

        HapticsHelper.triggerSkipForwardHaptic()
        PlaybackManager.shared.skipForward()
        animateSkipButton(skipFwdBtn, clockwise: true)
    }

    #if !APPCLIP
    private func presentStationDetailIfPossible() {
        guard let station = PlaybackManager.shared.liveStation() else { return }
        let detail = StationDetailViewController(station: station)
        let nav = SJUIUtils.navController(for: detail, iconStyle: .secondaryText01, themeOverride: nil)
        let presenter = view.window?.rootViewController?.presentedViewController ?? view.window?.rootViewController
        presenter?.present(nav, animated: true, completion: nil)
    }
    #endif

    // MARK: - Live radio: skip → mute/stop swap

    @objc private func muteStateChanged() {
        updateSkipMuteSwap()
    }

    /// Mirrors `NowPlayingPlayerItemViewController.updateSkipMuteSwap()` for the
    /// mini player: when a `RadioStation` is current, the skip buttons become mute
    /// + stop. The mini-player buttons are plain `UIButton`s (no Lottie chrome) so
    /// we only need to swap the image + accessibility label.
    func updateSkipMuteSwap() {
        let isRadio = PlaybackManager.shared.shouldUseMuteControls()

        // Right slot for radio: Station Tracklist icon (music.note.list). Tap
        // routed to `presentStationDetailIfPossible`. Stop only on lock screen.
        skipFwdBtn.isUserInteractionEnabled = true
        if isRadio {
            let muteName = PlaybackManager.shared.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
            skipBackBtn.setImage(UIImage(systemName: muteName), for: .normal)
            skipBackBtn.accessibilityLabel = PlaybackManager.shared.isMuted ? L10n.accessibilityPlayerUnmute : L10n.accessibilityPlayerMute

            skipFwdBtn.setImage(UIImage(systemName: "music.note.list"), for: .normal)
            skipFwdBtn.accessibilityLabel = "Station tracklist"
        } else {
            // Restore the XIB-supplied images by clearing our overrides isn't possible
            // (the XIB images aren't accessible after `setImage(nil)`), so we look them
            // up from the asset catalog by name to match the original mini-player look.
            skipBackBtn.setImage(UIImage(named: "miniplayer-skip-backward"), for: .normal)
            skipBackBtn.accessibilityLabel = L10n.skipBack
            skipFwdBtn.setImage(UIImage(named: "miniplayer-skip-forward"), for: .normal)
            skipFwdBtn.accessibilityLabel = L10n.skipForward
        }
    }

    private func animateSkipButton(_ button: UIButton, clockwise: Bool) {
        guard let imageView = button.imageView else { return }

        if UIAccessibility.isReduceMotionEnabled {
            let alpha = CAKeyframeAnimation(keyPath: "opacity")
            alpha.values = [1.0, 0.4, 1.0]
            alpha.keyTimes = [0, 0.4, 1]
            alpha.duration = 0.3
            imageView.layer.add(alpha, forKey: "skipAlpha")
            return
        }

        let duration: CFTimeInterval = 0.7

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = clockwise ? CGFloat.pi * 2 : -CGFloat.pi * 2
        rotation.duration = duration
        rotation.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1.0)
        imageView.layer.add(rotation, forKey: "skipRotation")

        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [1.0, 0.85, 1.0]
        scale.keyTimes = [0, 0.4, 1]
        scale.duration = duration
        scale.timingFunctions = [
            CAMediaTimingFunction(name: .easeInEaseOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
        ]
        imageView.layer.add(scale, forKey: "skipScale")
    }

    func desiredHeight() -> CGFloat {
        70
    }

    func aboutToDisplayFullScreenPlayer() {
        guard rootViewController() != nil else { return }

        if fullScreenPlayer == nil {
            fullScreenPlayer = PlayerContainerViewController()
        }
    }

    func finishedWithFullScreenPlayer() {
        guard rootViewController() != nil else { return }

        rootViewController()?.setNeedsStatusBarAppearanceUpdate()
        rootViewController()?.setNeedsUpdateOfHomeIndicatorAutoHidden()

        fullScreenPlayer?.view.removeFromSuperview()
        fullScreenPlayer = nil

        // update the mini player on full screen player close
        playbackStateDidChange()
        playbackProgressDidChange()
    }

    func changeHeightTo(_ height: CGFloat) {
        if heightConstraint == nil {
            heightConstraint = view.heightAnchor.constraint(equalToConstant: height)
            heightConstraint?.isActive = true
        } else {
            heightConstraint?.constant = height
        }
    }

    func addUINotificationObservers() {
        addCustomObserver(Constants.Notifications.playbackStarting, selector: #selector(playbackStarting))
        addCustomObserver(Constants.Notifications.playbackStarted, selector: #selector(playbackStarted))
        addCustomObserver(Constants.Notifications.playbackEnded, selector: #selector(playbackStateDidChange))
        addCustomObserver(Constants.Notifications.playbackPaused, selector: #selector(playbackStateDidChange))
        addCustomObserver(Constants.Notifications.playbackTrackChanged, selector: #selector(playbackStateDidChange))
        addCustomObserver(Constants.Notifications.playbackProgress, selector: #selector(playbackProgressDidChange))
        addCustomObserver(Constants.Notifications.googleCastStatusChanged, selector: #selector(playbackStateDidChange))
        addCustomObserver(Constants.Notifications.statusBarHeightChanged, selector: #selector(statusBarHeightDidChange))

        addCustomObserver(Constants.Notifications.podcastImageReCacheRequired, selector: #selector(updateRequired))

        addCustomObserver(.episodeEmbeddedArtworkLoaded, selector: #selector(updateRequired))

        addCustomObserver(Constants.Notifications.upNextQueueChanged, selector: #selector(upNextListChanged))
        addCustomObserver(Constants.Notifications.podcastDeleted, selector: #selector(upNextListChanged))

        addCustomObserver(UIApplication.didBecomeActiveNotification, selector: #selector(playbackStateDidChange))

        addCustomObserver(Constants.Notifications.themeChanged, selector: #selector(themeChanged))
        addCustomObserver(Constants.Notifications.currentlyPlayingEpisodeUpdated, selector: #selector(updateRequired))
        addCustomObserver(Constants.Notifications.playbackMuteChanged, selector: #selector(muteStateChanged))

        #if !APPCLIP
        addCustomObserver(.radioStationNowPlayingDidChange, selector: #selector(radioTrackArtworkChanged(notification:)))
        addCustomObserver(.radioTracklistDidRefresh, selector: #selector(radioTracklistRefreshed(notification:)))
        #endif
    }

    func rootViewController() -> MainTabBarController? {
        if let controller = view.window?.rootViewController as? MainTabBarController {
            return controller
        }

        return nil
    }

    private func rootNavController() -> UINavigationController? {
        if let rootNav = rootViewController()?.selectedViewController as? UINavigationController {
            return rootNav
        }

        return nil
    }

    func miniPlayerShowing() -> Bool {
        assert(!LiquidGlass.isEnabled, "Should never be used when Liquid Glass is on")
        return !view.isHidden
    }

    private func setupForEpisode(_ episode: BaseEpisode) {
        updateColors()

        if lastEpisodeUuidImageLoaded != episode.uuid {
            lastEpisodeUuidImageLoaded = episode.uuid
            #if !APPCLIP
            if let radio = PlaybackManager.shared.liveStation(for: episode) {
                applyRadioBaseArtwork(for: radio)
            } else {
                podcastArtwork.setBaseEpisode(episode: episode, size: .list)
            }
            #else
            podcastArtwork.setBaseEpisode(episode: episode, size: .list)
            #endif
        }

        if let episodeTitleLabel, episodeTitleLabel.text != episode.title {
            episodeTitleLabel.text = episode.title
        }
    }

    @objc private func playbackStarted() {
        if let episode = PlaybackManager.shared.currentEpisode() {
            setupForEpisode(episode)
            showMiniPlayer()
            let shouldOpenAutomatically: Bool
            if FeatureFlag.newSettingsStorage.enabled {
                shouldOpenAutomatically = SettingsStore.appSettings.openPlayer
            } else {
                shouldOpenAutomatically = UserDefaults.standard.bool(forKey: Constants.UserDefaults.openPlayerAutomatically)
            }
            if shouldOpenAutomatically || episode.videoPodcast(), lastEpisodeUuidAutoOpened != episode.uuid {
                lastEpisodeUuidAutoOpened = episode.uuid

                // we called show mini player above, which might have spent time animating itself into view, so give that time to finish
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Animation.defaultAnimationTime) {
                    self.openFullScreenPlayer()
                }
            }
        } else {
            hideMiniPlayer(true)
        }
    }

    @objc private func playbackStarting() {
        playbackStateDidChange()
    }

    @objc private func statusBarHeightDidChange() {
        if !LiquidGlass.isEnabled, miniPlayerShowing() {
            hideMiniPlayer(false)
            showMiniPlayer()
        }
    }

    @objc private func upNextListChanged() {
        playbackStateDidChange()
    }

    @objc private func playbackStateDidChange() {
        guard let episodePlaying = PlaybackManager.shared.currentEpisode() else {
            hideMiniPlayer(true)

            return
        }

        setupForEpisode(episodePlaying)
        updateSkipMuteSwap()
        showMiniPlayer()
        playbackProgressDidChange()
    }

    @objc private func themeChanged() {
        updateColors()
    }

    @objc private func playbackProgressDidChange() {
        if playerOpenState == .open { return } // don't update the mini player while the full screen player is open

        let currentTime = PlaybackManager.shared.currentTime()
        let duration = PlaybackManager.shared.duration()

        var progress: CGFloat = 0
        if currentTime > 0, duration > 0 {
            progress = min(1, CGFloat(currentTime / duration))
        }

        playbackProgressView.progress = progress
        playbackProgressView.indeterminant = PlaybackManager.shared.buffering() && PlaybackManager.shared.playing()

        let amountBuferred = PlaybackManager.shared.futureBufferAvailable()
        if amountBuferred > 0 {
            playbackProgressView.buferredAmount = CGFloat(amountBuferred / (duration - currentTime))
        }

        glassProgressView?.playbackProgress = progress

        if let episodeTimeLeftLabel {
            let remaining = max(0, duration - currentTime)
            let newText: String?
            if remaining > 0 {
                let formatted = TimeFormatter.shared.multipleUnitFormattedShortTime(time: remaining)
                newText = L10n.podcastTimeLeft(formatted)
            } else {
                newText = nil
            }
            if episodeTimeLeftLabel.text != newText {
                episodeTimeLeftLabel.text = newText
            }
        }
    }

    private func updateColors() {
        view.backgroundColor = .clear

        if FeatureFlag.liquidGlass.enabled, #available(iOS 26.0, *) {
            updateColorsLiquidGlass()
        } else {
            updateColorsLegacy()
        }

        playPauseBtn.isPlaying = PlaybackManager.shared.playing()
    }

    private func updateColorsLegacy() {
        gradientView.colors = [ThemeColor.primaryUi02().withAlphaComponent(0), ThemeColor.primaryUi02()]

        let actionColor = currentPodcastTintColor()
        let bgColor = ThemeColor.podcastUi02(podcastColor: actionColor)
        let iconColor = ThemeColor.podcastIcon03(podcastColor: actionColor)

        mainView.backgroundColor = bgColor

        playPauseBtn.playButtonColor = bgColor
        playPauseBtn.circleColor = iconColor

        playbackProgressView.updateColors()

        skipBackBtn.tintColor = iconColor
        skipFwdBtn.tintColor = iconColor
        upNextBtn.iconColor = iconColor
    }

    @available(iOS 26.0, *)
    private func updateColorsLiquidGlass() {
        let actionColor = currentPodcastTintColor()
        let iconColor = ThemeColor.podcastIcon03(podcastColor: actionColor)
        let bgColor = ThemeColor.primaryUi02()

        episodeTitleLabel?.textColor = ThemeColor.primaryText01()
        episodeTimeLeftLabel?.textColor = ThemeColor.primaryText02()

        playPauseBtn.playButtonColor = bgColor
        playPauseBtn.circleColor = iconColor

        skipBackBtn.tintColor = iconColor
        skipFwdBtn.tintColor = iconColor

        glassProgressView?.tintColorOverride = actionColor
    }

    private func currentPodcastTintColor() -> UIColor {
        if let podcast = podcastForEpisode(PlaybackManager.shared.currentEpisode()) {
            return Theme.isDarkTheme() ? ColorManager.darkThemeTintForPodcast(podcast) : ColorManager.lightThemeTintForPodcast(podcast)
        } else if let episode = PlaybackManager.shared.currentEpisode() as? UserEpisode, episode.imageColor > 0 {
            return AppTheme.userEpisodeColor(number: Int(episode.imageColor))
        } else {
            return AppTheme.userEpisodeColor(number: 1)
        }
    }

    private func podcastForEpisode(_ episode: BaseEpisode?) -> Podcast? {
        if let episode = PlaybackManager.shared.currentEpisode() as? Episode {
            return episode.parentPodcast()
        }

        return nil
    }

    @objc private func updateRequired() {
        guard let episode = PlaybackManager.shared.currentEpisode() else { return }

        updateColors()
        updateSkipMuteSwap()

        if let userEpisode = episode as? UserEpisode {
            podcastArtwork.setUserEpisode(uuid: userEpisode.uuid, size: .list)
        } else {
            #if !APPCLIP
            if let radio = PlaybackManager.shared.liveStation(for: episode) {
                applyRadioBaseArtwork(for: radio)
            } else {
                podcastArtwork.setBaseEpisode(episode: episode, size: .list)
            }
            #else
            podcastArtwork.setBaseEpisode(episode: episode, size: .list)
            #endif
        }
    }

    #if !APPCLIP
    func applyRadioBaseArtwork(for station: RadioStation) {
        podcastArtwork.imageView?.kf.cancelDownloadTask()
        if let asset = station.logoAsset, let image = UIImage(named: asset) {
            podcastArtwork.setImageManually(image: image, size: .list)
        } else {
            podcastArtwork.clearArtwork()
        }
    }

    @objc func radioTrackArtworkChanged(notification: Notification) {
        guard let info = notification.userInfo,
              let stationId = info[RadioMetadataNotificationKey.stationId] as? String else { return }
        let title = (info[RadioMetadataNotificationKey.title] as? String) ?? ""
        let artist = (info[RadioMetadataNotificationKey.artist] as? String) ?? ""
        resolveRadioArtwork(stationId: stationId, icyArtist: artist, icyTitle: title)
    }

    @objc func radioTracklistRefreshed(notification: Notification) {
        guard let info = notification.userInfo,
              let stationId = info[RadioMetadataNotificationKey.stationId] as? String else { return }
        resolveRadioArtwork(stationId: stationId, icyArtist: "", icyTitle: "")
    }

    private func resolveRadioArtwork(stationId: String, icyArtist: String, icyTitle: String) {
        guard let radio = PlaybackManager.shared.liveStation(),
              radio.uuid == stationId,
              let imageView = podcastArtwork.imageView else { return }

        // Baseline first so we never show a blank slot during the async resolve.
        applyRadioBaseArtwork(for: radio)

        // Non-enhanced stations: keep station logo, no iTunes call.
        guard let enhancement = CuratedStationsLoader.enhancementsByUUID[stationId],
              enhancement.tracklistUrl != nil else { return }

        guard let resolveEntry = TrackArtworkResolver.bestResolveEntry(stationId: stationId, icyArtist: icyArtist, icyTitle: icyTitle) else { return }

        let resolvedArtist = resolveEntry.artist
        let resolvedTitle = resolveEntry.title

        TrackArtworkResolver.shared.artworkURL(for: resolveEntry, station: radio) { [weak self] url in
            // Resolver completes off-main; UIImageView + Kingfisher writes
            // require the main thread.
            DispatchQueue.main.async {
                guard let self else { return }
                guard let current = PlaybackManager.shared.liveStation(),
                      current.uuid == stationId else { return }
                // Stale-guard: if a newer resolve has overtaken (different
                // top tracklist entry now), drop this completion.
                if let newest = TrackArtworkResolver.bestResolveEntry(stationId: stationId, icyArtist: "", icyTitle: ""),
                   newest.artist != resolvedArtist || newest.title != resolvedTitle {
                    return
                }

                if let url {
                    imageView.kf.setImage(with: url, placeholder: imageView.image, options: [.transition(.fade(0.2))]) { [weak self] result in
                        if case .failure = result {
                            self?.applyRadioBaseArtwork(for: radio)
                        }
                    }
                } else {
                    self.applyRadioBaseArtwork(for: radio)
                }
            }
        }
    }
    #endif

    func showUpNext(from source: UpNextViewSource) {
        upNextViewController = UpNextViewController(source: source)
        guard let upNextController = upNextViewController else { return }

        let navWrapper = SJUIUtils.navController(for: upNextController, iconStyle: .secondaryText01, themeOverride: upNextController.themeOverride)
        navWrapper.modalPresentationStyle = .formSheet
        rootViewController()?.present(navWrapper, animated: true, completion: nil)
    }
}

extension MiniPlayerViewController: AnalyticsSourceProvider {
    var analyticsSource: AnalyticsSource {
        .miniplayer
    }
}
