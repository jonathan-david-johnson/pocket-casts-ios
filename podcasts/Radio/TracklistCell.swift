import UIKit

final class TracklistCell: UITableViewCell {
    static let reuseIdentifier = "TracklistCell"

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let artistLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let albumLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let artView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 4
        iv.backgroundColor = .secondarySystemBackground
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private var artLoadTask: URLSessionDataTask?
    private var artGeneration: Int = 0

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.addSubview(titleLabel)
        contentView.addSubview(artistLabel)
        contentView.addSubview(albumLabel)
        contentView.addSubview(artView)

        NSLayoutConstraint.activate([
            artView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            artView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            artView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            artView.widthAnchor.constraint(equalToConstant: 60),
            artView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: artView.leadingAnchor, constant: -12),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),

            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            albumLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            albumLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            albumLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 2),
            albumLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        artGeneration &+= 1   // invalidate any in-flight image load
        artLoadTask?.cancel()
        artLoadTask = nil
        artView.image = nil
        titleLabel.text = nil
        artistLabel.text = nil
        albumLabel.text = nil
    }

    func configure(with entry: TracklistEntry, fallbackArt: UIImage? = nil) {
        titleLabel.text = entry.title
        artistLabel.text = entry.artist
        albumLabel.text = entry.album
        albumLabel.isHidden = (entry.album?.isEmpty ?? true)

        artView.image = fallbackArt
        guard let url = entry.albumArtURL else { return }

        let generation = artGeneration
        artLoadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.artGeneration == generation else { return }
                self.artView.image = image
            }
        }
        artLoadTask?.resume()
    }
}
