# 📝 TextStudio - Markdown Notes

<img width="1366" height="768" alt="image" src="https://github.com/user-attachments/assets/370137f2-42df-404e-b2bf-c26896fe8f5e" />

A small native macOS app for writing Markdown notes, built with SwiftUI and SwiftData. Notes are stored in a local SQLite database.

## Features

- Three-column layout: folders and tags, then the note list (sorted by last edit, with search), then the editor
- Folders: create, rename and delete them (their notes are kept), and move notes in from the context menu or by dragging a note onto a folder (drop on All Notes to take it out of its folder)
- Tags: add them in the tag bar above the editor (Return or comma to add, or pick an existing tag from the menu), then browse by tag in the sidebar. Right-click a tag (in the sidebar or the tag bar) to give it a color: Red, Orange, Yellow, Green, Teal, Blue, Purple, Pink, Gray, or any custom color. Rename or remove a tag across all notes from its context menu. Search also matches tags (`#tag`)
- Hide the note list (⌥⌘L or the toolbar button) for a two-column layout; clicking a folder or tag then opens its most recent note
- Duplicate a note (⌘D or its context menu)
- Templates: File ▸ New Note from Template (or hold the New Note toolbar button) with built-in **Bug Report** and **Roadmap** templates. Save any note as your own template from its context menu or File ▸ Save Note as Template…; `{{date}}`, `{{time}}` and `{{datetime}}` are filled in when a note is created from it
- Note links: write `[[Note Title]]` (or `[[Note Title|shown text]]`) to link to another note, or press ⌘K to pick one. Click a link in the preview to open that note; links to notes that don't exist yet are dimmed, and clicking one creates the note. Copy a note's link from its context menu (Copy Link)
- Claude Code access: notes are served read-only at `http://127.0.0.1:7337/` (see [Using with Claude Code](#using-with-claude-code))
- Export a note as a paginated PDF (⇧⌘E, the toolbar or its context menu), rendered from the Markdown preview in a print-friendly light style
- Edit, Split and Preview modes, with a native Markdown preview (headings, lists, task lists, quotes, code blocks, inline styles, links, Discord-style `-#` subtext)
- Saves automatically as you type
- Zoom with ⌘+ / ⌘− / ⌘0 or a trackpad pinch
- Frosted, translucent background across all three columns, with adjustable transparency
- Light and dark themes based on Solarized (dark is Solarized Dark Vivid), plus Catppuccin (Mocha and Latte) and Tokyo Night (Night and Day)
- Monospaced editor font: PlemolJP Console NF, falling back to the system mono font if it isn't installed

## Requirements

- macOS 14 Sonoma or later
- Xcode 15+ or a Swift 5.9+ toolchain

## Build and run

```sh
./build-app.sh
open TextStudio.app
```

`build-app.sh` builds a release binary with Swift Package Manager, wraps it in `TextStudio.app` with its icon and ad-hoc signs it. To build and install into `/Applications` in one step:

```sh
./build-app.sh --install
```

The app icon is `Resources/AppIcon.icns`, generated from `TextStudio.png`.

For a quick debug run without building the app bundle:

```sh
swift run
```

## Keyboard shortcuts

| Shortcut | Action                                    |
| -------- | ----------------------------------------- |
| ⌘N       | New note                                  |
| ⇧⌘N      | New folder                                |
| ⌘D       | Duplicate the selected note               |
| ⌘K       | Insert a link to another note             |
| ⇧⌘E      | Export the selected note as PDF           |
| ⌥⌘L      | Show/hide the note list                   |
| ⌫        | Delete the selected note (in the sidebar) |
| ⌘+ / ⌘=  | Zoom in                                   |
| ⌘−       | Zoom out                                  |
| ⌘0       | Reset zoom                                |
| ⌘,       | Settings (theme, text size, transparency) |

## Using with Claude Code

While TextStudio is running it serves your notes, read-only, at `http://127.0.0.1:7337/`. The server only listens on this Mac's loopback interface and rejects requests that don't address `127.0.0.1` or `localhost`. Turn it off or change the port in Settings ▸ Claude Code.

Tell Claude Code something like:

> My notes are in TextStudio at http://127.0.0.1:7337/ — use `curl` to read them.

| URL                         | Returns                                                         |
| --------------------------- | --------------------------------------------------------------- |
| `/`                         | This list of URLs                                               |
| `/notes`                    | Every note: title, URL, folder, tags, last edit (most recent first) |
| `/notes?tag=dev`, `?folder=Work` | Notes with that tag, or in that folder                     |
| `/notes.json`               | The same list as JSON                                           |
| `/notes/<id>`               | One note's Markdown                                             |
| `/note?title=<title>`       | The note with that title (follows a `[[Title]]` link)           |
| `/search?q=<text>`          | Notes whose text or tags contain the text                       |
| `/templates`                | All templates                                                   |

Right-click a note ▸ Copy Link ▸ URL for Claude Code (or Edit ▸ Copy Note URL for Claude Code) to copy the URL of a single note.

`textstudio://note/<id>` links (Copy Link ▸ App Link) open the note in TextStudio from anywhere, such as a browser or `open textstudio://note/<id>` in a terminal.

## Data

Notes are stored at:

```
~/Library/Application Support/TextStudio/Notes.store
```

To back up your notes, copy that file together with its `-shm` and `-wal` companions.

## Project layout

```
Package.swift
build-app.sh
Sources/TextStudio/
  TextStudioApp.swift      App entry, menu commands, settings
  ContentView.swift        Sidebar, editor and preview layout
  MarkdownEditor.swift     Editor with Markdown syntax highlighting
  MarkdownView.swift       Markdown parser and renderer
  Note.swift               SwiftData models
  NoteLinks.swift          [[Wiki links]], textstudio:// links, link picker
  NoteServer.swift         Read-only local HTTP server for Claude Code
  Templates.swift          Built-in note templates
  Theme.swift              Palettes, fonts, frosted background
```

## License

TextStudio is released under the [MIT License](LICENSE). Copyright (c) 2026 Power.
