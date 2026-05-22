//
//  BluetoothRingView.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/5/21.
//

import UIKit
import SnapKit

class BluetoothRingView: UIView {

    private let outerRingView = UIView()
    private let middleRingView = UIView()
    private let innerRingView = UIView()
    private let bluetoothIcon = UIImageView(image: UIImage(named: "home_bluetooth"))
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        outerRingView.backgroundColor = Theme.bluetoothRingOuter
        outerRingView.layer.cornerRadius = 48
        addSubview(outerRingView)
        outerRingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.height.equalTo(96)
        }

        middleRingView.backgroundColor = Theme.bluetoothRingMiddle
        middleRingView.layer.cornerRadius = 36
        outerRingView.addSubview(middleRingView)
        middleRingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(72)
        }

        innerRingView.backgroundColor = Theme.bluetoothRingInner
        innerRingView.layer.cornerRadius = 28
        middleRingView.addSubview(innerRingView)
        innerRingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(56)
        }

        bluetoothIcon.tintColor = Theme.bluetoothRingIcon
        bluetoothIcon.contentMode = .scaleAspectFit
        innerRingView.addSubview(bluetoothIcon)
        bluetoothIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(34)
        }
    }
}
