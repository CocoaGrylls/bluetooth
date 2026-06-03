//
//  HomeRecordingFileCell.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/5/25.
//

import UIKit
import SnapKit

protocol HomeRecordingFileCellDelegate: AnyObject {
    func homeRecordingFileCellDidTapDownload(_ cell: HomeRecordingFileCell)
    func homeRecordingFileCellDidTapPlay(_ cell: HomeRecordingFileCell)
    func homeRecordingFileCellDidTapMore(_ cell: HomeRecordingFileCell)
}

final class HomeRecordingFileCell: UITableViewCell {

    static let reuseId = "HomeRecordingFileCell"

    enum State {
        case idle
        case downloading(Int)
        case done
        case error
    }

    weak var delegate: HomeRecordingFileCellDelegate?

    // MARK: - Lazy subviews

    private lazy var cardView: UIView = {
        let card = UIView()
        card.backgroundColor = Theme.audioCellBackground
        card.layer.cornerRadius = 8
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.audioCellBorder.cgColor
        card.clipsToBounds = true
        return card
    }()

    private lazy var fileIconContainer: UIView = {
        let container = UIView()
        container.layer.cornerRadius = 4
        container.clipsToBounds = true
        return container
    }()

    private lazy var fileIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "waveform"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var foldedCornerView: UIView = {
        let folded = UIView()
        folded.backgroundColor = UIColor.white.withAlphaComponent(0.28)
        return folded
    }()

    private lazy var nameLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.textColor = Theme.homePrimaryText
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingMiddle
        return titleLabel
    }()

    private lazy var infoLabel: UILabel = {
        let info = UILabel()
        info.textColor = Theme.homeSecondaryText
        info.font = .systemFont(ofSize: 13, weight: .regular)
        return info
    }()

    private lazy var waveformView: HomeAudioWaveformView = {
        let waveform = HomeAudioWaveformView()
        return waveform
    }()

    private lazy var durationLabel: UILabel = {
        let duration = UILabel()
        duration.textColor = Theme.homeSecondaryText
        duration.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        duration.textAlignment = .right
        return duration
    }()

    private lazy var actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = Theme.audioPlayBackground
        button.layer.cornerRadius = 23
        button.tintColor = Theme.audioPlayTint
        button.imageView?.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsets(top: 11, left: 11, bottom: 11, right: 11)
        return button
    }()

    private lazy var moreButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = Theme.homeSecondaryText
        return button
    }()

    private lazy var progressView: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.trackTintColor = UIColor.white.withAlphaComponent(0.12)
        p.isHidden = true
        return p
    }()

    // MARK: - State

    private var accentColor = Theme.audioBlue
    private var currentState: State = .idle
    private var currentIsLocal = false

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        buildUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        progressView.isHidden = true
        actionButton.isEnabled = true
    }

    // MARK: - Configuration

    func configure(item: AudioItem, displayName: String, durationText: String?, state: State) {
        accentColor = Self.accentColor(for: item.fileName)
        nameLabel.text = displayName
        infoLabel.text = makeInfoText(item)
        durationLabel.text = durationText?.isEmpty == false ? durationText : "--:--"
        waveformView.configure(accentColor: accentColor, seed: item.fileName)
        applyAccent()
        applyState(state, isLocal: item.isLocal)
    }

    // MARK: - UI Building

    private func buildUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)

        cardView.addSubview(fileIconContainer)
        fileIconContainer.addSubview(fileIconView)
        fileIconContainer.addSubview(foldedCornerView)

        cardView.addSubview(nameLabel)
        cardView.addSubview(infoLabel)
        cardView.addSubview(waveformView)
        cardView.addSubview(durationLabel)
        cardView.addSubview(actionButton)
        cardView.addSubview(moreButton)
        cardView.addSubview(progressView)

        // targets added here to avoid capturing self in lazy closures
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)
        moreButton.addTarget(self, action: #selector(moreTapped), for: .touchUpInside)

        // SnapKit 布局
        cardView.snp.makeConstraints { make in
            make.top.equalTo(contentView).offset(6)
            make.left.equalTo(contentView).offset(16)
            make.right.equalTo(contentView).offset(-16)
            make.bottom.equalTo(contentView).offset(-6)
        }

        fileIconContainer.snp.makeConstraints { make in
            make.left.equalTo(cardView).offset(26)
            make.centerY.equalTo(cardView)
            make.width.equalTo(42)
            make.height.equalTo(52)
        }

        fileIconView.snp.makeConstraints { make in
            make.centerX.equalTo(fileIconContainer)
            make.centerY.equalTo(fileIconContainer)
            make.width.height.equalTo(24)
        }

        foldedCornerView.snp.makeConstraints { make in
            make.top.equalTo(fileIconContainer)
            make.right.equalTo(fileIconContainer)
            make.width.height.equalTo(13)
        }

        moreButton.snp.makeConstraints { make in
            make.top.equalTo(cardView).offset(12)
            make.right.equalTo(cardView).offset(-10)
            make.width.height.equalTo(34)
        }

        actionButton.snp.makeConstraints { make in
            make.right.equalTo(cardView).offset(-26)
            make.centerY.equalTo(cardView).offset(12)
            make.width.height.equalTo(46)
        }

        nameLabel.snp.makeConstraints { make in
            make.top.equalTo(cardView).offset(20)
            make.left.equalTo(fileIconContainer.snp.right).offset(22)
            make.right.equalTo(moreButton.snp.left).offset(-8)
        }

        infoLabel.snp.makeConstraints { make in
            make.top.equalTo(nameLabel.snp.bottom).offset(6)
            make.left.equalTo(nameLabel)
            make.right.equalTo(actionButton.snp.left).offset(-12)
        }

        waveformView.snp.makeConstraints { make in
            make.left.equalTo(nameLabel)
            make.top.equalTo(infoLabel.snp.bottom).offset(14)
            make.right.equalTo(durationLabel.snp.left).offset(-10)
            make.height.equalTo(18)
        }

        durationLabel.snp.makeConstraints { make in
            make.centerY.equalTo(waveformView)
            make.right.equalTo(actionButton.snp.left).offset(-14)
            make.width.equalTo(52)
        }

        progressView.snp.makeConstraints { make in
            make.left.equalTo(nameLabel)
            make.right.equalTo(durationLabel)
            make.top.equalTo(waveformView.snp.bottom).offset(4)
        }
    }

    // MARK: - Helpers

    private func makeInfoText(_ item: AudioItem) -> String {
        let dateText = item.createTime.replacingOccurrences(of: "-", with: "/")
        return "\(dateText)  \(item.fileSizeStr)"
    }

    private func applyAccent() {
        fileIconContainer.backgroundColor = accentColor
        waveformView.tintColor = accentColor
        progressView.progressTintColor = accentColor
    }

    private func applyState(_ state: State, isLocal: Bool) {
        currentState = state
        currentIsLocal = isLocal

        switch state {
        case .idle:
            progressView.isHidden = true
            actionButton.isEnabled = true
            actionButton.setImage(isLocal ? UIImage(systemName: "play.fill") : Self.downloadImage(), for: .normal)
        case .downloading(let progress):
            progressView.isHidden = false
            progressView.progress = Float(progress) / 100.0
            actionButton.isEnabled = false
            actionButton.setImage(Self.downloadImage(), for: .normal)
        case .done:
            progressView.isHidden = true
            actionButton.isEnabled = true
            actionButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        case .error:
            progressView.isHidden = true
            actionButton.isEnabled = true
            actionButton.setImage(UIImage(systemName: "exclamationmark.arrow.triangle.2.circlepath"), for: .normal)
        }
    }

    @objc private func actionTapped() {
        let shouldPlay: Bool
        if case .done = currentState {
            shouldPlay = true
        } else {
            shouldPlay = currentIsLocal
        }

        if shouldPlay {
            delegate?.homeRecordingFileCellDidTapPlay(self)
        } else {
            delegate?.homeRecordingFileCellDidTapDownload(self)
        }
    }

    @objc private func moreTapped() {
        delegate?.homeRecordingFileCellDidTapMore(self)
    }

    private static func accentColor(for fileName: String) -> UIColor {
        let colors = [Theme.audioBlue, Theme.audioGreen, Theme.audioPurple, Theme.audioYellow]
        let index = abs(fileName.hashValue) % colors.count
        return colors[index]
    }

    private static func downloadImage() -> UIImage? {
        UIImage(named: "down_file")?.withRenderingMode(.alwaysOriginal) ?? UIImage(systemName: "arrow.down")
    }
}

private final class HomeAudioWaveformView: UIView {

    private var bars: [UIView] = []
    private var barHeights: [CGFloat] = []

    func configure(accentColor: UIColor, seed: String) {
        tintColor = accentColor
        if bars.isEmpty {
            buildBars()
        }

        barHeights = Self.makeHeights(seed: seed, count: bars.count)
        bars.enumerated().forEach { index, bar in
            bar.backgroundColor = accentColor
            bar.layer.cornerRadius = 1.2
            bar.alpha = index > 30 ? 0.55 : 1
        }
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bars.isEmpty else { return }

        let spacing: CGFloat = 3
        let barWidth = max(2, (bounds.width - CGFloat(bars.count - 1) * spacing) / CGFloat(bars.count))
        for (index, bar) in bars.enumerated() {
            let height = min(bounds.height, barHeights.indices.contains(index) ? barHeights[index] : 8)
            let x = CGFloat(index) * (barWidth + spacing)
            bar.frame = CGRect(x: x, y: (bounds.height - height) / 2, width: barWidth, height: height)
        }
    }

    private func buildBars() {
        (0..<32).forEach { _ in
            let bar = UIView()
            addSubview(bar)
            bars.append(bar)
        }
    }

    private static func makeHeights(seed: String, count: Int) -> [CGFloat] {
        var value = abs(seed.hashValue % 997)
        return (0..<count).map { index in
            value = (value * 31 + index * 17 + 23) % 997
            let normalized = CGFloat(value % 14)
            return 3 + normalized
        }
    }
}
