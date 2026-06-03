//
//  HomeRecordingStatusCell.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/6/3.
//

import UIKit
import SnapKit
import AIRECBleKit

protocol HomeRecordingStatusCellDelegate: AnyObject {
    func homeRecordingStatusCellDidTapPause(_ cell: HomeRecordingStatusCell)
    func homeRecordingStatusCellDidTapStop(_ cell: HomeRecordingStatusCell)
    func homeRecordingStatusCellDidTapPlay(_ cell: HomeRecordingStatusCell)
}

final class HomeRecordingStatusCell: UITableViewCell {

    static let reuseId = "HomeRecordingStatusCell"

    weak var delegate: HomeRecordingStatusCellDelegate?

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let statusPillLabel = UILabel()
    private let deviceLabel = UILabel()
    private let timeLabel = UILabel()
    private let waveformView = RecordingStatusWaveformView()
    private let pauseButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        waveformView.isAnimatingWave = false
    }

    func configure(device: AIRECBleDevice?, elapsedText: String, isPaused: Bool) {
        titleLabel.text = isPaused ? "录音已暂停" : "正在录音"
        statusPillLabel.text = isPaused ? "已暂停" : "录音中"
        statusPillLabel.textColor = isPaused ? Theme.audioYellow : Theme.audioGreen
        statusPillLabel.backgroundColor = (isPaused ? Theme.audioYellow : Theme.audioGreen).withAlphaComponent(0.16)
        deviceLabel.text = device?.name.isEmpty == false ? "\(device!.name) · 蓝牙已连接" : "蓝牙录音卡 · 已连接"
        timeLabel.text = elapsedText
        pauseButton.setImage(UIImage(systemName: isPaused ? "play.fill" : "pause.fill"), for: .normal)
        pauseButton.accessibilityLabel = isPaused ? "继续录音" : "暂停录音"
        waveformView.isAnimatingWave = !isPaused
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.backgroundColor = Theme.bluetoothHeaderBackground
        cardView.layer.cornerRadius = 18
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = Theme.bluetoothHeaderBorder.cgColor
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }

        let topRow = UIStackView()
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10
        cardView.addSubview(topRow)
        topRow.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(18)
            make.left.right.equalToSuperview().inset(22)
        }

        titleLabel.textColor = Theme.bluetoothHeaderPrimaryText
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        topRow.addArrangedSubview(titleLabel)

        let spacer = UIView()
        topRow.addArrangedSubview(spacer)

        statusPillLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        statusPillLabel.textAlignment = .center
        statusPillLabel.layer.cornerRadius = 12
        statusPillLabel.clipsToBounds = true
        topRow.addArrangedSubview(statusPillLabel)
        statusPillLabel.snp.makeConstraints { make in
            make.width.equalTo(58)
            make.height.equalTo(24)
        }

        deviceLabel.textColor = Theme.bluetoothHeaderSecondaryText
        deviceLabel.font = .systemFont(ofSize: 14, weight: .medium)
        deviceLabel.lineBreakMode = .byTruncatingTail
        cardView.addSubview(deviceLabel)
        deviceLabel.snp.makeConstraints { make in
            make.top.equalTo(topRow.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(22)
        }

        timeLabel.textColor = Theme.bluetoothHeaderPrimaryText
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 42, weight: .semibold)
        timeLabel.textAlignment = .center
        timeLabel.adjustsFontSizeToFitWidth = true
        timeLabel.minimumScaleFactor = 0.75
        cardView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints { make in
            make.top.equalTo(deviceLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(22)
            make.height.equalTo(48)
        }

        waveformView.tintColor = Theme.audioYellow
        cardView.addSubview(waveformView)
        waveformView.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(10)
            make.left.right.equalToSuperview().inset(38)
            make.height.equalTo(26)
        }

        let buttonRow = UIStackView(arrangedSubviews: [pauseButton, stopButton, playButton])
        buttonRow.axis = .horizontal
        buttonRow.alignment = .center
        buttonRow.distribution = .equalSpacing
        cardView.addSubview(buttonRow)
        buttonRow.snp.makeConstraints { make in
            make.top.equalTo(waveformView.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(54)
            make.bottom.equalToSuperview().offset(-18)
        }

        configureRoundButton(pauseButton, systemName: "pause.fill", tintColor: Theme.bluetoothButtonText, backgroundColor: Theme.bluetoothButtonBackground)
        configureRoundButton(stopButton, systemName: "stop.fill", tintColor: .white, backgroundColor: UIColor(hexValue: 0xEF4444))
        configureRoundButton(playButton, systemName: "play.fill", tintColor: Theme.audioPlayTint, backgroundColor: Theme.audioPlayBackground)

        playButton.alpha = 0.45
        playButton.isEnabled = false
        pauseButton.addTarget(self, action: #selector(pauseTapped), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)
    }

    private func configureRoundButton(_ button: UIButton, systemName: String, tintColor: UIColor, backgroundColor: UIColor) {
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = tintColor
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 26
        button.imageEdgeInsets = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        button.snp.makeConstraints { make in
            make.width.height.equalTo(52)
        }
    }

    @objc private func pauseTapped() {
        delegate?.homeRecordingStatusCellDidTapPause(self)
    }

    @objc private func stopTapped() {
        delegate?.homeRecordingStatusCellDidTapStop(self)
    }

    @objc private func playTapped() {
        delegate?.homeRecordingStatusCellDidTapPlay(self)
    }
}

private final class RecordingStatusWaveformView: UIView {

    var isAnimatingWave = false {
        didSet {
            guard oldValue != isAnimatingWave else { return }
            if isAnimatingWave {
                startTimer()
            } else {
                timer?.invalidate()
                timer = nil
                setNeedsLayout()
            }
        }
    }

    private var bars: [UIView] = []
    private var phase = 0
    private var timer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildBars()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !bars.isEmpty else { return }

        let spacing: CGFloat = 4
        let barWidth = max(2, (bounds.width - CGFloat(bars.count - 1) * spacing) / CGFloat(bars.count))
        for (index, bar) in bars.enumerated() {
            let seed = CGFloat((index * 17 + phase * 11) % 19)
            let targetHeight = isAnimatingWave ? 5 + seed : 7 + CGFloat(index % 5) * 2
            let height = min(bounds.height, targetHeight)
            bar.frame = CGRect(x: CGFloat(index) * (barWidth + spacing), y: (bounds.height - height) / 2, width: barWidth, height: height)
        }
    }

    private func buildBars() {
        (0..<32).forEach { index in
            let bar = UIView()
            bar.backgroundColor = tintColor
            bar.alpha = index > 26 ? 0.45 : 1
            bar.layer.cornerRadius = 1.4
            addSubview(bar)
            bars.append(bar)
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.phase += 1
            UIView.animate(withDuration: 0.16) {
                self.setNeedsLayout()
                self.layoutIfNeeded()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }
}
