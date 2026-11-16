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
import UniformTypeIdentifiers

/**
 * Renders a note's Markdown preview to a paginated PDF. Pages break between
 * blocks; code blocks taller than a page are split by lines.
 */
@MainActor
enum PDFExporter {
    static let fontSize = 11.0
    static let margin: CGFloat = 54   /* 0.75 in */

    /** Asks where to save, then writes the PDF. */
    static func export(_ note: Note) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = fileName(for: note.title) + ".pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try write(markdown: note.body, title: note.title, to: url)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    static func write(markdown: String, title: String, to url: URL) throws {
        let paper = NSPrintInfo.shared.paperSize
        let contentWidth = paper.width - 2 * margin
        let contentHeight = paper.height - 2 * margin
        let spacing = MarkdownView.blockSpacing(fontSize)

        func page(_ blocks: [MarkdownView.Block]) -> some View {
            MarkdownView(blocks: blocks, fontSize: fontSize, palette: .print, printable: true)
                .frame(width: contentWidth, alignment: .topLeading)
                .environment(\.colorScheme, .light)
        }

        func renderer(_ blocks: [MarkdownView.Block]) -> ImageRenderer<some View> {
            let r = ImageRenderer(content: page(blocks))
            r.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
            return r
        }

        func height(_ blocks: [MarkdownView.Block]) -> CGFloat {
            var h: CGFloat = 0
            renderer(blocks).render { size, _ in h = size.height }
            return h
        }

        /** Splits code blocks that won't fit on one page. */
        func fitted(_ block: MarkdownView.Block) -> [MarkdownView.Block] {
            guard case .code(let s) = block, height([block]) > contentHeight else { return [block] }
            let lines = s.components(separatedBy: "\n")

            guard lines.count > 1 else { return [block] }
            let mid = lines.count / 2

            return fitted(.code(lines[..<mid].joined(separator: "\n")))
                + fitted(.code(lines[mid...].joined(separator: "\n")))
        }

        /* Greedily pack blocks into pages. */
        var pages: [[MarkdownView.Block]] = []
        var current: [MarkdownView.Block] = []
        var used: CGFloat = 0

        for block in MarkdownView.parse(markdown).flatMap(fitted) {
            let h = height([block])
            let next = current.isEmpty ? h : used + spacing + h

            if next > contentHeight, !current.isEmpty {
                pages.append(current)
                current = [block]
                used = h
            } else {
                current.append(block)
                used = next
            }
        }

        if !current.isEmpty || pages.isEmpty { pages.append(current) }

        var box = CGRect(origin: .zero, size: paper)
        let info = [kCGPDFContextTitle as String: title, kCGPDFContextCreator as String: "TextStudio"]

        guard let pdf = CGContext(url as CFURL, mediaBox: &box, info as CFDictionary) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: url.path])
        }

        for blocks in pages {
            renderer(blocks).render { size, draw in
                /* Normally one sheet; more only if a single block is still taller than a page. */
                let sheets = max(1, Int(ceil((size.height - 1) / contentHeight)))

                for i in 0..<sheets {
                    pdf.beginPDFPage(nil)
                    pdf.saveGState()
                    pdf.clip(to: CGRect(x: margin, y: margin, width: contentWidth, height: contentHeight))
                    /* CG origin is bottom-left: pin the view's top to the top margin. */
                    pdf.translateBy(x: margin, y: paper.height - margin - size.height + CGFloat(i) * contentHeight)
                    draw(pdf)
                    pdf.restoreGState()
                    pdf.endPDFPage()
                }
            }
        }

        pdf.closePDF()
    }

    private static func fileName(for title: String) -> String {
        let cleaned = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")

        return cleaned.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : cleaned
    }
}
