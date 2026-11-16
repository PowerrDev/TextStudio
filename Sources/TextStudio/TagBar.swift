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

/** Row of tag chips above the editor, with a field to add more. */
struct TagBar: View {
    @Bindable var note: Note
    /** Every tag in use, for the suggestions menu. */
    let allTags: [String]
    /** Chosen tag colors (0xRRGGBB); others use the accent. */
    let tagHexes: [String: Int]
    let palette: Palette
    @Environment(\.modelContext) private var context

    @State private var draft = ""
    @State private var customColor: CustomColorTarget?

    private func color(_ tag: String) -> Color {
        tagHexes[tag].map { Color(hex: UInt32($0)) } ?? palette.accent
    }

    private var suggestions: [String] { allTags.filter { !note.tags.contains($0) } }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .foregroundStyle(palette.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(note.tags, id: \.self) { tag in
                        chip(tag)
                    }

                    TextField("Add tag", text: $draft)
                        .textFieldStyle(.plain)
                        .frame(width: 90)
                        .onSubmit(commit)
                        .onChange(of: draft) {
                            if draft.contains(",") { commit() }
                        }
                }
            }

            if !suggestions.isEmpty {
                Menu {
                    ForEach(suggestions, id: \.self) { tag in
                        Button { add(tag) } label: {
                            if let hex = tagHexes[tag] {
                                Label { Text(tag) } icon: { TagColorMenu.swatch(hex) }
                            } else {
                                Text(tag)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Add an existing tag")
            }
        }
        .font(.caption)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .sheet(item: $customColor) { target in
            CustomTagColorSheet(tag: target.tag, color: target.initial)
        }
    }

    private func chip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
            Button {
                note.removeTag(tag)
                try? context.save()
            } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
            .help("Remove tag")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(color(tag))
        .background(Capsule().fill(color(tag).opacity(0.15)))
        .contextMenu {
            TagColorMenu(tag: tag, current: tagHexes[tag]) {
                customColor = CustomColorTarget(tag: tag, initial: color(tag))
            }

            Button("Remove Tag") {
                note.removeTag(tag)
                try? context.save()
            }
        }
    }

    private func commit() {
        draft.split(separator: ",").forEach { add(String($0)) }
        draft = ""
    }

    private func add(_ tag: String) {
        note.addTag(tag)
        try? context.save()
    }
}
