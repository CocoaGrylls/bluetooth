//
//  ScanPeripheralViewController.swift
//  AIRECIOSBleDemo
//
//  Created by 李龙飞 on 2026/5/19.
//

import UIKit
import AIRECBleKit
import SnapKit

class ScanPeripheralViewController: UIViewController {
    
    var onConnected: (() -> Void)?

    let radarContainer = ScanContainerView()
    let refreshIcon = UIActivityIndicatorView(style: .medium)
    let helpButton = UIButton(type: .system)

    private var devices: [AIRECBleDevice] = []
    private var seenIds = Set<String>()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)


    //设置导航栏
    func setupNav() {
        title = "连接设备"
        // 设置导航栏左侧关闭按钮,图标使用close自定义图标
        let closeButton = UIButton(type: .custom)
        closeButton.setImage(UIImage(named: "close_icon"), for: .normal)
        closeButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)   
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: closeButton)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.circle"),
            style: .plain,
            target: self,
            action: #selector(helpAction)
        )
    }

    //创建页面元素
    func setupView() {
        // 配置 radarContainer 作为 tableHeaderView
        radarContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 220)
        tableView.tableHeaderView = radarContainer
        radarContainer.stopButton.addTarget(self, action: #selector(stopScan), for: .touchUpInside)

        // 配置 tableView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(BlueToothDeviceInfoCell.self, forCellReuseIdentifier: BlueToothDeviceInfoCell.reuseId)
        tableView.register(EmptyAIRECDeviceCell.self, forCellReuseIdentifier: EmptyAIRECDeviceCell.reuseId)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.bottom.equalToSuperview()
        }

    }
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground

        // 使用系统导航栏标题
        setupNav()

        // 创建页面元素
        setupView()

        AIRECBleManager.shared.delegate = self
        AIRECBleManager.shared.startScan()
        
        radarContainer.startScanningAnimation()
    }
    
    @objc func cancelTapped() {
        AIRECBleManager.shared.stopScan()
        dismiss(animated: true)
    }
    @objc func helpAction() {
        // 实现帮助按钮逻辑
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AIRECBleManager.shared.stopScan()
    }

    @objc func stopScan() {
        radarContainer.scanView.stopAnimation()
        radarContainer.stopButton.setTitle("已停止", for: .normal)
        radarContainer.stopButton.isEnabled = false
        // 这里可以加停止扫描的逻辑
    }
}

extension ScanPeripheralViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return devices.isEmpty ? 100 : 80
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return devices.isEmpty ? 1 : devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !devices.isEmpty else {
            return tableView.dequeueReusableCell(withIdentifier: EmptyAIRECDeviceCell.reuseId, for: indexPath)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: BlueToothDeviceInfoCell.reuseId, for: indexPath) as! BlueToothDeviceInfoCell
        cell.configure(device: devices[indexPath.row])
        cell.connectButtonTapped = { [weak self] in
            guard let self = self else { return }
            let device = self.devices[indexPath.row]
            AIRECBleManager.shared.stopScan()
            AIRECBleManager.shared.connect(device)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !devices.isEmpty else { return }

        let device = devices[indexPath.row]
        AIRECBleManager.shared.stopScan()
        AIRECBleManager.shared.connect(device)
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        //显示目前扫描到的设备数量
        return "附近设备（\(devices.count)）"
    }
}

private class EmptyAIRECDeviceCell: UITableViewCell {

    static let reuseId = "EmptyAIRECDeviceCell"

    private let emptyLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        selectionStyle = .none
        emptyLabel.text = "暂无可用AIREC设备"
        emptyLabel.font = .systemFont(ofSize: 16)
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        contentView.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
}

// MARK: - AIRECBleDelegate（只实现扫描/连接相关回调）
extension ScanPeripheralViewController: AIRECBleDelegate {

    func bleManager(_ manager: AIRECBleManager, didDiscover device: AIRECBleDevice) {
        guard !seenIds.contains(device.identifier) else { return }
        seenIds.insert(device.identifier)
        devices.append(device)
        tableView.reloadData()
    }

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        radarContainer.scanView.stopAnimation()
        // 先切换 delegate 到 MainViewController
        // 手动把 didConnect 转发给新 delegate（MainViewController）
        // 因为 SDK 只触发一次，切换 delegate 后需要手动补发
        DispatchQueue.main.async {
            AIRECBleManager.shared.delegate?.bleManager(manager, didConnect: device)
            self.dismiss(animated: true)
        }
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        radarContainer.scanView.stopAnimation()
        let msg = reason.contains("超时") ? "连接超时，请靠近设备重试" : "连接失败，请重试"
        showAlert(title: "连接失败", message: msg)
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        if !enabled {
            radarContainer.scanView.stopAnimation()
            // statusLabel.text = "蓝牙已关闭，请开启蓝牙"
        }
    }
}
