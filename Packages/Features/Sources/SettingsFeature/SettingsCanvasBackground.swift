import DesignSystem
import SwiftUI

struct SettingsCanvasBackground: View {
    var body: some View {
        Color.dsWindowChrome
    }
}

#Preview("Settings canvas") {
    SettingsCanvasBackground()
        .frame(width: 1000, height: 700)
}
