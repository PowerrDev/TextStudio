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

/**
 * A lightweight native Markdown renderer. Handles block structure
 * (headings, lists, quotes, code fences, rules) itself and delegates
 * inline styling (bold, italic, code, links, strikethrough) to AttributedString.
 */
struct MarkdownView: View {
    let blocks: [Block]
    var fontSize: Double = Prefs.defaultFontSize
    var palette: Palette = .dark
    /** Lays out for static rendering (PDF): code blocks wrap instead of scrolling. */
    var printable = false

    init(text: String, fontSize: Double = Prefs.defaultFontSize, palette: Palette = .dark) {
        self.init(blocks: Self.parse(text), fontSize: fontSize, palette: palette)
    }

    init(blocks: [Block], fontSize: Double = Prefs.defaultFontSize, palette: Palette = .dark, printable: Bool = false) {
        self.blocks = blocks
        self.fontSize = fontSize
        self.palette = palette
        self.printable = printable
    }

    /** Vertical gap between blocks. */
    static func blockSpacing(_ fontSize: Double) -> Double { fontSize * 0.6 }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.blockSpacing(fontSize)) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .font(.system(size: fontSize))
        .lineSpacing(fontSize * 0.2)
        .foregroundStyle(palette.text)
        .tint(palette.link)
        .textSelection(.enabled)
    }

    enum Block {
        case heading(Int, String)
        case paragraph(String)
        case bullet(String, indent: Int)
        case numbered(String, String, indent: Int)
        case task(Bool, String, indent: Int)
        case quote(String)
        case code(String)
        case rule
    }

    private var indentStep: CGFloat { fontSize * 1.2 }

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .heading(let level, let s):
            inline(s)
                .font(headingFont(level))
                .foregroundStyle(palette.heading(level))
                .padding(.top, level <= 2 ? fontSize * 0.6 : fontSize * 0.3)
            if level <= 2 {
                Rectangle().fill(palette.heading(level).opacity(0.3)).frame(height: 1)
            }

        case .paragraph(let s):
            inline(s).fixedSize(horizontal: false, vertical: true)

        case .bullet(let s, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•").foregroundStyle(palette.heading(indent % 4 + 1))
                inline(s).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(indent) * indentStep)

        case .numbered(let n, let s, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(n + ".").font(Fonts.mono(fontSize)).foregroundStyle(palette.heading(indent % 4 + 1))
                inline(s).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(indent) * indentStep)

        case .task(let done, let s, let indent):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: done ? "checkmark.square.fill" : "square")
                    .foregroundStyle(done ? palette.check : palette.secondary)
                inline(s)
                    .strikethrough(done)
                    .foregroundStyle(done ? palette.secondary : palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(indent) * indentStep)

        case .quote(let s):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5).fill(palette.quoteBar).frame(width: 3)
                inline(s).italic().foregroundStyle(palette.secondary).fixedSize(horizontal: false, vertical: true)
            }

        case .code(let s):
            Group {
                if printable {
                    codeText(s).fixedSize(horizontal: false, vertical: true)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) { codeText(s) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(palette.codeBackground.opacity(0.85)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.secondary.opacity(0.2)))

        case .rule:
            Rectangle().fill(palette.secondary.opacity(0.3)).frame(height: 1).padding(.vertical, 4)
        }
    }

    private func codeText(_ s: String) -> some View {
        Text(s)
            .font(Fonts.mono(fontSize * 0.95))
            .foregroundStyle(palette.text)
            .padding(12)
    }

    private func inline(_ s: String) -> Text {
        let opts = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)

        guard var attr = try? AttributedString(markdown: s, options: opts) else { return Text(s) }

        let runs = attr.runs.map { ($0.range, $0.inlinePresentationIntent, $0.link) }

        for (range, intent, link) in runs {
            if let intent {
                if intent.contains(.code) {
                    attr[range].font = Fonts.mono(fontSize * 0.95)
                    attr[range].foregroundColor = palette.code
                    attr[range].backgroundColor = palette.codeBackground.opacity(0.85)
                } else if intent.contains(.stronglyEmphasized) {
                    attr[range].foregroundColor = palette.bold
                } else if intent.contains(.emphasized) {
                    attr[range].foregroundColor = palette.italic
                }
            }

            if link != nil {
                attr[range].foregroundColor = palette.link
                attr[range].underlineStyle = .single
            }
        }

        return Text(attr)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .system(size: fontSize * 2.0, weight: .bold)
        case 2: .system(size: fontSize * 1.6, weight: .bold)
        case 3: .system(size: fontSize * 1.3, weight: .semibold)
        default: .system(size: fontSize * 1.1, weight: .semibold)
        }
    }

    // MARK: - Parser

    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var code: [String]? = nil

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: "\n"))); quote = [] }
        }

        for raw in text.components(separatedBy: "\n") {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            /* Fenced code blocks */
            if trimmed.hasPrefix("```") {
                if let c = code { blocks.append(.code(c.joined(separator: "\n"))); code = nil }
                else { flush(); code = [] }
                continue
            }

            if code != nil { code!.append(raw); continue }

            if trimmed.isEmpty { flush(); continue }

            let indent = (raw.prefix(while: { $0 == " " || $0 == "\t" })
                .reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }) / 2

            /* Headings */
            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                let rest = trimmed.dropFirst(level)

                if level <= 6, rest.first == " " {
                    flush()
                    blocks.append(.heading(level, rest.trimmingCharacters(in: .whitespaces)))
                    continue
                }
            }

            /* Horizontal rule */
            if ["---", "***", "___"].contains(where: { trimmed.replacingOccurrences(of: " ", with: "").hasPrefix($0) })
                && Set(trimmed.replacingOccurrences(of: " ", with: "")).count == 1 {
                flush(); blocks.append(.rule); continue
            }

            /* Quote */
            if trimmed.hasPrefix(">") {
                if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
                quote.append(trimmed.dropFirst().trimmingCharacters(in: .whitespaces))
                continue
            }

            /* Bullets & tasks */
            if let first = trimmed.first, "-*+".contains(first), trimmed.dropFirst().first == " " {
                flush()
                let item = String(trimmed.dropFirst(2))

                if item.hasPrefix("[ ] ") {
                    blocks.append(.task(false, String(item.dropFirst(4)), indent: indent))
                } else if item.lowercased().hasPrefix("[x] ") {
                    blocks.append(.task(true, String(item.dropFirst(4)), indent: indent))
                } else {
                    blocks.append(.bullet(item, indent: indent))
                }

                continue
            }

            /* Numbered list */
            let digits = trimmed.prefix(while: \.isNumber)

            if !digits.isEmpty, trimmed.dropFirst(digits.count).hasPrefix(". ") {
                flush()
                blocks.append(.numbered(String(digits), String(trimmed.dropFirst(digits.count + 2)), indent: indent))
                continue
            }

            if !quote.isEmpty { flush() }
            paragraph.append(trimmed)
        }

        if let c = code { blocks.append(.code(c.joined(separator: "\n"))) }
        flush()
        return blocks
    }
}
