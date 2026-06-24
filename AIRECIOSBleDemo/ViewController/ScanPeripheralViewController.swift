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

    let refreshIcon = UIActivityIndicatorView(style: .medium)
    let helpButton = UIButton(type: .system)

    private var devices: [AIRECBleDevice] = []
    private var seenIds = Set<String>()
    private var connectedDevice: AIRECBleDevice? {
        AIRECBleChannel.shared.getConnectedDevice()
    }
    private var connectingHud: UIAlertController?
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        AIRECBleChannel.shared.stopScan()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemGroupedBackground

        // 使用系统导航栏标题
        setupNav()

        // 创建页面元素
        setupView()

        AIRECBleChannel.shared.addObserver(self)
        AIRECBleChannel.shared.startScan()
        
        radarContainer.startScanningAnimation()
    }

    deinit {
        AIRECBleChannel.shared.removeObserver(self)
    }
    
    
    //设置导航栏
    func setupNav() {
        title = "连接设备"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "questionmark.circle"),
            style: .plain,
            target: self,
            action: #selector(helpAction)
        )
    }

    //创建页面元素
    func setupView() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.left.right.bottom.equalToSuperview()
        }
    }


    @objc func cancelTapped() {
        AIRECBleChannel.shared.stopScan()
        self.navigationController?.popViewController(animated: true)
    }
    @objc func helpAction() {
        // 实现帮助按钮逻辑
    }

   

    private func stopScan() {
        radarContainer.markScanStopped()
        AIRECBleChannel.shared.stopScan()
    }
    
    private func showConnectingLoading() {
        let hud = UIAlertController(title: nil, message: "正在连接...\n\n", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        hud.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: hud.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: hud.view.bottomAnchor, constant: -20)
        ])
        connectingHud = hud
        present(hud, animated: true)
    }
    
    private func hideConnectingLoading() {
        if let hud = connectingHud {
            hud.dismiss(animated: true)
            connectingHud = nil
        }
    }
    
    // MARK: - UI Elements 懒加载
    private lazy var radarContainer: ScanContainerView = {
        let radarContainer = ScanContainerView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 220))
        radarContainer.onStopTapped = { [weak self] in
            self?.stopScan()
        }
        return radarContainer
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: UIScreen.main.bounds, style: .insetGrouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ScanBlueToothDeviceInfoCell.self, forCellReuseIdentifier: ScanBlueToothDeviceInfoCell.reuseId)
        tableView.register(ScanEmptyAIRECDeviceCell.self, forCellReuseIdentifier: ScanEmptyAIRECDeviceCell.reuseId)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.tableHeaderView = radarContainer
        return tableView
    }()
    
}

extension ScanPeripheralViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return connectedDevice != nil ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 && connectedDevice != nil {
            return 80
        }
        let targetDevices = devices
        return targetDevices.isEmpty ? 100 : 80
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && connectedDevice != nil {
            return 1
        }
        let targetSection = connectedDevice != nil ? section - 1 : section
        if targetSection == 0 {
            return devices.isEmpty ? 1 : devices.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && connectedDevice != nil {
            guard let device = connectedDevice else {
                return UITableViewCell()
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: ScanBlueToothDeviceInfoCell.reuseId, for: indexPath) as! ScanBlueToothDeviceInfoCell
            cell.configure(device: device)
            cell.connectButton.setTitle("已连接", for: .normal)
            cell.connectButton.setTitleColor(.systemGreen, for: .normal)
            cell.connectButton.layer.borderColor = UIColor.systemGreen.cgColor
            cell.connectButton.isEnabled = false
            return cell
        }
        
        let targetSection = connectedDevice != nil ? indexPath.section - 1 : indexPath.section
        if targetSection == 0 && devices.isEmpty {
            return tableView.dequeueReusableCell(withIdentifier: ScanEmptyAIRECDeviceCell.reuseId, for: indexPath)
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: ScanBlueToothDeviceInfoCell.reuseId, for: indexPath) as! ScanBlueToothDeviceInfoCell
        let device = devices[indexPath.row]
        cell.configure(device: device)
        cell.connectButton.setTitle("连接", for: .normal)
        cell.connectButton.setTitleColor(.systemBlue, for: .normal)
        cell.connectButton.layer.borderColor = UIColor.systemBlue.cgColor
        cell.connectButton.isEnabled = true
        cell.connectButtonTapped = { [weak self] in
            guard let self = self else { return }
            let device = self.devices[indexPath.row]
            self.showConnectingLoading()
            AIRECBleChannel.shared.connect(device)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 && connectedDevice != nil {
            return
        }
        
        let targetSection = connectedDevice != nil ? indexPath.section - 1 : indexPath.section
        if targetSection == 0 && devices.isEmpty {
            return
        }

        let device = devices[indexPath.row]
        showConnectingLoading()
        AIRECBleChannel.shared.connect(device)
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 && connectedDevice != nil {
            return "已连接设备"
        }
        let targetSection = connectedDevice != nil ? section - 1 : section
        if targetSection == 0 {
            return "附近设备（\(devices.count)）"
        }
        return nil
    }
}

// MARK: - AIRECBleDelegate（只实现扫描/连接相关回调）
extension ScanPeripheralViewController: AIRECBleDelegate {

    func bleManager(_ manager: AIRECBleManager, didDiscover device: AIRECBleDevice) {
        guard !seenIds.contains(device.identifier) else { return }
        if let connected = connectedDevice, connected.identifier == device.identifier {
            return
        }
        seenIds.insert(device.identifier)
        devices.append(device)
        tableView.reloadData()
    }

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        hideConnectingLoading()
        AIRECBleChannel.shared.stopScan()
        devices.removeAll { item in
            return item.identifier == device.identifier
        }
        tableView.reloadData()
    }
    

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        hideConnectingLoading()
        radarContainer.stopScanningAnimation()
        tableView.reloadData()
        let msg = reason.contains("超时") ? "连接超时，请靠近设备重试" : "连接失败，请重试"
        showAlert(title: "连接失败", message: msg)
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        if !enabled {
            radarContainer.stopScanningAnimation()
            // statusLabel.text = "蓝牙已关闭，请开启蓝牙"
        }
    }
}
