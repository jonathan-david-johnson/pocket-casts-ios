import UIKit

class SegmentedTitleView: UIView {
    enum Segment: CaseIterable { case playlists, upNext }

    var onSelect: ((Segment) -> Void)?

    private(set) var activeSegment: Segment = .playlists {
        didSet { refreshStyles() }
    }

    private let playlistsButton = SegmentButton()
    private let upNextButton = SegmentButton()
    private let separatorLabel = UILabel()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        NotificationCenter.default.addObserver(self, selector: #selector(themeDidChange), name: Constants.Notifications.themeChanged, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit { NotificationCenter.default.removeObserver(self) }

    func setActive(_ segment: Segment) { activeSegment = segment }

    /// Test hook — runs the same code path the tap action invokes.
    func simulateTap(on segment: Segment) { handleTap(segment) }

    private func setup() {
        playlistsButton.setTitle(L10n.playlists, for: .normal)
        upNextButton.setTitle(L10n.upNext, for: .normal)
        separatorLabel.text = "/"
        separatorLabel.isUserInteractionEnabled = false

        for (button, segment) in [(playlistsButton, Segment.playlists), (upNextButton, Segment.upNext)] {
            button.addAction(UIAction { [weak self] _ in self?.handleTap(segment) }, for: .touchUpInside)
            button.isAccessibilityElement = true
            button.accessibilityTraits = .button
        }
        playlistsButton.accessibilityLabel = L10n.playlists
        upNextButton.accessibilityLabel = L10n.upNext

        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        [playlistsButton, separatorLabel, upNextButton].forEach { stack.addArrangedSubview($0) }
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        refreshStyles()
    }

    private func handleTap(_ segment: Segment) {
        guard segment != activeSegment else { return }
        activeSegment = segment
        onSelect?(segment)
    }

    private func refreshStyles() {
        let themeType = Theme.sharedTheme.activeTheme
        let primary = AppTheme.colorForStyle(.primaryText01, themeOverride: themeType)
        let secondary = AppTheme.colorForStyle(.primaryText02, themeOverride: themeType)
        let metrics = UIFontMetrics(forTextStyle: .headline)
        let activeFont = metrics.scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
        let inactiveFont = metrics.scaledFont(for: .systemFont(ofSize: 17, weight: .regular))

        configure(playlistsButton, isActive: activeSegment == .playlists, primary: primary, secondary: secondary, activeFont: activeFont, inactiveFont: inactiveFont)
        configure(upNextButton, isActive: activeSegment == .upNext, primary: primary, secondary: secondary, activeFont: activeFont, inactiveFont: inactiveFont)

        separatorLabel.font = inactiveFont
        separatorLabel.textColor = secondary
    }

    private func configure(_ button: SegmentButton, isActive: Bool, primary: UIColor, secondary: UIColor, activeFont: UIFont, inactiveFont: UIFont) {
        button.titleLabel?.font = isActive ? activeFont : inactiveFont
        button.setTitleColor(isActive ? primary : secondary, for: .normal)
        if isActive {
            button.accessibilityTraits = [.button, .selected]
        } else {
            button.accessibilityTraits = .button
        }
    }

    @objc private func themeDidChange() { refreshStyles() }
}

private final class SegmentButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
        configuration = config
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
