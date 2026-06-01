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

    private let audioExts: Set<String> = ["wav", "mp3", "aac", "m4a", "ogg", "opus", "flac", "pcm", "amr"]

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "首页";
        setupView()
        AIRECBleChannel.shared.addObserver(self)
        refreshBluetoothInfoView(shouldFetchDeviceInfo: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupNavigationBar()
        AIRECBleChannel.shared.activate()
        refreshBluetoothInfoView(shouldFetchDeviceInfo: true)
    }

    deinit {
        AIRECBleChannel.shared.removeObserver(self)
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

    private func refreshBluetoothInfoView(shouldFetchDeviceInfo: Bool = false) {
        let channel = AIRECBleChannel.shared
        tableView.reloadSections(IndexSet(integer: 0), with: .none)

        if shouldFetchDeviceInfo, channel.isConnected {
            channel.fetchAllDeviceInfo()
            channel.fetchFileList()
        }
    }

    @objc private func connectButtonTapped() {
        if AIRECBleChannel.shared.isConnected {
            refreshBluetoothInfoView(shouldFetchDeviceInfo: true)
            return
        }

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

    private func reloadLocalFiles() {
        localItems = loadLocalAudioRecords()
        applyFilter()
        reloadFileList()
    }

    private func loadLocalAudioRecords() -> [LocalAudioRecord] {
        LocalAudioRecordManager.shared.fetchAll().map { record in
            LocalAudioRecord(
                id: record.id,
                fileName: record.fileName,
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
            guard !seen.contains(file.fileName) else { return false }
            seen.insert(file.fileName)
            return true
        }
        latestDeviceFiles = filteredFiles

        durationTexts = filteredFiles.reduce(into: durationTexts) { result, file in
            result[file.fileName] = file.durationStr
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
        applyFilter()
        reloadFileList()
    }

    private func applyFilter() {
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
            self.applyFilter()
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

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        refreshBluetoothInfoView(shouldFetchDeviceInfo: true)
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        latestDeviceFiles.removeAll()
        deviceItems.removeAll()
        if !hasManuallySelectedFilter {
            currentFilter = .local
        }
        refreshBluetoothInfoView()
        reloadLocalFiles()
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateDeviceInfo device: AIRECBleDevice) {
        refreshBluetoothInfoView()
    }

    func bleManager(_ manager: AIRECBleManager, didReceiveFirmwareVersion version: String) {
        refreshBluetoothInfoView()
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        if !enabled {
            latestDeviceFiles.removeAll()
            deviceItems.removeAll()
            if !hasManuallySelectedFilter {
                currentFilter = .local
            }
            refreshBluetoothInfoView()
            reloadLocalFiles()
        }
    }

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
        fileStates[file.fileName] = .downloading(progress)
        reloadCell(id: file.fileName)
    }

    func bleManager(_ manager: AIRECBleManager, downloadComplete file: AIRECBleFile, localPath: String) {
        fileStates[file.fileName] = nil
        durationTexts[file.fileName] = file.durationStr
        guard let stablePath = persistDownloadedFile(fileName: file.fileName, localPath: localPath) else {
            fileStates[file.fileName] = .error
            reloadCell(id: file.fileName)
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
        if let index = localItems.firstIndex(where: { $0.id == file.fileName }) {
            localItems[index] = savedRecord
        } else {
            localItems.append(savedRecord)
        }
        localItems = localItems.sorted { left, right in
            left.createTime == right.createTime ? left.fileName > right.fileName : left.createTime > right.createTime
        }
        applyFilter()
        reloadFileList()
        showToast("下载完成：\(file.fileName)")
    }

    func bleManager(_ manager: AIRECBleManager, downloadFailed file: AIRECBleFile, reason: String) {
        print("AIREC_iOS: download failed file=\(file.fileName), reason=\(reason)")
        fileStates[file.fileName] = .error
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
        section == 0 ? 1 : displayItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: HomeBluetoothDeviceInfoCell.reuseId, for: indexPath) as! HomeBluetoothDeviceInfoCell
            let device = AIRECBleChannel.shared.isConnected ? AIRECBleChannel.shared.getConnectedDevice() : nil
            cell.configure(device: device)
            cell.delegate = self
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: HomeRecordingFileCell.reuseId, for: indexPath) as! HomeRecordingFileCell
        let record = displayItems[indexPath.row]
        let item = audioItem(from: record)
        let state: HomeRecordingFileCell.State = currentFilter == .local ? .done : (fileStates[record.id] ?? .idle)
        cell.configure(item: item, durationText: durationTexts[item.id], state: state)
        cell.delegate = self
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 214 : 130
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

        let player = PlayerViewController(filePath: localPath, fileName: item.fileName, fileSize: item.fileSizeStr)
        navigationController?.pushViewController(player, animated: true)
    }

    func homeRecordingFileCellDidTapMore(_ cell: HomeRecordingFileCell) {
        guard let record = record(for: cell) else { return }
        let alert = UIAlertController(title: record.fileName, message: nil, preferredStyle: .actionSheet)
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
            self.applyFilter()
            self.reloadFileList()
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.popoverPresentationController?.sourceView = cell
        alert.popoverPresentationController?.sourceRect = cell.bounds
        present(alert, animated: true)
    }
}
