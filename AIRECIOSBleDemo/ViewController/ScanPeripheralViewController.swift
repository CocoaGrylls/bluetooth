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
        tableView.register(BlueToothDeviceInfoCell.self, forCellReuseIdentifier: BlueToothDeviceInfoCell.reuseId)
        tableView.register(EmptyAIRECDeviceCell.self, forCellReuseIdentifier: EmptyAIRECDeviceCell.reuseId)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.tableHeaderView = radarContainer
        return tableView
    }()
    
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
            AIRECBleChannel.shared.stopScan()
            AIRECBleChannel.shared.connect(device)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !devices.isEmpty else { return }

        let device = devices[indexPath.row]
        AIRECBleChannel.shared.stopScan()
        AIRECBleChannel.shared.connect(device)
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        //显示目前扫描到的设备数量
        return "附近设备（\(devices.count)）"
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
        radarContainer.stopScanningAnimation()
        DispatchQueue.main.async {
            self.onConnected?()
            self.navigationController?.popViewController(animated: true)
        }
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        radarContainer.stopScanningAnimation()
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
