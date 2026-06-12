//
//  AudioPlayViewController.swift
//  AIRECIOSBleDemo
//
//  Created by 李龙飞 on 2026/6/10.
//

import UIKit
import AVFoundation
import SnapKit

final class AudioPlayViewController: UIViewController {

    private let filePath: String
    private let fileDate: String
    private let fileSize: String
    private let playbackManager = AudioPlaybackManager()

    private let headerView: AudioPlayHeaderView
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let waveformView = AudioWaveformView()
    private let rewindButton = UIButton(type: .custom)
    private let playPauseButton = UIButton(type: .custom)
    private let forwardButton = UIButton(type: .custom)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)

    private var waveformPath = ""

    init(filePath: String, fileName: String, fileDate: String = "", fileSize: String) {
        self.filePath = filePath
        self.fileDate = fileDate
        self.fileSize = fileSize
        self.headerView = AudioPlayHeaderView(fileName: fileName, fileDate: fileDate, fileSize: fileSize)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "音频播放"
        view.backgroundColor = Theme.pageBackground
        playbackManager.delegate = self
        buildUI()
        addAudioInterruptionObserver()
        setLoading(true)
        playbackManager.prepare(filePath: filePath)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        playbackManager.stop()
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
    }

    private func buildUI() {
        currentTimeLabel.text = "00:00"
        durationLabel.text = "--:--"
        currentTimeLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        currentTimeLabel.textColor = .white
        durationLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        durationLabel.textColor = .white
        [currentTimeLabel, durationLabel].forEach {
            $0.isHidden = false
        }
        durationLabel.textAlignment = .right

        waveformView.onSeekProgress = { [weak self] progress in
            guard let self else { return }
            let target = TimeInterval(progress) * self.playbackManager.duration
            self.playbackManager.seek(to: target)
        }

        let timeRow = UIView()
        timeRow.addSubview(currentTimeLabel)
        timeRow.addSubview(durationLabel)

        configureIconButton(rewindButton, imageName: "houtui10s", action: #selector(rewindTapped))
        configureIconButton(playPauseButton, imageName: "bofang", action: #selector(playPauseTapped))
        configureIconButton(forwardButton, imageName: "kuaijing10s", action: #selector(forwardTapped))
        playPauseButton.backgroundColor = Theme.audioBlue
        playPauseButton.layer.cornerRadius = 28
        playPauseButton.isEnabled = false

        let rewindItem = makeControlItem(button: rewindButton, title: "后退 10 秒")
        let playItem = makeControlItem(button: playPauseButton, title: "")
        let forwardItem = makeControlItem(button: forwardButton, title: "前进 10 秒")
        let controlRow = UIView()
        controlRow.addSubview(rewindItem)
        controlRow.addSubview(playItem)
        controlRow.addSubview(forwardItem)

        activityIndicator.hidesWhenStopped = true

        let waveformCard = UIView()
        waveformCard.backgroundColor = UIColor(hex: 0x031A3A)
        waveformCard.layer.cornerRadius = 14
        waveformCard.clipsToBounds = true
        waveformCard.addSubview(waveformView)
        waveformCard.addSubview(timeRow)

        let detailView = makeDetailView()
        view.addSubview(headerView)
        view.addSubview(waveformCard)
        view.addSubview(controlRow)
        view.addSubview(detailView)
        view.addSubview(activityIndicator)

        headerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
        }

        waveformCard.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(28)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
            make.height.equalTo(210)
        }

        waveformView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(timeRow.snp.top).offset(-8)
        }

        timeRow.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(24)
            make.right.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-18)
            make.height.equalTo(24)
        }

        currentTimeLabel.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(64)
        }

        durationLabel.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(64)
        }

        controlRow.snp.makeConstraints { make in
            make.top.equalTo(waveformCard.snp.bottom).offset(28)
            make.left.equalToSuperview().offset(42)
            make.right.equalToSuperview().offset(-42)
            make.height.equalTo(82)
        }

        rewindItem.snp.makeConstraints { make in
            make.centerX.equalTo(controlRow.snp.left).offset(48)
            make.centerY.equalToSuperview()
        }

        playItem.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        forwardItem.snp.makeConstraints { make in
            make.centerX.equalTo(controlRow.snp.right).offset(-48)
            make.centerY.equalToSuperview()
        }

        detailView.snp.makeConstraints { make in
            make.top.equalTo(controlRow.snp.bottom).offset(28)
            make.left.equalToSuperview().offset(20)
            make.right.equalToSuperview().offset(-20)
        }

        activityIndicator.snp.makeConstraints { make in
            make.center.equalTo(waveformCard)
        }
    }

    private func configureIconButton(_ button: UIButton, imageName: String, action: Selector) {
        button.setImage(UIImage(named: imageName), for: .normal)
        button.tintColor = Theme.audioBlue
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func makeControlItem(button: UIButton, title: String) -> UIView {
        let container = UIView()

        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor(hex: 0x333333)
        label.textAlignment = .center

        container.addSubview(button)
        container.addSubview(label)

        container.snp.makeConstraints { make in
            make.width.equalTo(96)
            make.height.equalTo(82)
        }

        button.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(56)
        }

        label.snp.makeConstraints { make in
            make.top.equalTo(button.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
            make.height.equalTo(title.isEmpty ? 0 : 20)
        }

        return container
    }

    private func makeDetailView() -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.pageControlBackground
        container.layer.cornerRadius = 12
        container.layer.borderWidth = 1
        container.layer.borderColor = Theme.pageControlBorder.cgColor

        let timeRow = makeDetailRow(iconName: "timeicon", title: "录音时间", value: fileDate)
        let sizeRow = makeDetailRow(iconName: "fileicon", title: "文件大小", value: fileSize)
        let separator = UIView()
        separator.backgroundColor = UIColor(hex: 0xEEF0F5)

        container.addSubview(timeRow)
        container.addSubview(separator)
        container.addSubview(sizeRow)

        timeRow.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.height.equalTo(82)
        }

        separator.snp.makeConstraints { make in
            make.top.equalTo(timeRow.snp.bottom)
            make.left.right.equalToSuperview()
            make.height.equalTo(1)
        }

        sizeRow.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom)
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(82)
        }

        return container
    }

    private func makeDetailRow(iconName: String, title: String, value: String) -> UIView {
        let row = UIView()

        let iconView = UIImageView(image: UIImage(named: iconName))
        iconView.contentMode = .scaleAspectFit

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = Theme.pageTitleText

        let valueLabel = UILabel()
        valueLabel.text = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "--" : value
        valueLabel.font = .systemFont(ofSize: 15)
        valueLabel.textColor = UIColor(hex: 0x333333)

        row.addSubview(iconView)
        row.addSubview(titleLabel)
        row.addSubview(valueLabel)

        iconView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(24)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(46)
        }

        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(iconView.snp.right).offset(18)
            make.right.equalToSuperview().offset(-20)
            make.top.equalToSuperview().offset(18)
        }

        valueLabel.snp.makeConstraints { make in
            make.left.right.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }

        return row
    }

    private func setLoading(_ loading: Bool) {
        loading ? activityIndicator.startAnimating() : activityIndicator.stopAnimating()
        playPauseButton.isEnabled = !loading
        rewindButton.isEnabled = !loading
        forwardButton.isEnabled = !loading
        waveformView.isUserInteractionEnabled = !loading
    }

    private func updatePlayPauseIcon(isPlaying: Bool) {
        playPauseButton.setImage(UIImage(named: isPlaying ? "zanting" : "bofang"), for: .normal)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(max(0, time))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func addAudioInterruptionObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    @objc private func playPauseTapped() {
        playbackManager.togglePlayPause()
    }

    @objc private func rewindTapped() {
        playbackManager.skip(by: -10)
    }

    @objc private func forwardTapped() {
        playbackManager.skip(by: 10)
    }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            playbackManager.pause()
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    playbackManager.play()
                }
            }
        @unknown default:
            break
        }
    }
}

extension AudioPlayViewController: AudioPlaybackManagerDelegate {
    func audioPlaybackManager(_ manager: AudioPlaybackManager, didPrepareFile path: String) {
        waveformPath = path
        AudioWaveformAnalyzer.analyze(path: path) { [weak self] amplitudes in
            guard let self, self.waveformPath == path else { return }
            self.waveformView.setAmplitudes(amplitudes)
        }
    }

    func audioPlaybackManager(_ manager: AudioPlaybackManager, didUpdate currentTime: TimeInterval, duration: TimeInterval) {
        setLoading(false)
        if duration > 0 {
            durationLabel.text = formatTime(duration)
            waveformView.setProgress(CGFloat(currentTime / duration))
        }
        currentTimeLabel.text = formatTime(currentTime)
    }

    func audioPlaybackManager(_ manager: AudioPlaybackManager, didChangePlaying isPlaying: Bool) {
        setLoading(false)
        updatePlayPauseIcon(isPlaying: isPlaying)
    }

    func audioPlaybackManager(_ manager: AudioPlaybackManager, didFailWith message: String) {
        setLoading(false)
        updatePlayPauseIcon(isPlaying: false)
        showAlert(title: "播放失败", message: message)
    }

    func audioPlaybackManagerDidFinish(_ manager: AudioPlaybackManager) {
        waveformView.setProgress(0)
        currentTimeLabel.text = "00:00"
        updatePlayPauseIcon(isPlaying: false)
    }
}
