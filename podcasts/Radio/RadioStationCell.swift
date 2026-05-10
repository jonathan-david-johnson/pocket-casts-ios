import UIKit

class RadioStationCell: UITableViewCell {
    static let reuseId = "RadioStationCell"

    private let logoView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.layer.cornerRadius = 8
        iv.clipsToBounds = true
        iv.backgroundColor = .secondarySystemBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cityLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryType = .disclosureIndicator
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

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
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(name: String, city: String, logoAsset: String?) {
        nameLabel.text = name
        cityLabel.text = city
        if let asset = logoAsset, let image = UIImage(named: asset) {
            logoView.image = image
        } else {
            logoView.image = UIImage(systemName: "radio")
            logoView.tintColor = .secondaryLabel
        }
    }

    func configure(name: String, city: String, faviconUrl: String?) {
        nameLabel.text = name
        cityLabel.text = city
        logoView.image = UIImage(systemName: "radio")
        logoView.tintColor = .secondaryLabel
        guard let urlString = faviconUrl, let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self?.logoView.image = image }
        }.resume()
    }
}
