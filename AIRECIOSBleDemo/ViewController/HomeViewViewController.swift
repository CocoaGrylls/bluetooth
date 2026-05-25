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

    private let connectionTitleLabel = UILabel()
    private let connectionSubtitleLabel = UILabel()
    private let connectButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "首页";
        setupView()
        AIRECBleChannel.shared.addObserver(self)
        refreshBluetoothInfoView(shouldFetchDeviceInfo: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AIRECBleChannel.shared.activate()
        refreshBluetoothInfoView(shouldFetchDeviceInfo: true)
    }

    deinit {
        AIRECBleChannel.shared.removeObserver(self)
    }

    private func setupView() {
        view.backgroundColor = Theme.pageBackground
        setupBluetoothDeviceInfoView()

    }

    private func setupBluetoothDeviceInfoView() {
        let headerView = UIView()
        headerView.backgroundColor = Theme.bluetoothHeaderBackground
        headerView.layer.cornerRadius = 18
        headerView.layer.borderColor = Theme.bluetoothHeaderBorder.cgColor
        headerView.layer.borderWidth = 1
        headerView.clipsToBounds = true
        view.addSubview(headerView)
        
        headerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(194)
        }

        let decorativeIconView = UIImageView(image: UIImage(systemName: "waveform.path.ecg.rectangle"))
        decorativeIconView.tintColor = Theme.bluetoothHeaderDecorative
        decorativeIconView.contentMode = .scaleAspectFit
        headerView.addSubview(decorativeIconView)
        decorativeIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(28)
            make.right.equalToSuperview().offset(-16)
            make.width.equalTo(118)
            make.height.equalTo(86)
        }

        let topContentView = UIView()
        headerView.addSubview(topContentView)
        topContentView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(-58)
        }

        let bluetoothRingView = BluetoothRingView()
        topContentView.addSubview(bluetoothRingView)
        bluetoothRingView.snp.makeConstraints { make in
            make.width.height.equalTo(96)
            make.left.equalToSuperview().offset(24)
            make.centerY.equalToSuperview()
        }

        let textStackView = UIStackView()
        textStackView.axis = .vertical
        textStackView.alignment = .leading
        textStackView.spacing = 10
        topContentView.addSubview(textStackView)
        textStackView.snp.makeConstraints { make in
            make.left.equalTo(bluetoothRingView.snp.right).offset(24)
            make.right.lessThanOrEqualToSuperview().offset(-24)
            make.centerY.equalToSuperview()
        }

        connectionTitleLabel.text = "未连接设备"
        connectionTitleLabel.textColor = Theme.bluetoothHeaderPrimaryText
        connectionTitleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        textStackView.addArrangedSubview(connectionTitleLabel)

        connectionSubtitleLabel.text = "请连接蓝牙录音卡设备"
        connectionSubtitleLabel.textColor = Theme.bluetoothHeaderSecondaryText
        connectionSubtitleLabel.font = UIFont.systemFont(ofSize: 16)
        connectionSubtitleLabel.numberOfLines = 2
        textStackView.addArrangedSubview(connectionSubtitleLabel)

        connectButton.setTitle("连接设备", for: .normal)
        connectButton.setImage(UIImage(systemName: "bluetooth"), for: .normal)
        connectButton.setTitleColor(Theme.bluetoothButtonText, for: .normal)
        connectButton.tintColor = Theme.bluetoothButtonText
        connectButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        connectButton.backgroundColor = Theme.bluetoothButtonBackground
        connectButton.layer.cornerRadius = 22
        connectButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        connectButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        textStackView.setCustomSpacing(18, after: connectionSubtitleLabel)
        textStackView.addArrangedSubview(connectButton)
        connectButton.snp.makeConstraints { make in
            make.width.equalTo(150)
            make.height.equalTo(44)
        }

        let separatorView = UIView()
        separatorView.backgroundColor = Theme.bluetoothHeaderSeparator
        headerView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-58)
            make.height.equalTo(1)
        }

        let availableDeviceButton = UIButton(type: .system)
        availableDeviceButton.tintColor = Theme.bluetoothHeaderIcon
        availableDeviceButton.contentHorizontalAlignment = .fill
        availableDeviceButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        headerView.addSubview(availableDeviceButton)
        availableDeviceButton.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(58)
        }

        let deviceIconView = UIImageView(image: UIImage(systemName: "list.bullet.rectangle"))
        deviceIconView.tintColor = Theme.bluetoothHeaderIcon
        deviceIconView.contentMode = .scaleAspectFit
        availableDeviceButton.addSubview(deviceIconView)
        deviceIconView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(24)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(22)
        }

        let availableDeviceLabel = UILabel()
        availableDeviceLabel.text = "发现设备"
        availableDeviceLabel.textColor = Theme.bluetoothHeaderMutedText
        availableDeviceLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        availableDeviceButton.addSubview(availableDeviceLabel)
        availableDeviceLabel.snp.makeConstraints { make in
            make.left.equalTo(deviceIconView.snp.right).offset(10)
            make.centerY.equalToSuperview()
        }

        let arrowIconView = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrowIconView.tintColor = Theme.bluetoothHeaderIcon
        arrowIconView.contentMode = .scaleAspectFit
        availableDeviceButton.addSubview(arrowIconView)
        arrowIconView.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-24)
            make.centerY.equalToSuperview()
            make.width.equalTo(10)
            make.height.equalTo(18)
        }
    }

    private func refreshBluetoothInfoView(shouldFetchDeviceInfo: Bool = false) {
        let channel = AIRECBleChannel.shared
        
        guard channel.isConnected, let device = channel.getConnectedDevice()
        else {
            connectionTitleLabel.text = "未连接设备"
            connectionSubtitleLabel.text = "请连接蓝牙录音卡设备"
            connectButton.setTitle("连接设备", for: .normal)
            connectButton.setImage(UIImage(systemName: "bluetooth"), for: .normal)
            return
        }

        connectionTitleLabel.text = device.name
        connectionSubtitleLabel.text = makeDeviceInfoText(device)
        connectButton.setTitle("设备信息", for: .normal)
        connectButton.setImage(UIImage(systemName: "info.circle"), for: .normal)

        if shouldFetchDeviceInfo {
            channel.fetchAllDeviceInfo()
        }
    }

    private func makeDeviceInfoText(_ device: AIRECBleDevice) -> String {
        var infoItems = ["电量 \(device.battery)%", "存储 \(device.storageStr)"]
        if !device.firmwareVersion.isEmpty {
            infoItems.append("固件 \(device.firmwareVersion)")
        }
        if device.isCharging {
            infoItems.append("充电中")
        }
        if device.isRecording {
            infoItems.append("录音中")
        }
        return infoItems.joined(separator: " · ")
    }

    @objc private func connectButtonTapped() {
        if AIRECBleChannel.shared.isConnected {
            refreshBluetoothInfoView(shouldFetchDeviceInfo: true)
            return
        }

        let scanVC = ScanPeripheralViewController()
        navigationController?.pushViewController(scanVC, animated: true)
    }
}

extension HomeViewViewController: AIRECBleDelegate {

    func bleManager(_ manager: AIRECBleManager, didConnect device: AIRECBleDevice) {
        refreshBluetoothInfoView(shouldFetchDeviceInfo: true)
    }

    func bleManager(_ manager: AIRECBleManager, didDisconnect device: AIRECBleDevice?, reason: String) {
        refreshBluetoothInfoView()
    }

    func bleManager(_ manager: AIRECBleManager, didUpdateDeviceInfo device: AIRECBleDevice) {
        refreshBluetoothInfoView()
    }

    func bleManager(_ manager: AIRECBleManager, didReceiveFirmwareVersion version: String) {
        refreshBluetoothInfoView()
    }

    func bleManager(_ manager: AIRECBleManager, didChangeBluetoothState enabled: Bool) {
        if !enabled {
            refreshBluetoothInfoView()
        }
    }
}
