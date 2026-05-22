//
//  Theme.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/5/22.
//

import UIKit

final class Theme {

    private init() {}

    static let pageBackground = UIColor.white

    static let bluetoothHeaderBackground = UIColor(hex: 0x0F1C3D)
    static let bluetoothHeaderBorder = UIColor(hex: 0x2A4F98, alpha: 0.35)
    static let bluetoothHeaderSeparator = UIColor(hex: 0xFFFFFF, alpha: 0.08)
    static let bluetoothHeaderPrimaryText = UIColor.white
    static let bluetoothHeaderSecondaryText = UIColor.white.withAlphaComponent(0.6)
    static let bluetoothHeaderMutedText = UIColor.white.withAlphaComponent(0.72)
    static let bluetoothHeaderIcon = UIColor.white.withAlphaComponent(0.66)
    static let bluetoothHeaderDecorative = UIColor(hex: 0x3775FF, alpha: 0.12)

    static let bluetoothButtonBackground = UIColor(hex: 0x3775FF)
    static let bluetoothButtonText = UIColor.white

    static let bluetoothRingOuter = UIColor(hex: 0x204297, alpha: 0.22)
    static let bluetoothRingMiddle = UIColor(hex: 0x2D67FF, alpha: 0.72)
    static let bluetoothRingInner = UIColor(hex: 0x11254D)
    static let bluetoothRingIcon = UIColor(hex: 0x4181FF)
}

private extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
