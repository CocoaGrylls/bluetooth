import AVFoundation
import Foundation

protocol AudioPlaybackManagerDelegate: AnyObject {
    func audioPlaybackManager(_ manager: AudioPlaybackManager, didPrepareFile path: String)
    func audioPlaybackManager(_ manager: AudioPlaybackManager, didUpdate currentTime: TimeInterval, duration: TimeInterval)
    func audioPlaybackManager(_ manager: AudioPlaybackManager, didChangePlaying isPlaying: Bool)
    func audioPlaybackManager(_ manager: AudioPlaybackManager, didFailWith message: String)
    func audioPlaybackManagerDidFinish(_ manager: AudioPlaybackManager)
}

final class AudioPlaybackManager: NSObject {

    weak var delegate: AudioPlaybackManagerDelegate?

    private var audioPlayer: AVAudioPlayer?
    private var avPlayer: AVPlayer?
    private var progressTimer: Timer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private(set) var sourcePath: String = ""
    private(set) var currentPath: String = ""
    private let prepareQueue = DispatchQueue(label: "com.airec.audio.prepare", qos: .userInitiated)

    var isPlaying: Bool {
        audioPlayer?.isPlaying == true || avPlayer?.timeControlStatus == .playing
    }

    var currentTime: TimeInterval {
        if let audioPlayer {
            return audioPlayer.currentTime
        }
        if let avPlayer {
            let seconds = CMTimeGetSeconds(avPlayer.currentTime())
            return seconds.isFinite ? seconds : 0
        }
        return 0
    }

    var duration: TimeInterval {
        if let audioPlayer {
            return audioPlayer.duration
        }
        if let item = avPlayer?.currentItem {
            let seconds = CMTimeGetSeconds(item.duration)
            return seconds.isFinite ? seconds : 0
        }
        return 0
    }

    deinit {
        stop()
    }

    func prepare(filePath: String, autoPlay: Bool = true) {
        stop()
        sourcePath = filePath
        currentPath = filePath

        prepareQueue.async { [weak self] in
            guard let self else { return }

            guard FileManager.default.fileExists(atPath: filePath) else {
                DispatchQueue.main.async {
                    self.delegate?.audioPlaybackManager(self, didFailWith: "文件不存在：\(filePath)")
                }
                return
            }

            self.configureAudioSession()

            let formatCheck = ATWOpusConverter.isSupportedPrivateFormat(path: filePath)
            if formatCheck.supported {
                let formatName = formatCheck.format ?? "私有音频"
                ATWOpusConverter.convertToWAV(srcPath: filePath) { [weak self] wavPath in
                    guard let self else { return }
                    guard let wavPath else {
                        self.delegate?.audioPlaybackManager(self, didFailWith: "\(formatName) 格式转换失败")
                        return
                    }
                    self.prepareStandardFile(path: wavPath, autoPlay: autoPlay)
                }
                return
            }

            var playPath = filePath
            if URL(fileURLWithPath: filePath).pathExtension.isEmpty,
               let ext = Self.detectAudioExt(path: filePath) {
                let pathWithExt = filePath + ext
                if !FileManager.default.fileExists(atPath: pathWithExt) {
                    try? FileManager.default.copyItem(atPath: filePath, toPath: pathWithExt)
                }
                if FileManager.default.fileExists(atPath: pathWithExt) {
                    playPath = pathWithExt
                }
            }

            DispatchQueue.main.async {
                guard self.sourcePath == filePath else {
                    return
                }
                self.prepareStandardFile(path: playPath, autoPlay: autoPlay)
            }
        }
    }

    func play() {
        if let audioPlayer {
            audioPlayer.play()
        } else {
            avPlayer?.play()
        }
        startProgressUpdates()
        delegate?.audioPlaybackManager(self, didChangePlaying: isPlaying)
    }

    func pause() {
        audioPlayer?.pause()
        avPlayer?.pause()
        stopProgressTimer()
        delegate?.audioPlaybackManager(self, didChangePlaying: false)
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func stop() {
        audioPlayer?.stop()
        avPlayer?.pause()
        audioPlayer = nil
        removeAVPlayerObservers()
        avPlayer = nil
        stopProgressTimer()
    }

    func seek(to time: TimeInterval) {
        let target = max(0, min(time, duration > 0 ? duration : time))
        if let audioPlayer {
            audioPlayer.currentTime = target
        } else if let avPlayer {
            avPlayer.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        }
        notifyProgress()
    }

    func skip(by interval: TimeInterval) {
        seek(to: currentTime + interval)
    }

    func exportablePath(completion: @escaping (String?) -> Void) {
        let sourcePath = sourcePath
        let currentPath = currentPath

        prepareQueue.async {
            let formatCheck = ATWOpusConverter.isSupportedPrivateFormat(path: sourcePath)
            if formatCheck.supported {
                ATWOpusConverter.convertToOggOpus(srcPath: sourcePath) { path in
                    completion(path)
                }
                return
            }

            var path = currentPath.isEmpty ? sourcePath : currentPath
            if URL(fileURLWithPath: path).pathExtension.isEmpty,
               let ext = Self.detectAudioExt(path: path) {
                let pathWithExt = path + ext
                if !FileManager.default.fileExists(atPath: pathWithExt) {
                    try? FileManager.default.copyItem(atPath: path, toPath: pathWithExt)
                }
                path = pathWithExt
            }
            DispatchQueue.main.async {
                completion(FileManager.default.fileExists(atPath: path) ? path : nil)
            }
        }
    }

    private func prepareStandardFile(path: String, autoPlay: Bool) {
        currentPath = path
        delegate?.audioPlaybackManager(self, didPrepareFile: path)
        let url = URL(fileURLWithPath: path)
        let ext = url.pathExtension.lowercased()

        if ["opus", "ogg", "caf"].contains(ext) {
            prepareAVPlayer(url: url, autoPlay: autoPlay)
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            audioPlayer = player
            player.delegate = self
            player.prepareToPlay()
            delegate?.audioPlaybackManager(self, didUpdate: 0, duration: player.duration)
            if autoPlay {
                play()
            }
        } catch {
            prepareAVPlayer(url: url, autoPlay: autoPlay)
        }
    }

    private func prepareAVPlayer(url: URL, autoPlay: Bool) {
        removeAVPlayerObservers()

        let ext = url.pathExtension.lowercased()
        let item: AVPlayerItem
        if ext == "ogg" || ext == "opus" {
            let asset = AVURLAsset(url: url, options: ["AVURLAssetOutOfBandMIMETypeKey": "audio/ogg; codecs=opus"])
            item = AVPlayerItem(asset: asset)
        } else {
            item = AVPlayerItem(url: url)
        }

        let player = AVPlayer(playerItem: item)
        avPlayer = player
        delegate?.audioPlaybackManager(self, didUpdate: 0, duration: 0)

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] observedItem, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                switch observedItem.status {
                case .readyToPlay:
                    self.notifyProgress()
                    if autoPlay {
                        self.play()
                    }
                case .failed:
                    self.delegate?.audioPlaybackManager(self, didFailWith: observedItem.error?.localizedDescription ?? "音频播放失败")
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.handleFinished()
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] _ in
            self?.notifyProgress()
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("AudioPlaybackManager audio session error: \(error.localizedDescription)")
            }
        }
    }

    private func startProgressUpdates() {
        guard audioPlayer != nil else { return }
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.notifyProgress()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func notifyProgress() {
        delegate?.audioPlaybackManager(self, didUpdate: currentTime, duration: duration)
    }

    private func handleFinished() {
        stopProgressTimer()
        seek(to: 0)
        delegate?.audioPlaybackManager(self, didChangePlaying: false)
        delegate?.audioPlaybackManagerDidFinish(self)
    }

    private func removeAVPlayerObservers() {
        if let timeObserver, let avPlayer {
            avPlayer.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        handleFinished()
    }

    static func detectAudioExt(path: String) -> String? {
        guard let fileHandle = FileHandle(forReadingAtPath: path),
              let headerData = try? fileHandle.read(upToCount: 12),
              headerData.count >= 8 else {
            return nil
        }
        try? fileHandle.close()
        let bytes = [UInt8](headerData)
        if bytes[0] == 0x63 && bytes[1] == 0x61 && bytes[2] == 0x66 && bytes[3] == 0x66 { return ".caf" }
        if bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33 { return ".mp3" }
        if bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0 { return ".mp3" }
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 { return ".wav" }
        if bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53 { return ".opus" }
        if bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0 { return ".aac" }
        if bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43 { return ".flac" }
        if bytes[0] == 0x23 && bytes[1] == 0x21 && bytes[2] == 0x41 && bytes[3] == 0x4D { return ".amr" }
        if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 { return ".m4a" }
        if bytes[0] == 0x5B && bytes[1] == 0x50 { return ".atw" }
        if bytes[0] == 0x4B && bytes[1] == 0x41 { return ".ka" }
        return nil
    }
}

extension AudioPlaybackManager: AVAudioPlayerDelegate {}
