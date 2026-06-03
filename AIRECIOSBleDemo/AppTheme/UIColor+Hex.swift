//
//  UIColor+Hex.swift
//  AIRECIOSBleDemo
//
//  Created by Codex on 2026/6/3.
//

import UIKit

extension UIColor {

    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    convenience init(hexValue: Int, alpha: CGFloat = 1) {
        self.init(hex: hexValue, alpha: alpha)
    }
}
