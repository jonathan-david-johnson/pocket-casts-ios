import UIKit

/// Full-screen lyrics view for a single tracklist entry. Synced lyrics render
/// as a table that auto-advances (when `isCurrentSong`); plain lyrics render as
/// a static text view; missing lyrics show a centered empty state.
final class LyricsViewController: UIViewController {
    private let entry: TracklistEntry
    private let lyricsResult: LyricsResult
    private let initialOffset: TimeInterval
    private let isCurrentSong: Bool

    private var lyricStartDate: Date?
    private var lyricTimer: Timer?
    private var currentLineIndex: Int = 0

    // MARK: - Header

    private let artView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 6
        iv.backgroundColor = AppTheme.colorForStyle(.primaryUi02)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = AppTheme.colorForStyle(.primaryText01)
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let artistLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15)
        l.textColor = AppTheme.colorForStyle(.primaryText02)
        l.numberOfLines = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let lyricsTable: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.separatorStyle = .none
        tv.estimatedRowHeight = 30
        tv.rowHeight = UITableView.automaticDimension
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private var artLoadTask: URLSessionDataTask?

    private static let lyricCellID = "LyricLineCell"

    init(entry: TracklistEntry, lyricsResult: LyricsResult, offset: TimeInterval, isCurrentSong: Bool) {
        self.entry = entry
        self.lyricsResult = lyricsResult
        self.initialOffset = offset
        self.isCurrentSong = isCurrentSong
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = entry.title
        view.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        setupHeader()

        if lyricsResult.hasSynced {
            setupSyncedTable()
        } else if let plain = lyricsResult.plain, !plain.isEmpty {
            setupPlainText(plain)
        } else {
            setupEmptyState()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard lyricsResult.hasSynced else { return }
        currentLineIndex = startingIndex(for: initialOffset)
        scrollToCurrentLine(animated: false)
        if isCurrentSong {
            startTimer()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopTimer()
        artLoadTask?.cancel()
        artLoadTask = nil
    }

    // MARK: - Header layout

    private func setupHeader() {
        titleLabel.text = entry.title
        artistLabel.text = entry.artist

        let textStack = UIStackView(arrangedSubviews: [titleLabel, artistLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let headerStack = UIStackView(arrangedSubviews: [artView, textStack])
        headerStack.axis = .horizontal
        headerStack.spacing = 12
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        NSLayoutConstraint.activate([
            artView.widthAnchor.constraint(equalToConstant: 40),
            artView.heightAnchor.constraint(equalToConstant: 40),
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor)
        ])

        loadArtwork()
    }

    private func loadArtwork() {
        artView.image = UIImage(systemName: "music.note")
        artView.tintColor = AppTheme.colorForStyle(.primaryIcon02)
        guard let url = entry.albumArtURL else { return }
        artLoadTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { [weak self] in
                self?.artView.image = image
            }
        }
        artLoadTask?.resume()
    }

    // MARK: - Synced

    private func setupSyncedTable() {
        lyricsTable.register(UITableViewCell.self, forCellReuseIdentifier: Self.lyricCellID)
        lyricsTable.dataSource = self
        lyricsTable.delegate = self
        lyricsTable.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        lyricsTable.allowsSelection = false
        view.addSubview(lyricsTable)

        NSLayoutConstraint.activate([
            lyricsTable.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 72),
            lyricsTable.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lyricsTable.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lyricsTable.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupPlainText(_ plain: String) {
        let tv = UITextView()
        tv.isEditable = false
        tv.text = plain
        tv.font = .systemFont(ofSize: 16)
        tv.textColor = AppTheme.colorForStyle(.primaryText01)
        tv.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        tv.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tv)

        NSLayoutConstraint.activate([
            tv.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 72),
            tv.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            tv.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            tv.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupEmptyState() {
        let label = UILabel()
        label.text = "No lyrics found"
        label.font = .systemFont(ofSize: 16)
        label.textColor = AppTheme.colorForStyle(.primaryText02)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Timer / advancing

    private func startTimer() {
        lyricStartDate = Date().addingTimeInterval(-initialOffset)
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        lyricTimer = timer
    }

    private func stopTimer() {
        lyricTimer?.invalidate()
        lyricTimer = nil
    }

    private func tick() {
        guard let start = lyricStartDate else { return }
        let offset = Date().timeIntervalSince(start)
        let newIndex = startingIndex(for: offset)
        guard newIndex != currentLineIndex else { return }
        let previous = currentLineIndex
        currentLineIndex = newIndex
        lyricsTable.reloadRows(at: [IndexPath(row: previous, section: 0),
                                    IndexPath(row: newIndex, section: 0)], with: .none)
        scrollToCurrentLine(animated: true)
    }

    /// Index of the last line whose timestamp <= offset, clamped to bounds.
    private func startingIndex(for offset: TimeInterval) -> Int {
        let lines = lyricsResult.lines
        guard !lines.isEmpty else { return 0 }
        var idx = 0
        for (i, line) in lines.enumerated() where line.timestamp <= offset {
            idx = i
        }
        return idx
    }

    private func scrollToCurrentLine(animated: Bool) {
        guard lyricsResult.hasSynced, currentLineIndex < lyricsResult.lines.count else { return }
        lyricsTable.scrollToRow(at: IndexPath(row: currentLineIndex, section: 0), at: .middle, animated: animated)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension LyricsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        lyricsResult.lines.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.lyricCellID, for: indexPath)
        let line = lyricsResult.lines[indexPath.row]
        cell.backgroundColor = AppTheme.colorForStyle(.primaryUi01)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = line.text

        let isCurrent = indexPath.row == currentLineIndex
        cell.textLabel?.font = isCurrent ? .systemFont(ofSize: 18, weight: .bold) : .systemFont(ofSize: 16)
        cell.textLabel?.textColor = isCurrent
            ? AppTheme.colorForStyle(.primaryText01)
            : AppTheme.colorForStyle(.primaryText02)
        return cell
    }
}
