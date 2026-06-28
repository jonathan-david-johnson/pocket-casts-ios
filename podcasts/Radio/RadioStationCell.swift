import Kingfisher
import UIKit

class RadioStationCell: UITableViewCell {
    static let reuseId = "RadioStationCell"

    private let logoView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 8
        iv.clipsToBounds = true
        iv.backgroundColor = AppTheme.colorForStyle(.primaryUi02)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textColor = AppTheme.colorForStyle(.primaryText01)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cityLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = AppTheme.colorForStyle(.primaryText02)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        showsReorderControl = true
        backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        logoView.kf.cancelDownloadTask()
        logoView.image = UIImage(systemName: "radio")
        logoView.tintColor = AppTheme.colorForStyle(.primaryIcon02)
    }

    private func setupLayout() {
        let textStack = UIStackView(arrangedSubviews: [nameLabel, cityLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(logoView)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            logoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logoView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoView.widthAnchor.constraint(equalToConstant: 48),
            logoView.heightAnchor.constraint(equalToConstant: 48),
            logoView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            logoView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10),

            textStack.leadingAnchor.constraint(equalTo: logoView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(name: String, city: String, logoAsset: String?) {
        applyTheme()
        nameLabel.text = name
        cityLabel.text = city
        if let asset = logoAsset, let image = UIImage(named: asset) {
            logoView.image = image
        } else {
            logoView.image = UIImage(systemName: "radio")
            logoView.tintColor = AppTheme.colorForStyle(.primaryIcon02)
        }
    }

    func configure(name: String, city: String, faviconUrl: String?) {
        applyTheme()
        nameLabel.text = name
        cityLabel.text = city
        let placeholder = UIImage(systemName: "radio")
        logoView.tintColor = AppTheme.colorForStyle(.primaryIcon02)
        guard let urlString = faviconUrl, let url = URL(string: urlString) else {
            logoView.image = placeholder
            return
        }
        logoView.kf.setImage(
            with: url,
            placeholder: placeholder,
            options: [.targetCache(ImageManager.sharedManager.stationFaviconCache), .transition(.fade(0.15))]
        )
    }

    /// Cells are reused — re-read theme colours every configure so a theme
    /// change in Settings propagates immediately on the next
    /// `tableView.reloadData()` (no restart).
    private func applyTheme() {
        backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        contentView.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        nameLabel.textColor = AppTheme.colorForStyle(.primaryText01)
        cityLabel.textColor = AppTheme.colorForStyle(.primaryText02)
        logoView.backgroundColor = AppTheme.colorForStyle(.primaryUi02)
    }
}
