//
//  HomeViewViewController.swift
//  AIRECIOSBleDemo
//
//  Created by 李龙飞 on 2026/5/21.
//

import UIKit
import SnapKit

class HomeViewViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
    }

    private func setupView() {
        view.backgroundColor = .white
        setupBluetoothHeaderView()

    }

    private func setupBluetoothHeaderView() {
        let headerView = UIView()
        headerView.backgroundColor = UIColor(red: 22/255, green: 34/255, blue: 64/255, alpha: 1)
        headerView.layer.cornerRadius = 16
        view.addSubview(headerView)
        
        headerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(120)
        }

        // 蓝牙图标
        let bluetoothIcon = UIImageView(image: UIImage(systemName: "bluetooth"))
        bluetoothIcon.tintColor = UIColor(red: 72/255, green: 123/255, blue: 255/255, alpha: 1)
        bluetoothIcon.backgroundColor = UIColor(red: 18/255, green: 38/255, blue: 84/255, alpha: 1)
        bluetoothIcon.layer.cornerRadius = 32
        bluetoothIcon.clipsToBounds = true
        headerView.addSubview(bluetoothIcon)
        bluetoothIcon.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(20)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(64)
        }

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = "未连接设备"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        headerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.left.equalTo(bluetoothIcon.snp.right).offset(16)
            make.top.equalTo(bluetoothIcon.snp.top).offset(4)
        }

        // 副标题
        let subtitleLabel = UILabel()
        subtitleLabel.text = "请连接蓝牙录音卡设备"
        subtitleLabel.textColor = UIColor(white: 1, alpha: 0.6)
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        headerView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.left.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
        }

        // 连接按钮
        let connectButton = UIButton(type: .system)
        connectButton.setTitle("连接设备", for: .normal)
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        connectButton.backgroundColor = UIColor(red: 72/255, green: 123/255, blue: 255/255, alpha: 1)
        connectButton.layer.cornerRadius = 20
        connectButton.addTarget(self, action: #selector(connectButtonTapped), for: .touchUpInside)
        headerView.addSubview(connectButton)
        connectButton.snp.makeConstraints { make in
            make.left.equalTo(subtitleLabel)
            make.top.equalTo(subtitleLabel.snp.bottom).offset(16)
            make.width.equalTo(120)
            make.height.equalTo(40)
        }
    }

    @objc private func connectButtonTapped() {
        let scanVC = ScanPeripheralViewController()
        navigationController?.pushViewController(scanVC, animated: true)
    }
}
