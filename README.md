# TextStudio - Markdown Notes

A small native macOS app for writing Markdown notes, built with SwiftUI and SwiftData. Notes are stored in a local SQLite database.

## Features

- Sidebar of notes with search, sorted by last edit
- Edit, Split and Preview modes, with a native Markdown preview (headings, lists, task lists, quotes, code blocks, inline styles, links)
- Saves automatically as you type
- Zoom with ⌘+ / ⌘− / ⌘0 or a trackpad pinch
- Frosted, translucent window background with adjustable transparency
- Light and dark themes based on Solarized (dark is Solarized Dark Vivid)
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

| Shortcut | Action |
| --- | --- |
| ⌘N | New note |
| ⌫ | Delete the selected note (in the sidebar) |
| ⌘+ / ⌘= | Zoom in |
| ⌘− | Zoom out |
| ⌘0 | Reset zoom |
| ⌘, | Settings (theme, text size, transparency) |

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
  MarkdownView.swift       Markdown parser and renderer
  Note.swift               SwiftData model
  Theme.swift              Palettes, fonts, frosted background
```
