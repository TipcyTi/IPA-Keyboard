import SwiftUI
import UIKit

enum Palette {
    static let canvas = adaptive(light: 0xF2F4ED, dark: 0x0C0C0C)
    static let ink = adaptive(light: 0x101010, dark: 0xF2F2EC)
    static let subink = adaptive(light: 0x767A70, dark: 0x9A9E94)
    static let hairline = adaptive(light: 0xE3E5DC, dark: 0x242424)
    static let field = adaptive(light: 0xE8EAE1, dark: 0x1A1A1A)
    static let bubble = adaptive(light: 0x111111, dark: 0x262626)
    static let onBubble = adaptive(light: 0xF2F4ED, dark: 0xF2F2EC)
}

enum Metric {
    static let margin: CGFloat = 20
    static let corner: CGFloat = 20
}

private func adaptive(light: UInt32, dark: UInt32) -> Color {
    Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
    })
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
