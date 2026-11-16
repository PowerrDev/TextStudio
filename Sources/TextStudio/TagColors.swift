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
import SwiftData
import AppKit

/** A tag's chosen color. Tags without one use the theme accent. */
@Model
final class TagColor {
    @Attribute(.unique) var tag: String
    var hex: Int

    init(tag: String, hex: Int) {
        self.tag = tag
        self.hex = hex
    }

    var color: Color { Color(hex: UInt32(hex)) }

    /** Sets (or with nil, clears) the color for a tag. */
    static func set(_ tag: String, hex: Int?, in context: ModelContext) {
        let existing = try? context.fetch(FetchDescriptor<TagColor>(predicate: #Predicate { $0.tag == tag })).first

        switch (existing, hex) {
        case (let e?, let h?): e.hex = h
        case (let e?, nil): context.delete(e)
        case (nil, let h?): context.insert(TagColor(tag: tag, hex: h))
        case (nil, nil): break
        }

        try? context.save()
    }

    /** Moves a color to a renamed tag. */
    static func rename(_ old: String, to new: String, in context: ModelContext) {
        guard let e = try? context.fetch(FetchDescriptor<TagColor>(predicate: #Predicate { $0.tag == old })).first
        else { return }
        let hex = e.hex
        context.delete(e)
        set(new, hex: hex, in: context)
    }
}

/** Named colors, from the Solarized accents the app's theme uses. */
enum TagPreset: CaseIterable {
    case red, orange, yellow, green, teal, blue, purple, pink, gray

    var name: String { String(describing: self).capitalized }
    var hex: Int {
        switch self {
        case .red: 0xDC322F
        case .orange: 0xCB4B16
        case .yellow: 0xB58900
        case .green: 0x859900
        case .teal: 0x2AA198
        case .blue: 0x268BD2
        case .purple: 0x6C71C4
        case .pink: 0xD33682
        case .gray: 0x839496
        }
    }
}

extension Color {
    /** sRGB value as 0xRRGGBB. */
    var hexValue: Int {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return byte(c.redComponent) << 16 | byte(c.greenComponent) << 8 | byte(c.blueComponent)
    }
}

/** "Color" submenu for a tag: presets, Custom…, and Default. */
struct TagColorMenu: View {
    let tag: String
    /** Current hex, nil when using the default. */
    let current: Int?
    let onCustom: () -> Void
    @Environment(\.modelContext) private var context

    var body: some View {
        Menu("Color") {
            ForEach(TagPreset.allCases, id: \.self) { preset in
                Toggle(isOn: Binding(
                    get: { current == preset.hex },
                    set: { _ in TagColor.set(tag, hex: preset.hex, in: context) }
                )) {
                    Label { Text(preset.name) } icon: { Self.swatch(preset.hex) }
                }
            }

            Divider()
            Toggle(isOn: Binding(
                get: { current != nil && !TagPreset.allCases.contains { $0.hex == current } },
                set: { _ in onCustom() }
            )) {
                Text("Custom…")
            }

            Toggle(isOn: Binding(
                get: { current == nil },
                set: { _ in TagColor.set(tag, hex: nil, in: context) }
            )) {
                Text("Default")
            }
        }
    }

    /** Menus render SF Symbols as templates, so draw a non-template dot. */
    static func swatch(_ hex: Int) -> Image {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            NSColor(Color(hex: UInt32(hex))).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }

        image.isTemplate = false
        return Image(nsImage: image)
    }
}

/** Sheet with a color well for choosing any color. */
struct CustomTagColorSheet: View {
    let tag: String
    @State var color: Color

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color for #\(tag)").font(.headline)
            ColorPicker("Color", selection: $color, supportsOpacity: false)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply") {
                    TagColor.set(tag, hex: color.hexValue, in: context)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 280)
    }
}

/** Identifies which tag the custom color sheet is open for. */
struct CustomColorTarget: Identifiable {
    let tag: String
    let initial: Color
    var id: String { tag }
}
