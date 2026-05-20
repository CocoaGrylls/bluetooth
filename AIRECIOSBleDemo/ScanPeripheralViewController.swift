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

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        // 使用系统导航栏标题
        title = "连接设备"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.circle"),
            style: .plain,
            target: self,
            action: #selector(helpAction)
        )

        // 配置 radarContainer 作为 tableHeaderView
        radarContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 220)
        tableView.tableHeaderView = radarContainer
        radarContainer.stopButton.addTarget(self, action: #selector(stopScan), for: .touchUpInside)

        // 配置 tableView
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DeviceCell.self, forCellReuseIdentifier: DeviceCell.reuseId)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.bottom.equalToSuperview()
        }

        // 刷新icon（可选，放在header里更合适）
        // view.addSubview(refreshIcon)
        // refreshIcon.snp.makeConstraints { make in
        //     make.top.equalTo(tableView.snp.top).offset(8)
        //     make.right.equalToSuperview().offset(-16)
        // }

        AIRECBleManager.shared.delegate = self
        AIRECBleManager.shared.startScan()
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        devices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DeviceCell.reuseId, for: indexPath) as! DeviceCell
        cell.configure(device: devices[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        let device = devices[indexPath.row]
        AIRECBleManager.shared.stopScan()
        AIRECBleManager.shared.connect(device)
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "附近设备"
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

