import SwiftUI
import UIKit

public extension Color {
    /// Builds a SwiftUI `Color` from `#RRGGBB` / `#RRGGBBAA`, falling back to a
    /// neutral gray when the string is malformed.
    init(hex: String) {
        if let ui = UIColor(hex: hex) {
            self.init(uiColor: ui)
        } else {
            self.init(uiColor: .systemGray)
        }
    }
}
