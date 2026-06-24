//
//  HomeViewViewController.swift
//  AIRECIOSBleDemo
//
//  Created by 李龙飞 on 2026/5/21.
//

import UIKit
import SnapKit
import AIRECBleKit

class HomeViewViewController: UIViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)

    private var fileStates: [String: HomeRecordingFileCell.State] = [:]
    private var localItems: [LocalAudioRecord] = []
    private var deviceItems: [LocalAudioRecord] = []
    private var displayItems: [LocalAudioRecord] = []
    private var durationTexts: [String: String] = [:]
    private var latestDeviceFiles: [AIRECBleFile] = []
    private var currentFilter: AudioFilter = .local
    private var hasManuallySelectedFilter = false
    private var isRecording = false
    private var isRecordPaused = false
    private var recordingTimer = RecordingTimerModel()
    private var appInitiatedPauseResume = false

    private let audioExts: Set<String> = ["wav", "mp3", "aac", "m4a", "ogg", "opus", "flac", "pcm", "amr"]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "首页";
        setupView()
        AIRECBleChannel.shared.addObserver(self)
//        NotificationCenter.default.addObserver(self,
//                                               selector: #selector(handleDeviceFormatDidFinish),
//                                               name: .airecDeviceFormatDidFinish,
//                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
        AIRECBleChannel.shared.activate()
        if AIRECBleChannel.shared.isConnected {
            print("viewWillAppear");
            AIRECBleChannel.shared.fetchDeviceInfo()
            AIRECBleChannel.shared.fetchFileList()
        }
    }

    deinit {
        AIRECBleChannel.shared.removeObserver(self)
//        NotificationCenter.default.removeObserver(self, name: .airecDeviceFormatDidFinish, object: nil)
    }

    private func setupView() {
        setupNavigationBar()
        view.backgroundColor = Theme.pageBackground
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(HomeBluetoothDeviceInfoCell.self, forCellReuseIdentifier: HomeBluetoothDeviceInfoCell.reuseId)
        tableView.register(HomeRecordingStatusCell.self, forCellReuseIdentifier: HomeRecordingStatusCell.reuseId)
        tableView.register(HomeRecordingFileCell.self, forCellReuseIdentifier: HomeRecordingFileCell.reuseId)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.right.bottom.equalToSuperview()
        }

        reloadLocalFiles()
    }

    private func setupNavigationBar() {
        guard let navigationBar = navigationController?.navigationBar else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.navigationBarBackground
        appearance.shadowColor = Theme.pageControlBorder
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.pageTitleText,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
        navigationBar.tintColor = Theme.pageTitleText
        navigationBar.isTranslucent = false
    }

    private func reloadBluetoothInfoRow(animated: Bool = false) {
        let animation: UITableView.RowAnimation = animated ? .fade : .none
        tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: animation)
    }

    private func fetchConnectedDeviceSnapshot() {
        let channel = AIRECBleChannel.shared
        guard channel.isConnected else { return }
        channel.fetchDeviceInfo()
        channel.fetchFileList()
    }

    private func reloadRecordingStatusRow(animated: Bool = true) {
        let animation: UITableView.RowAnimation = animated ? .fade : .none
        tableView.reloadSections(IndexSet(integer: 0), with: animation)
    }

    private func resetRecordingDuration() {
        recordingTimer.elapsedText = "00:00:00"
    }

    private func updateRecordingDuration(_ durationSec: Int64) {
        recordingTimer.elapsedText = formatRecordingDuration(durationSec)
        reloadRecordingStatusCellIfVisible()
    }

    private func formatRecordingDuration(_ durationSec: Int64) -> String {
        String(format: "%02d:%02d:%02d", durationSec / 3600, (durationSec % 3600) / 60, durationSec % 60)
    }

    private func reloadRecordingStatusCellIfVisible() {
        let recordingStatusIndexPath = IndexPath(row: 1, section: 0)
        if tableView.indexPathsForVisibleRows?.contains(recordingStatusIndexPath) == true {
            tableView.reloadRows(at: [recordingStatusIndexPath], with: .none)
        }
    }

    private func syncRecordingState(recording: Bool, paused: Bool, resetTimerWhenStarting: Bool) {
        let wasRecording = isRecording
        isRecording = recording
        isRecordPaused = paused

        if recording {
            if !wasRecording {
                if resetTimerWhenStarting {
                    resetRecordingDuration()
                }
            }
        } else {
            resetRecordingDuration()
        }

        if wasRecording != recording {
            reloadRecordingStatusRow()
        } else {
            reloadRecordingStatusCellIfVisible()
        }
    }

    @objc private func connectButtonTapped() {
        let scanVC = ScanPeripheralViewController()
        navigationController?.pushViewController(scanVC, animated: true)
    }

    @objc private func refreshFileListTapped() {
        reloadLocalFiles()
        if AIRECBleChannel.shared.isConnected {
            AIRECBleChannel.shared.fetchFileList()
        } else {
            showToast("请先连接设备")
        }
    }

    @objc private func handleDeviceFormatDidFinish() {
        latestDeviceFiles.removeAll()
        deviceItems.removeAll()
        fileStates.removeAll()
        durationTexts.removeAll()
        if !hasManuallySelectedFilter {
            currentFilter = .local
        }
        queryCurrentDisplayFileData()
        reloadFileList()
    }

    private func reloadLocalFiles() {
        localItems = loadLocalAudioRecords()
        queryCurrentDisplayFileData()
        reloadFileList()
    }

    private func loadLocalAudioRecords() -> [LocalAudioRecord] {
        LocalAudioRecordManager.shared.fetchAll().map { record in
            LocalAudioRecord(
                id: record.id,
                fileName: record.fileName,
                displayName: record.displayName,
                fileSize: record.fileSize,
                createTime: record.createTime,
                localPath: record.resolvedLocalPath,
                isDevice: false,
                updatedAt: record.updatedAt
            )
        }.sorted { left, right in
            left.createTime == right.createTime ? left.fileName > right.fileName : left.createTime > right.createTime
        }
    }

    private func persistDownloadedFile(fileName: String, localPath: String) -> String? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: localPath) else { return nil }

        guard let baseURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }

        let directoryURL = baseURL.appendingPathComponent("AIRECAudioFiles", isDirectory: true)
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let sourceURL = URL(fileURLWithPath: localPath)
        let safeFileName = URL(fileURLWithPath: fileName).lastPathComponent
        var destinationURL = directoryURL.appendingPathComponent(safeFileName)
        if destinationURL.pathExtension.isEmpty, !sourceURL.pathExtension.isEmpty {
            destinationURL.appendPathExtension(sourceURL.pathExtension)
        }

        if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return relativeDocumentsPath(for: destinationURL)
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return relativeDocumentsPath(for: destinationURL)
        } catch {
            return nil
        }
    }

    private func relativeDocumentsPath(for fileURL: URL) -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.standardizedFileURL
        let standardizedFileURL = fileURL.standardizedFileURL

        guard standardizedFileURL.path.hasPrefix(documentsURL.path) else {
            return standardizedFileURL.path
        }

        let relativePath = standardizedFileURL.path.dropFirst(documentsURL.path.count)
        return relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func reloadDeviceFiles(_ files: [AIRECBleFile]) {
        var seen: Set<String> = []
        let filteredFiles = files.filter { file in
            let fileName = file.fileName.lowercased()
            guard let dotIndex = fileName.lastIndex(of: ".") else { return true }
            let ext = String(fileName[fileName.index(after: dotIndex)...])
            return audioExts.contains(ext)
        }.filter { file in
            let id = LocalAudioRecord.makeID(fileName: file.fileName, createTime: file.createTime)
            guard !seen.contains(id) else { return false }
            seen.insert(id)
            return true
        }
        latestDeviceFiles = filteredFiles

        durationTexts = filteredFiles.reduce(into: durationTexts) { result, file in
            let id = LocalAudioRecord.makeID(fileName: file.fileName, createTime: file.createTime)
            result[id] = file.durationStr
        }

        deviceItems = filteredFiles.map { file in
            LocalAudioRecord(
                fileName: file.fileName,
                fileSize: file.fileSize,
                createTime: file.createTime,
                localPath: "",
                isDevice: true
            )
        }.sorted { left, right in
            if left.createTime == right.createTime { return left.fileName > right.fileName }
            if left.createTime.isEmpty { return false }
            if right.createTime.isEmpty { return true }
            return left.createTime > right.createTime
        }
        if !hasManuallySelectedFilter {
            currentFilter = .device
        }
        queryCurrentDisplayFileData()
        reloadFileList()
    }

    private func queryCurrentDisplayFileData() {
        switch currentFilter {
        case .all:
            displayItems = []
        case .device:
            displayItems = deviceItems
        case .local:
            displayItems = localItems
        }
    }

    private func reloadFileList() {
        tableView.reloadData()
    }

    private func reloadCell(id: String) {
        guard let index = displayItems.firstIndex(where: { $0.id == id }) else {
            tableView.reloadData()
            return
        }
        tableView.reloadRows(at: [IndexPath(row: index, section: 1)], with: .none)
    }

    private func record(for cell: UITableViewCell) -> LocalAudioRecord? {
        guard let indexPath = tableView.indexPath(for: cell),
              indexPath.section == 1,
              displayItems.indices.contains(indexPath.row) else {
            return nil
        }
        return displayItems[indexPath.row]
    }

    private func audioItem(from record: LocalAudioRecord) -> AudioItem {
        var item = record.audioItem
        item.localPath = record.localPath.isEmpty ? nil : record.resolvedLocalPath
        item.isDevice = record.isDevice
        return item
    }

    private func recordByUpdatingDisplayName(_ record: LocalAudioRecord, displayName: String) -> LocalAudioRecord {
        LocalAudioRecord(
            id: record.id,
            fileName: record.fileName,
            displayName: displayName,
            fileSize: record.fileSize,
            createTime: record.createTime,
            localPath: record.localPath,
            isDevice: record.isDevice,
            updatedAt: Int64(Date().timeIntervalSince1970)
        )
    }

    private func updateDisplayName(for record: LocalAudioRecord, displayName: String) {
        let updatedRecord = recordByUpdatingDisplayName(record, displayName: displayName)

        if let index = localItems.firstIndex(where: { $0.id == record.id }) {
            localItems[index] = updatedRecord
            LocalAudioRecordManager.shared.updateDisplayName(id: record.id, displayName: displayName)
        }

        if let index = deviceItems.firstIndex(where: { $0.id == record.id }) {
            deviceItems[index] = updatedRecord
        }

        queryCurrentDisplayFileData()
        reloadCell(id: record.id)
        showToast("修改成功")
    }

    private func presentRenameAlert(for record: LocalAudioRecord) {
        let alert = UIAlertController(title: "修改文件名称", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = record.displayName
            textField.clearButtonMode = .whileEditing
            textField.returnKeyType = .done
            textField.placeholder = "文件名称"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default) { [weak self, weak alert] _ in
            guard let self = self else { return }
            let displayName = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !displayName.isEmpty else {
                self.showToast("文件名称不能为空")
                return
            }
            self.updateDisplayName(for: record, displayName: displayName)
        })
        present(alert, animated: true)
    }

    private func makeRecordingFilesHeaderView() -> UIView {
        let headerView = UIView()
        headerView.backgroundColor = Theme.pageBackground

        let titleLabel = UILabel()
        titleLabel.text = currentFilter.title
        titleLabel.textColor = Theme.pageTitleText
        titleLabel.font = .boldSystemFont(ofSize: 22)
        headerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }

        let refreshButton = makeHeaderIconButton(systemName: "arrow.clockwise")
        refreshButton.addTarget(self, action: #selector(refreshFileListTapped), for: .touchUpInside)
        headerView.addSubview(refreshButton)
        refreshButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.right.equalToSuperview().offset(-16)
            make.width.height.equalTo(48)
        }

        let searchButton = makeHeaderIconButton(systemName: "line.3.horizontal.decrease.circle")
        searchButton.addTarget(self, action: #selector(filterFileListTapped(_:)), for: .touchUpInside)
        headerView.addSubview(searchButton)
        searchButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.right.equalTo(refreshButton.snp.left).offset(-12)
            make.width.height.equalTo(48)
        }

        return headerView
    }

    @objc private func filterFileListTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "筛选录音文件", message: nil, preferredStyle: .actionSheet)
        addFilterAction(.device, title: "录音卡文件", to: alert)
        addFilterAction(.local, title: "手机文件", to: alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = sender
        alert.popoverPresentationController?.sourceRect = sender.bounds
        present(alert, animated: true)
    }

    private func addFilterAction(_ filter: AudioFilter, title: String, to alert: UIAlertController) {
        let isSelected = currentFilter == filter
        let actionTitle = isSelected ? "\(title) ✓" : title
        alert.addAction(UIAlertAction(title: actionTitle, style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.currentFilter = filter
            self.hasManuallySelectedFilter = true
            self.queryCurrentDisplayFileData()
            self.reloadFileList()
        })
    }

    private func makeHeaderIconButton(systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = Theme.pageTitleText
        button.backgroundColor = Theme.pageControlBackground
        button.layer.cornerRadius = 24
        button.layer.borderColor = Theme.pageControlBorder.cgColor
        button.layer.borderWidth = 1
        return button
    }

    private func makeEmptyFooterView() -> UIView {
        let footerView = UIView()
        footerView.backgroundColor = Theme.pageBackground

        let emptyLabel = UILabel()
        emptyLabel.text = currentFilter == .device ? "暂无录音卡文件" : "暂无手机文件"
        emptyLabel.textColor = Theme.pageSecondaryText
        emptyLabel.font = .systemFont(ofSize: 15, weight: .medium)
        emptyLabel.textAlignment = .center
        footerView.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(40)
        }

        return footerView
    }
}

extension HomeViewViewController: AIRECBleDelegate {

    // MARK: - Connection State

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        fetchConnectedDeviceSnapshot()
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        let wasShowingRecordingStatus = isRecording
        latestDeviceFiles.removeAll()
        deviceItems.removeAll()
        syncRecordingState(recording: false, paused: false, resetTimerWhenStarting: true)
        if !hasManuallySelectedFilter {
            currentFilter = .local
        }
        if !wasShowingRecordingStatus {
            reloadBluetoothInfoRow()
        }
        reloadLocalFiles()
    }

    // MARK: - Device Info

    func bleManager(_ manager: AIRECBleManager, didUpdateDeviceInfo device: AIRECBleDevice) {
        reloadBluetoothInfoRow()
    }

    func bleManager(_ manager: AIRECBleManager, didReceiveFirmwareVersion version: String) {
        reloadBluetoothInfoRow()
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        if !enabled {
            let wasShowingRecordingStatus = isRecording
            latestDeviceFiles.removeAll()
            deviceItems.removeAll()
            syncRecordingState(recording: false, paused: false, resetTimerWhenStarting: true)
            if !hasManuallySelectedFilter {
                currentFilter = .local
            }
            if !wasShowingRecordingStatus {
                reloadBluetoothInfoRow()
            }
            reloadLocalFiles()
        }
    }

    // MARK: - Recording

    func bleManager(_ manager: AIRECBleManager, didChangeRecordState recording: Bool, fileName: String) {
        syncRecordingState(recording: recording, paused: false, resetTimerWhenStarting: true)
        showToast(recording ? "录音中" : "录音已保存")
        if !recording {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard AIRECBleChannel.shared.isConnected else { return }
                AIRECBleChannel.shared.fetchDeviceInfo()
                AIRECBleChannel.shared.fetchFileList()
            }
        }
    }

    func bleManagerDidPauseRecord(_ manager: AIRECBleManager) {
        guard isRecording else { return }
        if appInitiatedPauseResume {
            appInitiatedPauseResume = false
            return
        }
        syncRecordingState(recording: true, paused: !isRecordPaused, resetTimerWhenStarting: false)
    }

    func bleManager(_ manager: AIRECBleManager, didQueryRecordStatus recording: Bool, paused: Bool, fileName: String) {
        syncRecordingState(recording: recording, paused: paused, resetTimerWhenStarting: true)
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateRecordDuration durationSec: Int64) {
        updateRecordingDuration(durationSec)
        if !isRecording {
            syncRecordingState(recording: true, paused: false, resetTimerWhenStarting: false)
        }
    }

    // MARK: - Files

    func bleManager(_ manager: AIRECBleManager, didUpdateFileList files: [AIRECBleFile]) {
        reloadDeviceFiles(files)
    }

    func bleManager(_ manager: AIRECBleManager, didDeleteFile fileName: String, success: Bool) {
        showToast(success ? "删除成功" : "删除失败")
        if success {
            AIRECBleChannel.shared.fetchFileList()
        }
    }

    func bleManager(_ manager: AIRECBleManager, downloadProgress file: AIRECBleFile, progress: Int) {
        let id = LocalAudioRecord.makeID(fileName: file.fileName, createTime: file.createTime)
        fileStates[id] = .downloading(progress)
        reloadCell(id: id)
    }

    func bleManager(_ manager: AIRECBleManager, downloadComplete file: AIRECBleFile, localPath: String) {
        let id = LocalAudioRecord.makeID(fileName: file.fileName, createTime: file.createTime)
        fileStates[id] = nil
        durationTexts[id] = file.durationStr
        guard let stablePath = persistDownloadedFile(fileName: file.fileName, localPath: localPath) else {
            fileStates[id] = .error
            reloadCell(id: id)
            showToast("保存文件失败，请重新下载")
            return
        }
        LocalAudioRecordManager.shared.save(LocalAudioRecord(
            fileName: file.fileName,
            fileSize: file.fileSize,
            createTime: file.createTime,
            localPath: stablePath,
            isDevice: false
        ))

        let savedRecord = LocalAudioRecord(
            fileName: file.fileName,
            fileSize: file.fileSize,
            createTime: file.createTime,
            localPath: stablePath,
            isDevice: false
        )
        if let index = localItems.firstIndex(where: { $0.id == id }) {
            localItems[index] = savedRecord
        } else {
            localItems.append(savedRecord)
        }
        localItems = localItems.sorted { left, right in
            left.createTime == right.createTime ? left.fileName > right.fileName : left.createTime > right.createTime
        }
        queryCurrentDisplayFileData()
        reloadFileList()
        showToast("下载完成：\(file.fileName)")
    }

    func bleManager(_ manager: AIRECBleManager, downloadFailed file: AIRECBleFile, reason: String) {
        print("AIREC_iOS: download failed file=\(file.fileName), reason=\(reason)")
        let id = LocalAudioRecord.makeID(fileName: file.fileName, createTime: file.createTime)
        fileStates[id] = .error
        let downloadingIds = fileStates.compactMap { id, state -> String? in
            if case .downloading = state { return id }
            return nil
        }
        downloadingIds.forEach { id in
            fileStates[id] = .idle
        }
        reloadFileList()
        showToast("下载失败：\(reason)")
    }
}

extension HomeViewViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? (isRecording ? 2 : 1) : displayItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: HomeBluetoothDeviceInfoCell.reuseId, for: indexPath) as! HomeBluetoothDeviceInfoCell
                let device = AIRECBleChannel.shared.isConnected ? AIRECBleChannel.shared.getConnectedDevice() : nil
                cell.configure(device: device)
                cell.delegate = self
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: HomeRecordingStatusCell.reuseId, for: indexPath) as! HomeRecordingStatusCell
                cell.configure(elapsedText: recordingTimer.elapsedText, isPaused: isRecordPaused)
                cell.delegate = self
                return cell
            }
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: HomeRecordingFileCell.reuseId, for: indexPath) as! HomeRecordingFileCell
        let record = displayItems[indexPath.row]
        let item = audioItem(from: record)
        let state: HomeRecordingFileCell.State = currentFilter == .local ? .done : (fileStates[record.id] ?? .idle)
        cell.configure(item: item, displayName: record.displayName, durationText: durationTexts[record.id] ?? durationTexts[item.id], state: state)
        cell.delegate = self
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return indexPath.row == 0 ? 214 : 220
        }
        return 130
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        section == 1 ? makeRecordingFilesHeaderView() : nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? 70 : CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        section == 1 && displayItems.isEmpty ? makeEmptyFooterView() : nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == 1 && displayItems.isEmpty ? 120 : CGFloat.leastNormalMagnitude
    }
}

extension HomeViewViewController: HomeBluetoothDeviceInfoCellDelegate {

    func homeBluetoothDeviceInfoCellDidTapConnect(_ cell: HomeBluetoothDeviceInfoCell) {
        connectButtonTapped()
    }
}

extension HomeViewViewController: HomeRecordingStatusCellDelegate {

    func homeRecordingStatusCellDidTapPause(_ cell: HomeRecordingStatusCell) {
        guard AIRECBleChannel.shared.isConnected else {
            showToast("请先连接设备")
            return
        }

        if isRecordPaused {
            appInitiatedPauseResume = true
            AIRECBleChannel.shared.resumeRecord()
            syncRecordingState(recording: true, paused: false, resetTimerWhenStarting: false)
        } else {
            appInitiatedPauseResume = true
            AIRECBleChannel.shared.pauseRecord()
            syncRecordingState(recording: true, paused: true, resetTimerWhenStarting: false)
        }
    }

    func homeRecordingStatusCellDidTapStop(_ cell: HomeRecordingStatusCell) {
        guard AIRECBleChannel.shared.isConnected else {
            showToast("请先连接设备")
            return
        }

        AIRECBleChannel.shared.endRecord()
    }

}

extension HomeViewViewController: HomeRecordingFileCellDelegate {

    func homeRecordingFileCellDidTapDownload(_ cell: HomeRecordingFileCell) {
        guard let record = record(for: cell) else { return }
        guard AIRECBleChannel.shared.isConnected else {
            showToast("请先连接设备")
            return
        }

        fileStates[record.id] = .downloading(0)
        reloadCell(id: record.id)

        guard let bleFile = deviceFile(for: record) else {
            fileStates[record.id] = .idle
            reloadCell(id: record.id)
            showToast("请先刷新文件列表")
            return
        }
        print("AIREC_iOS: start download file=\(bleFile.fileName), size=\(bleFile.fileSize)")
        AIRECBleChannel.shared.downloadFile(bleFile)
    }

    private func deviceFile(for record: LocalAudioRecord) -> AIRECBleFile? {
        let normalizedName = record.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let files = latestDeviceFiles + (AIRECBleChannel.shared.getConnectedDevice()?.fileList ?? [])
        return files.first { file in
            file.fileName == record.fileName
        } ?? files.first { file in
            file.fileName.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(normalizedName) == .orderedSame
        }
    }

    func homeRecordingFileCellDidTapPlay(_ cell: HomeRecordingFileCell) {
        guard let record = record(for: cell) else { return }
        let item = audioItem(from: record)
        var basePath = item.localPath ?? LocalAudioRecordManager.shared.localPath(for: record.fileName) ?? AIRECBleChannel.shared.getLocalPath(record.fileName)

        if let path = basePath, !FileManager.default.fileExists(atPath: path) {
            for ext in [".caf", ".opus", ".mp3", ".wav", ".aac", ".m4a"] {
                let candidate = path + ext
                if FileManager.default.fileExists(atPath: candidate) {
                    basePath = candidate
                    break
                }
            }
        }

        guard let localPath = basePath, FileManager.default.fileExists(atPath: localPath) else {
            showToast("文件不存在，请重新下载")
            return
        }

        let player = AudioPlayViewController(filePath: localPath, fileName: record.displayName, fileDate: record.createTime, fileSize: item.fileSizeStr)
        player.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(player, animated: true)
    }

    func homeRecordingFileCellDidTapMore(_ cell: HomeRecordingFileCell) {
        guard let record = record(for: cell) else { return }
        let alert = UIAlertController(title: record.displayName, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "修改名称", style: .default) { [weak self] _ in
            self?.presentRenameAlert(for: record)
        })
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            if self.currentFilter == .device, record.isDevice {
                AIRECBleChannel.shared.deleteFile(record.fileName)
            }

            if self.currentFilter == .local, record.fileExists {
                LocalAudioRecordManager.shared.delete(fileName: record.id, removeFile: true)
            }

            if self.currentFilter == .device {
                self.deviceItems.removeAll { $0.id == record.id }
                self.latestDeviceFiles.removeAll { $0.fileName == record.fileName }
                self.fileStates[record.id] = nil
            } else if self.currentFilter == .local {
                self.localItems.removeAll { $0.id == record.id }
            }
            self.queryCurrentDisplayFileData()
            self.reloadFileList()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = cell
        alert.popoverPresentationController?.sourceRect = cell.bounds
        present(alert, animated: true)
    }
}
