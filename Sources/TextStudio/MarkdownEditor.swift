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

/**
 * Plain-text Markdown editor with syntax highlighting in the theme's colors.
 * Wraps NSTextView because SwiftUI's TextEditor can't style text on macOS 14.
 */
struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: Double
    let palette: Palette

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false

        let tv = scroll.documentView as! NSTextView
        tv.delegate = context.coordinator
        tv.drawsBackground = false
        tv.isRichText = false
        tv.allowsUndo = true
        tv.usesFindBar = true
        tv.isIncrementalSearchingEnabled = true
        tv.isAutomaticQuoteSubstitutionEnabled = false
        tv.isAutomaticDashSubstitutionEnabled = false
        tv.isAutomaticTextReplacementEnabled = false
        tv.textContainerInset = NSSize(width: 12, height: 10)
        tv.string = text
        context.coordinator.highlight(tv)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? NSTextView else { return }

        if tv.string != text {
            let selection = tv.selectedRanges
            tv.string = text
            tv.selectedRanges = selection.filter { NSMaxRange($0.rangeValue) <= (text as NSString).length }
        }

        context.coordinator.highlight(tv)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor

        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ note: Notification) {
            guard let tv = note.object as? NSTextView else { return }

            parent.text = tv.string
            highlight(tv)
        }

        func highlight(_ tv: NSTextView) {
            guard let storage = tv.textStorage else { return }

            let size = parent.fontSize
            let p = parent.palette
            let base = Fonts.nsMono(size)
            let para = NSMutableParagraphStyle()
            para.lineSpacing = size * 0.25

            let baseAttrs: [NSAttributedString.Key: Any] = [
                .font: base, .foregroundColor: NSColor(p.text), .paragraphStyle: para,
            ]
            tv.typingAttributes = baseAttrs
            tv.insertionPointColor = NSColor(p.accent)

            storage.beginEditing()
            storage.setAttributes(baseAttrs, range: NSRange(location: 0, length: storage.length))
            MarkdownHighlighter.apply(to: storage, palette: p, fontSize: size)
            storage.endEditing()
        }
    }
}

/** Regex-based Markdown source coloring. Later rules win over earlier ones. */
enum MarkdownHighlighter {
    private static func re(_ pattern: String, _ opts: NSRegularExpression.Options = [.anchorsMatchLines]) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: opts)
    }

    private static let heading = re(#"^(#{1,6})[ \t].*$"#)
    private static let listMarker = re(#"^[ \t]*(?:[-*+]|\d+[.)])(?=[ \t])"#)
    private static let task = re(#"^[ \t]*[-*+][ \t]+(\[[ xX]\])"#)
    private static let quote = re(#"^[ \t]*>.*$"#)
    private static let rule = re(#"^[ \t]*([-*_])(?:[ \t]*\1){2,}[ \t]*$"#)
    private static let bold = re(#"(\*\*|__)(?=\S)[^\n]*?\S\1"#)
    private static let italic = re(#"(?<![*\w])\*(?![*\s])[^*\n]*?(?<!\s)\*(?!\*)|(?<![_\w])_(?![_\s])[^_\n]*?(?<!\s)_(?![_\w])"#)
    private static let strike = re(#"~~(?=\S)[^\n]*?\S~~"#)
    private static let link = re(#"(!?\[[^\]\n]*\])(\([^)\n]*\))"#)
    private static let autolink = re(#"<https?://[^>\s]+>"#)
    private static let inlineCode = re(#"`[^`\n]+`"#)
    private static let fence = re(#"^[ \t]*(```|~~~).*?(?:^[ \t]*\1[ \t]*$|\z)"#, [.anchorsMatchLines, .dotMatchesLineSeparators])

    static func apply(to s: NSTextStorage, palette p: Palette, fontSize size: Double) {
        let str = s.string
        let all = NSRange(location: 0, length: (str as NSString).length)

        func each(_ r: NSRegularExpression, _ body: (NSTextCheckingResult) -> Void) {
            r.enumerateMatches(in: str, range: all) { m, _, _ in if let m { body(m) } }
        }

        func color(_ range: NSRange, _ c: Color) {
            if range.location != NSNotFound { s.addAttribute(.foregroundColor, value: NSColor(c), range: range) }
        }

        each(listMarker) { m in color(m.range, p.accent) }
        each(task) { m in
            let done = (str as NSString).substring(with: m.range(at: 1)).lowercased() == "[x]"
            color(m.range(at: 1), done ? p.check : p.secondary)
        }
        each(quote) { m in color(m.range, p.secondary) }
        each(rule) { m in color(m.range, p.secondary) }

        each(italic) { m in color(m.range, p.italic) }
        each(bold) { m in
            color(m.range, p.bold)
            s.addAttribute(.font, value: Fonts.nsMono(size, weight: .bold), range: m.range)
        }
        each(strike) { m in
            color(m.range, p.secondary)
            s.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: m.range)
        }
        each(link) { m in
            color(m.range(at: 1), p.link)
            color(m.range(at: 2), p.secondary)
        }
        each(autolink) { m in color(m.range, p.link) }

        each(heading) { m in
            color(m.range, p.heading(m.range(at: 1).length))
            s.addAttribute(.font, value: Fonts.nsMono(size, weight: .bold), range: m.range)
        }

        each(inlineCode) { m in
            color(m.range, p.code)
            s.addAttribute(.backgroundColor, value: NSColor(p.codeBackground).withAlphaComponent(0.85), range: m.range)
        }
        each(fence) { m in
            s.addAttributes([
                .foregroundColor: NSColor(p.code),
                .font: Fonts.nsMono(size),
                .backgroundColor: NSColor.clear,
            ], range: m.range)
        }
    }
}
