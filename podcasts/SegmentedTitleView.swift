import UIKit

class SegmentedTitleView: UIView {
    enum Segment: CaseIterable {
        case playlists, upNext, favorites, browse

        var title: String {
            switch self {
            case .playlists: return L10n.playlists
            case .upNext:    return L10n.upNext
            case .favorites: return "Favorites"
            case .browse:    return "Browse"
            }
        }
    }

    var onSelect: ((Segment) -> Void)?

    private(set) var activeSegment: Segment {
        didSet { refreshStyles() }
    }

    private let leadingButton = SegmentButton()
    private let trailingButton = SegmentButton()
    private let separatorLabel = UILabel()
    private let stack = UIStackView()

    private let leadingSegment: Segment
    private let trailingSegment: Segment

    /// Default initializer — shows Playlists / Up Next (M5.1 behaviour).
    convenience override init(frame: CGRect) {
        self.init(leading: .playlists, trailing: .upNext)
    }

    init(leading: Segment, trailing: Segment) {
        self.leadingSegment = leading
        self.trailingSegment = trailing
        self.activeSegment = leading
        super.init(frame: .zero)
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
        leadingButton.setTitle(leadingSegment.title, for: .normal)
        trailingButton.setTitle(trailingSegment.title, for: .normal)
        separatorLabel.text = "/"
        separatorLabel.isUserInteractionEnabled = false

        for (button, segment) in [(leadingButton, leadingSegment), (trailingButton, trailingSegment)] {
            button.addAction(UIAction { [weak self] _ in self?.handleTap(segment) }, for: .touchUpInside)
            button.isAccessibilityElement = true
            button.accessibilityTraits = .button
        }
        leadingButton.accessibilityLabel = leadingSegment.title
        trailingButton.accessibilityLabel = trailingSegment.title

        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        [leadingButton, separatorLabel, trailingButton].forEach { stack.addArrangedSubview($0) }
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

        configure(leadingButton, isActive: activeSegment == leadingSegment, primary: primary, secondary: secondary, activeFont: activeFont, inactiveFont: inactiveFont)
        configure(trailingButton, isActive: activeSegment == trailingSegment, primary: primary, secondary: secondary, activeFont: activeFont, inactiveFont: inactiveFont)

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
