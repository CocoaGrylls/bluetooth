//
//  RadarContainerView.swift
//  AIRECIOSBleDemo
//
//  Created by 李龙飞 on 2026/5/19.
//

import UIKit

import SnapKit

class ScanContainerView: UIView {
    
    let scanView = ScanPeripheralView()
    let scanTitleLabel = UILabel()
    let descLabel = UILabel()
    let stopButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = .white
        layer.cornerRadius = 20

        addSubview(scanView)
        scanView.snp.makeConstraints { make in
            make.left.equalTo(24)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(140)
        }
        scanView.startAnimation()

        scanTitleLabel.text = "正在搜索设备..."
        scanTitleLabel.font = .systemFont(ofSize: 18)
        scanTitleLabel.textColor = .darkGray
        scanTitleLabel.numberOfLines = 0
        addSubview(scanTitleLabel)
        scanTitleLabel.snp.makeConstraints { make in
            make.left.equalTo(scanView.snp.right).offset(16)
            make.right.equalToSuperview().offset(-16)
            make.top.equalTo(scanView).offset(8)
        }

        descLabel.text = "请确保设备已开启蓝牙并处于配对模式，且位于手机附近"
        descLabel.font = .systemFont(ofSize: 16)
        descLabel.textColor = .darkGray
        descLabel.numberOfLines = 0
        addSubview(descLabel)
        descLabel.snp.makeConstraints { make in
            make.left.equalTo(scanView.snp.right).offset(16)
            make.right.equalToSuperview().offset(-16)
            make.top.equalTo(scanTitleLabel.snp.bottom).offset(8)
        }

        stopButton.setTitle("停止搜索", for: .normal)
        stopButton.setTitleColor(.gray, for: .normal)
        stopButton.backgroundColor = UIColor.systemGray6
        stopButton.layer.cornerRadius = 18
        stopButton.titleLabel?.font = .systemFont(ofSize: 16)
        addSubview(stopButton)
        stopButton.snp.makeConstraints { make in
            make.left.equalTo(scanView.snp.right).offset(16)
            make.bottom.equalTo(scanView)
            make.height.equalTo(36)
            make.width.equalTo(110)
        }
    }
}
