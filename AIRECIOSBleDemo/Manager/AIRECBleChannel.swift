import Foundation
import AIRECBleKit

typealias AIRECBleChannelObserver = AIRECBleDelegate

final class AIRECBleChannel: NSObject {

    static let shared = AIRECBleChannel()

    private let manager = AIRECBleManager.shared
    private var observers: [WeakObserver] = []

    private override init() {
        super.init()
        activate()
    }

    func activate() {
        manager.delegate = self
    }

    func addObserver(_ observer: AIRECBleChannelObserver) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.activate()
            self.compactObservers()

            let id = ObjectIdentifier(observer)
            guard !self.observers.contains(where: { $0.id == id }) else { return }
            self.observers.append(WeakObserver(observer))
        }
    }

    func removeObserver(_ observer: AIRECBleChannelObserver) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            let id = ObjectIdentifier(observer)
            self.observers.removeAll { $0.value == nil || $0.id == id }
        }
    }

    func removeAllObservers() {
        runOnMain { [weak self] in
            self?.observers.removeAll()
        }
    }

    private func notify(_ block: @escaping (AIRECBleChannelObserver) -> Void) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.compactObservers()
            self.observers.compactMap(\.value).forEach(block)
        }
    }

    private func compactObservers() {
        observers.removeAll { $0.value == nil }
    }

    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

// MARK: - AIRECBleManager Proxy
extension AIRECBleChannel {

    var isConnected: Bool { manager.isConnected }
    var connectedDevice: AIRECBleDevice? { manager.getConnectedDevice() }
    var ledSwitch: Bool { manager.ledSwitch }
    var noiseSwitch: Bool { manager.noiseSwitch }
    var usbSwitch: Bool { manager.usbSwitch }
    var powerOnRecord: Bool { manager.powerOnRecord }
    var diskFormatSupport: Bool { manager.diskFormatSupport }
    var segmentDuration: Int { manager.segmentDuration }
    var idleShutdown: Int { manager.idleShutdown }
    var micGain: Int { manager.micGain }
    var macAddress: String { manager.macAddress }

    var onAudioStreamData: ((Data) -> Void)? {
        get { manager.onAudioStreamData }
        set { manager.onAudioStreamData = newValue }
    }

    var onFormatResult: ((Bool, String) -> Void)? {
        get { manager.onFormatResult }
        set { manager.onFormatResult = newValue }
    }

    func setup() {
        activate()
        manager.setup()
    }

    func getConnectedDevice() -> AIRECBleDevice? {
        manager.getConnectedDevice()
    }

    func startScan() {
        activate()
        manager.startScan()
    }

    func stopScan() {
        manager.stopScan()
    }

    func connect(_ device: AIRECBleDevice) {
        activate()
        manager.connect(device)
    }

    func disconnect() {
        manager.disconnect()
    }

    func fetchDeviceInfo() {
        activate()
        manager.fetchDeviceInfo()
    }

    func fetchAllDeviceInfo() {
        activate()
        manager.fetchAllDeviceInfo()
    }

    func fetchFirmwareVersion() {
        activate()
        manager.fetchFirmwareVersion()
    }

    func fetchFileList() {
        activate()
        manager.fetchFileList()
    }

    func deleteFile(_ fileName: String) {
        activate()
        manager.deleteFile(fileName)
    }

    func startRecord() {
        activate()
        manager.startRecord()
    }

    func pauseRecord() {
        activate()
        manager.pauseRecord()
    }

    func resumeRecord() {
        activate()
        manager.resumeRecord()
    }

    func endRecord() {
        activate()
        manager.endRecord()
    }

    func fetchInitParam() {
        activate()
        manager.fetchInitParam()
    }

    func sendLedSwitch(_ on: Bool) {
        activate()
        manager.sendLedSwitch(on)
    }

    func sendNoiseSwitch(_ on: Bool) {
        activate()
        manager.sendNoiseSwitch(on)
    }

    func sendUsbSwitch(_ on: Bool) {
        activate()
        manager.sendUsbSwitch(on)
    }

    func sendPowerOnRecord(_ on: Bool) {
        activate()
        manager.sendPowerOnRecord(on)
    }

    func sendSegmentDuration(_ minutes: Int) {
        activate()
        manager.sendSegmentDuration(minutes)
    }

    func sendIdleShutdown(_ minutes: Int) {
        activate()
        manager.sendIdleShutdown(minutes)
    }

    func sendMicGain(_ gain: Int) {
        activate()
        manager.sendMicGain(gain)
    }

    func sendFormatDisk() {
        activate()
        manager.sendFormatDisk()
    }

    func downloadFile(_ file: AIRECBleFile) {
        activate()
        manager.downloadFile(file)
    }

    func cancelDownload() {
        manager.cancelDownload()
    }

    func isDownloaded(_ fileName: String) -> Bool {
        manager.isDownloaded(fileName)
    }

    func getLocalPath(_ fileName: String) -> String? {
        manager.getLocalPath(fileName)
    }
}

// MARK: - AIRECBleDelegate
extension AIRECBleChannel: AIRECBleDelegate {

    func bleManager(_ manager: AIRECBleManager, didDiscover device: AIRECBleDevice) {
        notify { $0.bleManager(manager, didDiscover: device) }
    }

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        notify { $0.bleManager(manager, didConnect: device) }
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        notify { $0.bleManager(manager, didDisconnect: device, reason: reason) }
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateDeviceInfo device: AIRECBleDevice) {
        notify { $0.bleManager(manager, didUpdateDeviceInfo: device) }
    }

    func bleManager(_ manager: AIRECBleManager, didReceiveFirmwareVersion version: String) {
        notify { $0.bleManager(manager, didReceiveFirmwareVersion: version) }
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        notify { $0.bleManager(manager, didChangeBluetoothState: enabled) }
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateFileList files: [AIRECBleFile]) {
        notify { $0.bleManager(manager, didUpdateFileList: files) }
    }

    func bleManager(_ manager: AIRECBleManager, didDeleteFile fileName: String, success: Bool) {
        notify { $0.bleManager(manager, didDeleteFile: fileName, success: success) }
    }

    func bleManager(_ manager: AIRECBleManager, didChangeRecordState recording: Bool, fileName: String) {
        notify { $0.bleManager(manager, didChangeRecordState: recording, fileName: fileName) }
    }

    func bleManagerDidPauseRecord(_ manager: AIRECBleManager) {
        notify { $0.bleManagerDidPauseRecord(manager) }
    }

    func bleManager(_ manager: AIRECBleManager, didQueryRecordStatus recording: Bool, paused: Bool, fileName: String) {
        notify { $0.bleManager(manager, didQueryRecordStatus: recording, paused: paused, fileName: fileName) }
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateRecordDuration durationSec: Int64) {
        notify { $0.bleManager(manager, didUpdateRecordDuration: durationSec) }
    }

    func bleManager(_ manager: AIRECBleManager, downloadProgress file: AIRECBleFile, progress: Int) {
        notify { $0.bleManager(manager, downloadProgress: file, progress: progress) }
    }

    func bleManager(_ manager: AIRECBleManager, downloadComplete file: AIRECBleFile, localPath: String) {
        notify { $0.bleManager(manager, downloadComplete: file, localPath: localPath) }
    }

    func bleManager(_ manager: AIRECBleManager, downloadFailed file: AIRECBleFile, reason: String) {
        notify { $0.bleManager(manager, downloadFailed: file, reason: reason) }
    }
}

private final class WeakObserver {
    weak var value: AIRECBleChannelObserver?
    let id: ObjectIdentifier

    init(_ value: AIRECBleChannelObserver) {
        self.value = value
        self.id = ObjectIdentifier(value)
    }
}
