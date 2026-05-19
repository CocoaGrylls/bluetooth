import UIKit
import AVFoundation
import AVKit

/// 音频播放
/// 支持：普通音频 / ATW私有Opus格式自动转换 / 进度条 / 快进快退 / 保存文件
class PlayerViewController: UIViewController {

    // MARK: - 外部传入参数
    private let filePath: String
    private let fileName: String
    private let fileSize: String
    private var currentPlayPath: String = ""

    // MARK: - 播放器
    private var player: AVAudioPlayer?
    private var avPlayer: AVPlayer?
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var engineDuration: TimeInterval = 0
    private var progressTimer: Timer?
    private var isDraggingSlider = false

    // MARK: - UI
    private let fileNameLabel = UILabel()
    private let fileSizeLabel  = UILabel()
    private let currentLabel   = UILabel()
    private let durationLabel  = UILabel()
    private let slider         = UISlider()
    private let playPauseBtn   = UIButton(type: .system)
    private let rewindBtn      = UIButton(type: .system)
    private let forwardBtn     = UIButton(type: .system)
    private let saveBtn        = UIButton(type: .system)

    // MARK: - init
    init(filePath: String, fileName: String, fileSize: String) {
        self.filePath = filePath
        self.fileName = fileName
        self.fileSize = fileSize
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 生命周期
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "播放器"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeTapped))
        buildUI()

        // 监听音频中断（电话、语音助手等）
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleAudioInterruption),
            name: AVAudioSession.interruptionNotification, object: nil)

        preparePlayer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.stop()
        avPlayer?.pause()
        playerNode?.stop()
        audioEngine?.stop()
        progressTimer?.invalidate()
        if let item = avPlayer?.currentItem {
            item.removeObserver(self, forKeyPath: "status")
        }
        avPlayer = nil
        player = nil
        audioEngine = nil
        playerNode = nil
        audioFile = nil
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureAudioSession()
    }

    // MARK: - UI
    private func buildUI() {
        fileNameLabel.text = fileName
        fileNameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        fileNameLabel.textAlignment = .center
        fileNameLabel.numberOfLines = 2

        fileSizeLabel.text = "大小：\(fileSize)"
        fileSizeLabel.font = .systemFont(ofSize: 13)
        fileSizeLabel.textColor = .secondaryLabel
        fileSizeLabel.textAlignment = .center

        currentLabel.text = "00:00"
        durationLabel.text = "--:--"
        currentLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        durationLabel.textAlignment = .right

        slider.minimumValue = 0
        slider.addTarget(self, action: #selector(sliderMoved), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderUp), for: [.touchUpInside, .touchUpOutside])

        let timeRow = UIStackView(arrangedSubviews: [currentLabel, slider, durationLabel])
        timeRow.axis = .horizontal; timeRow.spacing = 8; timeRow.alignment = .center
        currentLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true
        durationLabel.widthAnchor.constraint(equalToConstant: 44).isActive = true

        rewindBtn.setImage(UIImage(systemName: "gobackward.10"), for: .normal)
        rewindBtn.addTarget(self, action: #selector(rewindTapped), for: .touchUpInside)

        playPauseBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseBtn.addTarget(self, action: #selector(playPauseTapped), for: .touchUpInside)
        playPauseBtn.isEnabled = false

        forwardBtn.setImage(UIImage(systemName: "goforward.10"), for: .normal)
        forwardBtn.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)

        rewindBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true
        playPauseBtn.heightAnchor.constraint(equalToConstant: 56).isActive = true
        forwardBtn.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let ctrlRow = UIStackView(arrangedSubviews: [rewindBtn, playPauseBtn, forwardBtn])
        ctrlRow.axis = .horizontal; ctrlRow.spacing = 32; ctrlRow.alignment = .center

        saveBtn.setTitle("保存到文件", for: .normal)
        saveBtn.backgroundColor = .systemBlue
        saveBtn.setTitleColor(.white, for: .normal)
        saveBtn.layer.cornerRadius = 10
        saveBtn.heightAnchor.constraint(equalToConstant: 48).isActive = true
        saveBtn.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        let card = UIView()
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [fileNameLabel, fileSizeLabel, timeRow, ctrlRow, saveBtn])
        stack.axis = .vertical; stack.spacing = 24; stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(stack)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            ctrlRow.centerXAnchor.constraint(equalTo: stack.centerXAnchor)
        ])
    }

    // MARK: - 准备播放器（格式检测 + ATW/KA转换）
    private func preparePlayer() {
        var playPath = filePath
        let fileURL = URL(fileURLWithPath: filePath)

        let exists = FileManager.default.fileExists(atPath: filePath)
        print("📂 准备播放: \(filePath)\n   文件存在: \(exists)\n   扩展名: [\(fileURL.pathExtension)]")

        guard exists else { showAlert(title: "文件不存在", message: filePath); return }

        let headerHex = readFileHeaderHex(path: filePath, length: 16)
        print("   文件头(16字节): \(headerHex)")

        let formatCheck = ATWOpusConverter.isSupportedPrivateFormat(path: filePath)
        print("   私有格式检测: \(formatCheck.supported ? formatCheck.format! : "不支持")")

        if formatCheck.supported {
            let formatName = formatCheck.format!
            print("✅ 检测到 \(formatName) 格式，准备转换为 WAV...")
            for ext in [".opus", ".ogg", ".caf", ".wav", ".m4a"] {
                try? FileManager.default.removeItem(atPath: filePath + ext)
            }
            showToast("正在转换 \(formatName) → WAV...")
            let srcPath = filePath
            ATWOpusConverter.convertToWAV(srcPath: srcPath) { [weak self] wavPath in
                guard let self = self else { return }
                if let path = wavPath {
                    print("   \(formatName) → WAV 转换成功: \(path)")
                    self.preparePlayerWithPath(path)
                } else {
                    print("   \(formatName) → WAV 转换失败")
                    self.showAlert(title: "转换失败", message: "\(formatName)格式无法播放")
                }
            }
            return
        }

        // 无扩展名 → 尝试识别格式
        if fileURL.pathExtension.isEmpty {
            print("   文件无扩展名，尝试检测格式...")
            if let ext = detectAudioExt(path: filePath) {
                let extName = String(ext.dropFirst())
                print("   检测到格式: \(extName)")
                let newURL = fileURL.appendingPathExtension(extName)
                if (try? FileManager.default.moveItem(at: fileURL, to: newURL)) != nil {
                    print("   重命名成功: \(newURL.path)")
                    playPath = newURL.path
                }
            } else {
                print("   ⚠️ 无法识别音频格式，将尝试直接播放")
            }
        }

        print("🎵 最终播放路径: \(playPath)")
        preparePlayerWithPath(playPath)
    }

    /// 检查缓存的 CAF 文件是否有效（是否有 uuid chunk）
    /// 旧缓存没有 uuid chunk，播放会无声
    private func isValidCafCache(_ path: String) -> Bool {
        guard let fh = FileHandle(forReadingAtPath: path),
              let data = try? fh.read(upToCount: 64), data.count >= 64 else {
            return false
        }
        try? fh.close()
        let header = [UInt8](data)
        // 检查 caff 头
        if header[0] != 0x63 || header[1] != 0x61 || header[2] != 0x66 || header[3] != 0x66 {
            return false
        }
        // 查找 uuid chunk magic: 'u','u','i','d'
        for i in 48..<(data.count - 4) {
            if data[i] == 0x75 && data[i+1] == 0x75 &&
               data[i+2] == 0x69 && data[i+3] == 0x64 {
                return true
            }
        }
        return false
    }

    private func readFileHeaderHex(path: String, length: Int) -> String {
        guard let fh = FileHandle(forReadingAtPath: path),
              let data = try? fh.read(upToCount: length), data.count >= 4 else { return "数据不足" }
        try? fh.close()
        return [UInt8](data).map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    // MARK: - 音频会话
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 必须与 SDK（AIRECAudioPlayer）保持一致用 .playAndRecord + .defaultToSpeaker
            // 否则 BLE 录音流已设置 playAndRecord 后，切换到 .playback 会报 -50
            try session.setCategory(.playAndRecord, mode: .default,
                                   options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ 音频会话配置成功")
        } catch {
            print("❌ 音频会话配置失败: \(error.localizedDescription)")
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                print("✅ 音频会话降级配置成功")
            } catch {
                print("❌ 音频会话降级配置也失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 初始化播放器（OGG Opus → AVPlayer 优先，其他格式 → AVAudioPlayer）
    private func preparePlayerWithPath(_ path: String) {
        print("🎵 preparePlayerWithPath 开始播放: \(path)")
        currentPlayPath = path
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ 文件不存在: \(path)")
            showAlert(title: "文件不存在", message: path); return
        }

        if let attrs = try? FileManager.default.attributesOfItem(atPath: path), let size = attrs[.size] as? Int64 {
            print("📁 文件大小: \(size) bytes")
        }

        configureAudioSession()

        // OGG/Opus/CAF Opus 文件直接用 AVPlayer
        let ext = url.pathExtension.lowercased()
        if ext == "opus" || ext == "ogg" || ext == "caf" {
            print("🔍 \(ext.uppercased()) 格式，直接使用 AVPlayer...")
            playPauseBtn.isEnabled = true
            tryAVPlayer()
            return
        }

        // 其他格式先尝试 AVAudioPlayer
        print("🔍 尝试使用 AVAudioPlayer...")
        do {
            let ap = try AVAudioPlayer(contentsOf: url)
            player = ap
            ap.delegate = self
            ap.prepareToPlay()
            slider.maximumValue = Float(ap.duration)
            durationLabel.text = formatTime(ap.duration)

            print("   音频格式: \(ap.format.channelCount) 声道, 采样率: \(ap.format.sampleRate) Hz")

            ap.play()
            print("   play() 调用后: isPlaying=\(ap.isPlaying)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                if self.player?.isPlaying == true {
                    self.updatePlayPauseIcon()
                    self.startProgressTimer()
                    self.playPauseBtn.isEnabled = true
                } else {
                    print("   ⚠️ AVAudioPlayer 播放失败，降级到 AVPlayer")
                    self.player = nil
                    self.tryAVPlayer()
                }
            }
        } catch {
            print("   ❌ AVAudioPlayer 初始化失败: \(error.localizedDescription)")
            tryAVPlayer()
        }
    }

    private func tryAVPlayer() {
        _avPlayerStatusObserved = false
        let path = currentPlayPath
        print("🔍 尝试使用 AVPlayer... path=\(path)")
        let url = URL(fileURLWithPath: path)
        // 对 OGG/Opus 文件，用 AVURLAsset 指定 MIME type 帮助 AVPlayer 识别格式
        let ext = url.pathExtension.lowercased()
        let item: AVPlayerItem
        if ext == "ogg" || ext == "opus" {
            let asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/ogg; codecs=opus"])
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }
        let ap2 = AVPlayer(playerItem: item)
        avPlayer = ap2

        // 播放结束通知
        NotificationCenter.default.addObserver(self, selector: #selector(avPlayerDidEnd), name: .AVPlayerItemDidPlayToEndTime, object: item)
        // 状态监听，readyToPlay 时自动触发播放
        item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)

        print("📡 开始播放...")
        // 先让 AVPlayer 加载文件，readyToPlay 时再 play()
        ap2.play()
        playPauseBtn.isEnabled = true
        playPauseBtn.setImage(UIImage(systemName: "pause.fill"), for: .normal)
        durationLabel.text = "--:--"
        startProgressTimer()
    }

    // AVPlayer KVO 状态观察者，防止重复移除
    private var _avPlayerStatusObserved = false

    // MARK: - AVPlayer 状态监听
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status", let item = object as? AVPlayerItem {
            // 只移除一次观察者
            if !_avPlayerStatusObserved {
                _avPlayerStatusObserved = true
                item.removeObserver(self, forKeyPath: "status")
            }

            print("📊 AVPlayerItem status changed: \(item.status.rawValue)")
            switch item.status {
            case .failed:
                let errorMsg = item.error?.localizedDescription ?? "未知错误"
                let errorCode = item.error?._code ?? -1
                print("❌ AVPlayer 播放失败: \(errorMsg), code: \(errorCode)\n   文件路径: \(filePath)")
                avPlayer?.pause()
                avPlayer = nil
                progressTimer?.invalidate()
                tryATWFallback()
            case .readyToPlay:
                print("✅ AVPlayer 准备就绪，重新播放...")
                if let dur = item.duration.seconds as Double?, dur.isFinite && dur > 0 {
                    DispatchQueue.main.async {
                        self.slider.maximumValue = Float(dur)
                        self.durationLabel.text = self.formatTime(dur)
                    }
                }
                avPlayer?.play()
            case .unknown:
                print("⏳ AVPlayer 状态未知...")
            @unknown default:
                print("⚠️ AVPlayer 未知状态")
            }
        }
    }

    /// AVPlayer 失败后，尝试 AVAudioEngine 播放（支持 CAF Opus）
    private func tryATWFallback() {
        print("🔍 尝试使用 AVAudioEngine...")
        // 确保有 CAF 文件
        let cafPath = filePath + ".caf"
        let oggPath = filePath + ".ogg"
        let pathToPlay = FileManager.default.fileExists(atPath: cafPath) ? cafPath :
                         (FileManager.default.fileExists(atPath: oggPath) ? oggPath : currentPlayPath)
        tryAudioEngine(path: pathToPlay)
    }

    private func tryAudioEngine(path: String) {
        do {
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            audioFile = file
            let format = file.processingFormat
            engineDuration = Double(file.length) / format.sampleRate

            let engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            audioEngine = engine
            playerNode = node

            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            try engine.start()

            node.scheduleFile(file, at: nil) { [weak self] in
                DispatchQueue.main.async {
                    self?.progressTimer?.invalidate()
                    self?.slider.value = 0
                    self?.currentLabel.text = "00:00"
                    self?.playPauseBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
                }
            }
            node.play()

            slider.maximumValue = Float(engineDuration)
            durationLabel.text = formatTime(engineDuration)
            playPauseBtn.isEnabled = true
            playPauseBtn.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            startProgressTimer()
            print("✅ AVAudioEngine 播放成功，时长: \(formatTime(engineDuration))")
        } catch {
            print("❌ AVAudioEngine 播放失败: \(error.localizedDescription)")
            showAlert(title: "播放失败", message: "所有播放方式均失败\n\(error.localizedDescription)")
        }
    }

    // MARK: - 进度刷新
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.updateProgress() }
    }

    private func updateProgress() {
        if let node = playerNode, node.isPlaying, let file = audioFile {
            if let nodeTime = node.lastRenderTime,
               let playerTime = node.playerTime(forNodeTime: nodeTime) {
                let t = Double(playerTime.sampleTime) / playerTime.sampleRate
                if t.isFinite && t >= 0 {
                    slider.value = Float(t)
                    currentLabel.text = formatTime(t)
                }
            }
        } else if let p = player {
            slider.value = Float(p.currentTime)
            currentLabel.text = formatTime(p.currentTime)
        } else if let ap = avPlayer {
            let t = CMTimeGetSeconds(ap.currentTime())
            if t.isFinite { slider.value = Float(t); currentLabel.text = formatTime(t) }
            if let dur = ap.currentItem?.duration, dur.isNumeric {
                let d = CMTimeGetSeconds(dur)
                if slider.maximumValue == 0 { slider.maximumValue = Float(d); durationLabel.text = formatTime(d) }
            }
        }
    }

    private func updatePlayPauseIcon() {
        let isPlaying = player?.isPlaying == true
            || avPlayer?.timeControlStatus == .playing
            || playerNode?.isPlaying == true
        playPauseBtn.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill"), for: .normal)
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let seconds = Int(max(0, t))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - 格式检测
    private func detectAudioExt(path: String) -> String? {
        guard let fh = FileHandle(forReadingAtPath: path),
              let headerData = try? fh.read(upToCount: 12), headerData.count >= 4 else { return nil }
        try? fh.close()
        let bytes = [UInt8](headerData)
        print("      格式检测字节: \(bytes.prefix(8).map { String(format: "%02X", $0) }.joined(separator: " "))")
        if bytes[0]==0x63&&bytes[1]==0x61&&bytes[2]==0x66&&bytes[3]==0x66 { return ".caf" }
        if bytes[0]==0x49&&bytes[1]==0x44&&bytes[2]==0x33 { return ".mp3" }
        if bytes[0]==0xFF&&(bytes[1]&0xE0)==0xE0 { return ".mp3" }
        if bytes[0]==0x52&&bytes[1]==0x49&&bytes[2]==0x46&&bytes[3]==0x46 { return ".wav" }
        if bytes[0]==0x4F&&bytes[1]==0x67&&bytes[2]==0x67&&bytes[3]==0x53 { return ".opus" }
        if bytes[0]==0xFF&&(bytes[1]&0xF0)==0xF0 { return ".aac" }
        if bytes[0]==0x66&&bytes[1]==0x4C&&bytes[2]==0x61&&bytes[3]==0x43 { return ".flac" }
        if bytes[0]==0x23&&bytes[1]==0x21&&bytes[2]==0x41&&bytes[3]==0x4D { return ".amr" }
        if bytes[4]==0x66&&bytes[5]==0x74&&bytes[6]==0x79&&bytes[7]==0x70 { return ".m4a" }
        if bytes[0]==0x5B&&bytes[1]==0x50 { return ".atw" }
        if bytes[0]==0x4B&&bytes[1]==0x41 { return ".ka" }
        print("      无法识别格式"); return nil
    }

    // MARK: - 按钮事件
    @objc private func playPauseTapped() {
        if let node = playerNode {
            if node.isPlaying { node.pause() } else { node.play() }
            node.isPlaying ? startProgressTimer() : progressTimer?.invalidate()
        } else if let p = player {
            if p.isPlaying { p.pause() } else { p.play() }
            if p.isPlaying { startProgressTimer() } else { progressTimer?.invalidate() }
        } else if let ap = avPlayer {
            ap.timeControlStatus == .playing ? ap.pause() : ap.play()
            ap.timeControlStatus == .playing ? startProgressTimer() : progressTimer?.invalidate()
        }
        updatePlayPauseIcon()
    }

    @objc private func rewindTapped() {
        if let p = player { p.currentTime = max(0, p.currentTime - 10) }
        else if let ap = avPlayer { ap.seek(to: CMTime(seconds: max(0, CMTimeGetSeconds(ap.currentTime()) - 10), preferredTimescale: 1)) }
        updateProgress()
    }

    @objc private func forwardTapped() {
        if let p = player { p.currentTime = min(p.duration, p.currentTime + 10) }
        else if let ap = avPlayer { ap.seek(to: CMTime(seconds: CMTimeGetSeconds(ap.currentTime()) + 10, preferredTimescale: 1)) }
        updateProgress()
    }

    @objc private func sliderMoved() {
        currentLabel.text = formatTime(TimeInterval(slider.value))
    }

    @objc private func sliderUp() {
        if let p = player { p.currentTime = TimeInterval(slider.value) }
        else if let ap = avPlayer { ap.seek(to: CMTime(seconds: Double(slider.value), preferredTimescale: 1)) }
    }

    @objc private func avPlayerDidEnd() {
        progressTimer?.invalidate()
        slider.value = 0; currentLabel.text = "00:00"
        playPauseBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
    }

    @objc private func saveTapped() {
        // 先检查是否 ATW/KA 私有格式 → 转为 OGG Opus 再导出
        let formatCheck = ATWOpusConverter.isSupportedPrivateFormat(path: filePath)
        if formatCheck.supported {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating(); spinner.center = view.center; view.addSubview(spinner)
            ATWOpusConverter.convertToOggOpus(srcPath: filePath) { [weak self] path in
                spinner.removeFromSuperview()
                guard let path = path else {
                    self?.showAlert(title: "导出失败", message: "无法导出音频"); return
                }
                self?.shareFile(path: path)
            }
            return
        }

        // 标准格式文件 → 确保有扩展名后直接分享
        var sharePath = currentPlayPath
        // 如果 currentPlayPath 是原始 ATW/KA 文件但没扩展名，尝试加扩展名
        if !currentPlayPath.contains(".") {
            if let ext = detectAudioExt(path: currentPlayPath) {
                let newPath = currentPlayPath + ext
                if !FileManager.default.fileExists(atPath: newPath) {
                    try? FileManager.default.copyItem(atPath: currentPlayPath, toPath: newPath)
                }
                sharePath = newPath
            }
        }
        guard FileManager.default.fileExists(atPath: sharePath) else {
            showAlert(title: "导出失败", message: "文件不存在")
            return
        }
        shareFile(path: sharePath)
    }

    private func shareFile(path: String) {
        let vc = UIActivityViewController(activityItems: [URL(fileURLWithPath: path)], applicationActivities: nil)
        if let popover = vc.popoverPresentationController {
            popover.sourceView = saveBtn
            popover.sourceRect = saveBtn.bounds
        }
        present(vc, animated: true)
    }

    @objc private func closeTapped() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        navigationController?.popViewController(animated: true)
    }

    /// 处理音频中断（电话打断等），中断结束后自动恢复播放
    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            print("🔇 音频中断，开始")
            player?.pause()
            avPlayer?.pause()
        case .ended:
            print("🔊 音频中断结束")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    configureAudioSession()
                    player?.play()
                    avPlayer?.play()
                }
            }
        @unknown default:
            break
        }
    }

    /// 验证 OGG 缓存文件的 OpusHead 是否为标准 19 字节
    private func isValidOggCache(_ path: String) -> Bool {
        guard let fh = FileHandle(forReadingAtPath: path),
              let data = try? fh.read(upToCount: 100), data.count >= 47 else { return false }
        try? fh.close()
        let bytes = [UInt8](data)
        // 检查 OggS 头
        guard bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53 else { return false }
        // segment table 在 offset 27，第一个 segment 的大小就是 OpusHead 的大小
        let numSegs = Int(bytes[26])
        guard numSegs >= 1 else { return false }
        let opusHeadSize = Int(bytes[27])
        // 标准 OpusHead = 19 字节，旧的错误版本 = 21 字节
        return opusHeadSize == 19
    }

}

// MARK: - AVAudioPlayerDelegate
extension PlayerViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        progressTimer?.invalidate()
        slider.value = 0; currentLabel.text = "00:00"
        updatePlayPauseIcon()
    }
}
