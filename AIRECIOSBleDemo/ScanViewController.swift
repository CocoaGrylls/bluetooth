import UIKit
import AIRECBleKit

class ScanViewController: UIViewController {

    var onConnected: (() -> Void)?

    private var devices: [AIRECBleDevice] = []
    private var seenIds = Set<String>()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let scanPeripheralView = ScanRadarView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "扫描设备"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "重新扫描", style: .plain, target: self, action: #selector(rescan))

        statusLabel.text = "扫描中..."
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textColor = .secondaryLabel
        spinner.startAnimating()

        tableView.register(BlueToothDeviceInfoCell.self, forCellReuseIdentifier: BlueToothDeviceInfoCell.reuseId)
        tableView.dataSource = self
        tableView.delegate   = self

        // header 用 frame-based 布局，避免 tableHeaderView 初始宽度为 0 时的约束冲突
        let header = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 52))
        spinner.frame = CGRect(x: 16, y: 14, width: 24, height: 24)
        statusLabel.frame = CGRect(x: 48, y: 0, width: header.bounds.width - 64, height: 52)
        header.addSubview(spinner)
        header.addSubview(statusLabel)
        tableView.tableHeaderView = header
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 添加 ScanPeripheralView
        scanPeripheralView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanPeripheralView)
        NSLayoutConstraint.activate([
            scanPeripheralView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            scanPeripheralView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanPeripheralView.widthAnchor.constraint(equalToConstant: 180),
            scanPeripheralView.heightAnchor.constraint(equalToConstant: 180)
        ])
        scanPeripheralView.startAnimation()

        AIRECBleManager.shared.delegate = self
        AIRECBleManager.shared.startScan()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AIRECBleManager.shared.stopScan()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 更新 header 宽度适配屏幕
        if let header = tableView.tableHeaderView {
            let w = tableView.bounds.width
            header.frame = CGRect(x: 0, y: 0, width: w, height: 52)
            statusLabel.frame = CGRect(x: 48, y: 0, width: w - 64, height: 52)
            tableView.tableHeaderView = header
        }
    }

    @objc private func cancelTapped() {
        AIRECBleManager.shared.stopScan()
        scanPeripheralView.stopAnimation()
        dismiss(animated: true)
    }

    @objc private func rescan() {
        devices.removeAll(); seenIds.removeAll()
        tableView.reloadData()
        statusLabel.text = "扫描中..."
        spinner.startAnimating()
        scanPeripheralView.startAnimation()
        AIRECBleManager.shared.startScan()
    }
}

extension ScanViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { devices.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: BlueToothDeviceInfoCell.reuseId, for: indexPath) as! BlueToothDeviceInfoCell
        cell.configure(device: devices[indexPath.row])
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let device = devices[indexPath.row]
        statusLabel.text = "连接中：\(device.name)..."
        spinner.startAnimating()
        AIRECBleManager.shared.stopScan()
        AIRECBleManager.shared.connect(device)
    }
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        devices.isEmpty ? nil : "发现 \(devices.count) 台设备，点击连接"
    }
}

// MARK: - AIRECBleDelegate（只实现扫描/连接相关回调）
extension ScanViewController: AIRECBleDelegate {

    func bleManager(_ manager: AIRECBleManager, didDiscover device: AIRECBleDevice) {
        guard !seenIds.contains(device.identifier) else { return }
        seenIds.insert(device.identifier)
        devices.append(device)
        tableView.reloadData()
        statusLabel.text = "发现 \(devices.count) 台设备，点击连接"
    }

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        spinner.stopAnimating()
        scanPeripheralView.stopAnimation()
        // 先切换 delegate 到 MainViewController
        onConnected?()
        // 手动把 didConnect 转发给新 delegate（MainViewController）
        // 因为 SDK 只触发一次，切换 delegate 后需要手动补发
        DispatchQueue.main.async {
            print("AIREC_iOS: ScanVC forwarding didConnect, delegate=\(AIRECBleManager.shared.delegate != nil ? String(describing: type(of: AIRECBleManager.shared.delegate!)) : "nil")")
            AIRECBleManager.shared.delegate?.bleManager(manager, didConnect: device)
            print("AIREC_iOS: ScanVC dismissing")
            self.dismiss(animated: true)
        }
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        spinner.stopAnimating()
        scanPeripheralView.stopAnimation()
        let msg = reason.contains("超时") ? "连接超时，请靠近设备重试" : "连接失败，请重试"
        statusLabel.text = msg
        showAlert(title: "连接失败", message: msg)
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        if !enabled {
            spinner.stopAnimating()
            scanPeripheralView.stopAnimation()
            statusLabel.text = "蓝牙已关闭，请开启蓝牙"
        }
    }
}
