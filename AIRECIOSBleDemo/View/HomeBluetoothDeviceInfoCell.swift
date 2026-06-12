//
//  HomeBluetoothDeviceInfoCell.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/5/27.
//

import UIKit
import SnapKit
import AIRECBleKit

protocol HomeBluetoothDeviceInfoCellDelegate: AnyObject {
    func homeBluetoothDeviceInfoCellDidTapConnect(_ cell: HomeBluetoothDeviceInfoCell)
}

final class HomeBluetoothDeviceInfoCell: UITableViewCell {

    static let reuseId = "HomeBluetoothDeviceInfoCell"

    weak var delegate: HomeBluetoothDeviceInfoCellDelegate?

    private let cardView = UIView()
    private let decorativeIconView = UIImageView(image: UIImage(systemName: "waveform.path.ecg.rectangle"))
    private let bluetoothRingView = HomeBluetoothRingView()
    private let connectionTitleLabel = UILabel()
    private let connectionSubtitleLabel = UILabel()
    private let connectButton = UIButton(type: .system)
    private let availableDeviceButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(device: AIRECBleDevice?) {
        if let device {
            connectionTitleLabel.text = device.name
            connectionSubtitleLabel.text = makeDeviceInfoText(device)
            connectButton.isHidden = true
        } else {
            connectionTitleLabel.text = "未连接设备"
            connectionSubtitleLabel.text = "请连接蓝牙录音卡设备"
            connectButton.isHidden = false
            connectButton.setTitle("连接设备", for: .normal)
            connectButton.setImage(UIImage(systemName: "bluetooth"), for: .normal)
        }
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.backgroundColor = Theme.bluetoothHeaderBackground
        cardView.layer.cornerRadius = 18
        cardView.layer.borderColor = Theme.bluetoothHeaderBorder.cgColor
        cardView.layer.borderWidth = 1
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }

        decorativeIconView.tintColor = Theme.bluetoothHeaderDecorative
        decorativeIconView.contentMode = .scaleAspectFit
        cardView.addSubview(decorativeIconView)
        decorativeIconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(28)
            make.right.equalToSuperview().offset(-16)
            make.width.equalTo(118)
            make.height.equalTo(86)
        }

        let topContentView = UIView()
        cardView.addSubview(topContentView)
        topContentView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalToSuperview().offset(-58)
        }

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

        connectionTitleLabel.textColor = Theme.bluetoothHeaderPrimaryText
        connectionTitleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        textStackView.addArrangedSubview(connectionTitleLabel)

        connectionSubtitleLabel.textColor = Theme.bluetoothHeaderSecondaryText
        connectionSubtitleLabel.font = UIFont.systemFont(ofSize: 16)
        connectionSubtitleLabel.numberOfLines = 2
        textStackView.addArrangedSubview(connectionSubtitleLabel)

        connectButton.setTitleColor(Theme.bluetoothButtonText, for: .normal)
        connectButton.tintColor = Theme.bluetoothButtonText
        connectButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        connectButton.backgroundColor = Theme.bluetoothButtonBackground
        connectButton.layer.cornerRadius = 22
        connectButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        connectButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        textStackView.setCustomSpacing(18, after: connectionSubtitleLabel)
        textStackView.addArrangedSubview(connectButton)
        connectButton.snp.makeConstraints { make in
            make.width.equalTo(150)
            make.height.equalTo(44)
        }

        let separatorView = UIView()
        separatorView.backgroundColor = Theme.bluetoothHeaderSeparator
        cardView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(24)
            make.bottom.equalToSuperview().offset(-58)
            make.height.equalTo(1)
        }

        availableDeviceButton.tintColor = Theme.bluetoothHeaderIcon
        availableDeviceButton.contentHorizontalAlignment = .fill
        availableDeviceButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        cardView.addSubview(availableDeviceButton)
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

        configure(device: nil)
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

    @objc private func connectTapped() {
        delegate?.homeBluetoothDeviceInfoCellDidTapConnect(self)
    }
}
