import UIKit
import PocketCastsDataModel

/// M1 stub: minimal Streams tab for proving RadioStation playback works.
/// Replace with full segmented Stations/Favorites/Browse UI in M2.
class StreamsHostViewController: UIViewController {

    private let kcrw = RadioStation(
        stationId: "kcrw",
        name: "KCRW",
        streamUrl: "https://streams.kcrw.com/e24_mp3",
        donateUrl: "https://join.kcrw.com",
        city: "Santa Monica, CA"
    )

    private let kexp = RadioStation(
        stationId: "kexp",
        name: "KEXP",
        streamUrl: "https://kexp.streamguys1.com/kexp160.aac",
        donateUrl: "https://www.kexp.org/donate",
        city: "Seattle, WA"
    )

    private let nprHourly = RadioStation(
        stationId: "npr_hourly",
        name: "NPR Hourly News",
        streamUrl: "http://pd.npr.org/anon.npr-mp3/npr/news/newscast.mp3",
        donateUrl: "https://www.npr.org/donations/support",
        city: "Washington, DC"
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Streams"
        view.backgroundColor = .systemBackground
        setupButtons()
    }

    private func setupButtons() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])

        for station in [kcrw, kexp, nprHourly] {
            let btn = UIButton(type: .system)
            btn.setTitle("▶ \(station.displayableTitle())", for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
            btn.addAction(UIAction { [weak self] _ in self?.play(station) }, for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }

        let stopBtn = UIButton(type: .system)
        stopBtn.setTitle("■ Stop", for: .normal)
        stopBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        stopBtn.tintColor = .systemRed
        stopBtn.addAction(UIAction { _ in PlaybackManager.shared.stopPlayback() }, for: .touchUpInside)
        stack.addArrangedSubview(stopBtn)
    }

    private func play(_ station: RadioStation) {
        PlaybackManager.shared.load(episode: station, autoPlay: true, overrideUpNext: false)
    }
}
