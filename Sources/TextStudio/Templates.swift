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

import Foundation

/** A note template, built in or saved by the user. */
struct TemplateItem: Identifiable {
    let id: String
    let name: String
    let body: String
    /** User templates can be deleted; built-ins can't. */
    let builtIn: Bool

    init(builtIn name: String, body: String) {
        self.id = "builtin:" + name
        self.name = name
        self.body = body
        self.builtIn = true
    }

    init(_ t: NoteTemplate) {
        self.id = "user:" + String(describing: t.persistentModelID)
        self.name = t.name
        self.body = t.body
        self.builtIn = false
    }

    /** The body with `{{date}}`, `{{time}}` and `{{datetime}}` filled in. */
    func expanded(at date: Date = .now) -> String {
        let day = date.formatted(.iso8601.year().month().day())
        let time = date.formatted(date: .omitted, time: .shortened)

        return body
            .replacingOccurrences(of: "{{datetime}}", with: day + " " + time)
            .replacingOccurrences(of: "{{date}}", with: day)
            .replacingOccurrences(of: "{{time}}", with: time)
    }

    static let builtIns: [TemplateItem] = [
        TemplateItem(builtIn: "Bug Report", body: """
            # Bug title

            ## Repro Steps
            1. Open **App** or any other app that has the affected content
            2. Do the thing that triggers the bug
            3. Observe the issue
            4. Describe what happens next (e.g. it recovers after a few seconds)

            ## Error Logs
            `[ 0.00000000 ] paste an error log line here`

            ## Framework Logs
            `[ 0.00000000 ] paste a framework log line here`

            """),
        TemplateItem(builtIn: "Roadmap", body: """
            # Roadmap for Project

            ## Bug Fixes
            - Bug to fix
            - Discover why the **subsystem** fails to do something (`value=0`)
            > **Kernel logs**
            > `paste a log line here`

            ## Features
            - Feature to add

            """),
    ]
}
