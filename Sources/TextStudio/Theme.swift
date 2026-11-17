/*
 * TextStudio
 *
 * Copyright (c) 2026 Power
 *
 * MIT License
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import SwiftUI
import AppKit

// MARK: - Appearance setting

enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark, catppuccin, tokyoNight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .catppuccin: "Catppuccin"
        case .tokyoNight: "Tokyo Night"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark, .catppuccin, .tokyoNight: NSAppearance(named: .darkAqua)
        }
    }

    /** Colors for this theme. System, Light and Dark follow the effective color scheme. */
    func palette(_ scheme: ColorScheme) -> Palette {
        switch self {
        case .system, .light, .dark: Palette.forScheme(scheme)
        case .catppuccin: .catppuccin
        case .tokyoNight: .tokyoNight
        }
    }

    func apply() { NSApp.appearance = nsAppearance }
}

enum Prefs {
    static let defaultFontSize = 14.0
    static let minFontSize = 9.0
    static let maxFontSize = 40.0
    static func clamp(_ v: Double) -> Double { min(max(v, minFontSize), maxFontSize) }
}

// MARK: - Palettes (dark = Solarized Dark Vivid, matching Ghostty; plus Catppuccin Mocha and Tokyo Night)

struct Palette {
    let background: Color
    let text: Color
    let secondary: Color
    let headings: [Color]      /* h1, h2, h3, h4+ */
    let accent: Color
    let link: Color
    let code: Color
    let codeBackground: Color
    let bold: Color
    let italic: Color
    let quoteBar: Color
    let check: Color

    func heading(_ level: Int) -> Color { headings[min(level, headings.count) - 1] }

    static func forScheme(_ scheme: ColorScheme) -> Palette { scheme == .dark ? .dark : .light }

    static let dark = Palette(
        background: Color(hex: 0x001E27),
        text: Color(hex: 0x9CC2C3),
        secondary: Color(hex: 0x5E8B92),
        headings: [Color(hex: 0xE24D8E), Color(hex: 0x178EC8), Color(hex: 0x00B39E), Color(hex: 0xB27E28)],
        accent: Color(hex: 0x178EC8),
        link: Color(hex: 0x178EC8),
        code: Color(hex: 0x51EF84),
        codeBackground: Color(hex: 0x002831),
        bold: Color(hex: 0xFCF4DC),
        italic: Color(hex: 0xE5A54B),
        quoteBar: Color(hex: 0x006488),
        check: Color(hex: 0x6CBE6C)
    )

    static let light = Palette(
        background: Color(hex: 0xFDF6E3),
        text: Color(hex: 0x4A5F66),
        secondary: Color(hex: 0x93A1A1),
        headings: [Color(hex: 0xD33682), Color(hex: 0x268BD2), Color(hex: 0x2AA198), Color(hex: 0xB58900)],
        accent: Color(hex: 0x268BD2),
        link: Color(hex: 0x268BD2),
        code: Color(hex: 0x6C8A00),
        codeBackground: Color(hex: 0xEEE8D5),
        bold: Color(hex: 0x073642),
        italic: Color(hex: 0xCB4B16),
        quoteBar: Color(hex: 0x93A1A1),
        check: Color(hex: 0x859900)
    )

    /** Catppuccin Mocha. */
    static let catppuccin = Palette(
        background: Color(hex: 0x1E1E2E),        /* base */
        text: Color(hex: 0xCDD6F4),              /* text */
        secondary: Color(hex: 0x9399B2),         /* overlay2 */
        headings: [Color(hex: 0xF38BA8), Color(hex: 0x89B4FA), Color(hex: 0x94E2D5), Color(hex: 0xF9E2AF)],
        accent: Color(hex: 0xCBA6F7),            /* mauve */
        link: Color(hex: 0x89B4FA),              /* blue */
        code: Color(hex: 0xA6E3A1),              /* green */
        codeBackground: Color(hex: 0x181825),    /* mantle */
        bold: Color(hex: 0xF5E0DC),              /* rosewater */
        italic: Color(hex: 0xFAB387),            /* peach */
        quoteBar: Color(hex: 0x585B70),          /* surface2 */
        check: Color(hex: 0xA6E3A1)              /* green */
    )

    /** Tokyo Night (night variant). */
    static let tokyoNight = Palette(
        background: Color(hex: 0x1A1B26),
        text: Color(hex: 0xC0CAF5),
        secondary: Color(hex: 0x737AA2),
        headings: [Color(hex: 0xF7768E), Color(hex: 0x7AA2F7), Color(hex: 0x7DCFFF), Color(hex: 0xE0AF68)],
        accent: Color(hex: 0x7AA2F7),
        link: Color(hex: 0x7AA2F7),
        code: Color(hex: 0x9ECE6A),
        codeBackground: Color(hex: 0x16161E),
        bold: Color(hex: 0xBB9AF7),
        italic: Color(hex: 0xFF9E64),
        quoteBar: Color(hex: 0x3B4261),
        check: Color(hex: 0x9ECE6A)
    )

    /** Light palette on white paper, with darker body text for print. */
    static let print = Palette(
        background: .white,
        text: Color(hex: 0x2E3D42),
        secondary: Color(hex: 0x7A8B8C),
        headings: light.headings,
        accent: light.accent,
        link: light.link,
        code: Color(hex: 0x5A7300),
        codeBackground: Color(hex: 0xF4F1E8),
        bold: Color(hex: 0x073642),
        italic: light.italic,
        quoteBar: light.quoteBar,
        check: light.check
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

// MARK: - Fonts

enum Fonts {
    /** Same font Ghostty is configured with (~/.config/ghostty/config). */
    static let monoFamily = "PlemolJP Console NF"
    static let monoAvailable = NSFont(name: "PlemolJPConsoleNF-Regular", size: 12) != nil

    static func mono(_ size: Double, weight: Font.Weight = .regular) -> Font {
        monoAvailable
            ? .custom(monoFamily, size: size).weight(weight)
            : .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Frosted glass background

struct FrostedBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.state = .active
        v.material = material
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
    }
}

/**
 * The window's single frosted-glass layer. Applied once behind the whole split
 * view; glass views are costly to create, so the columns share this one.
 */
struct WindowGlass: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.background {
            FrostedBackground(material: scheme == .dark ? .hudWindow : .underWindowBackground)
                .ignoresSafeArea()
        }
    }
}

/** The theme tint over the glass, at the opacity set in Settings → Transparency. */
struct ThemeTint: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    @AppStorage("theme") private var theme: AppTheme = .dark
    @AppStorage("tintOpacity") private var tintOpacity = 0.55

    func body(content: Content) -> some View {
        content.background {
            theme.palette(scheme).background.opacity(tintOpacity)
                .ignoresSafeArea()
        }
    }
}

extension View {
    func windowGlass() -> some View { modifier(WindowGlass()) }
    func themeTint() -> some View { modifier(ThemeTint()) }
}
