//
//  Theme.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/5/22.
//

import UIKit

final class Theme {

    private init() {}

    static let pageBackground = UIColor(hex: 0xF1F2F6)
    static let navigationBarBackground = UIColor(hex: 0xF8F9FB)
    static let pageTitleText = UIColor(hex: 0x111827)
    static let pageSecondaryText = UIColor(hex: 0x667085)
    static let pageControlBackground = UIColor.white
    static let pageControlBorder = UIColor(hex: 0xD9DEE8)

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

    static let homePrimaryText = UIColor.white
    static let homeSecondaryText = UIColor(hex: 0xA9B3C8)
    static let homeMutedText = UIColor(hex: 0x7E8AA2)
    static let homeControlBackground = UIColor(hex: 0x111827, alpha: 0.88)
    static let homeControlBorder = UIColor(hex: 0xFFFFFF, alpha: 0.08)
    static let audioCellBackground = UIColor(hex: 0x111827, alpha: 0.9)
    static let audioCellBorder = UIColor(hex: 0xFFFFFF, alpha: 0.06)
    static let audioPlayBackground = UIColor(hex: 0x243052)
    static let audioPlayTint = UIColor(hex: 0x5D82FF)
    static let audioBlue = UIColor(hex: 0x3D91FF)
    static let audioGreen = UIColor(hex: 0x45D889)
    static let audioPurple = UIColor(hex: 0x9A62F7)
    static let audioYellow = UIColor(hex: 0xFFC744)
}
