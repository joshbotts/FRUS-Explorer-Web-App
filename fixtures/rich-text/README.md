# Rich-text fixtures

The inputs of the golden spans, `fixtures/golden/rich-text/spans.json` (S15d), which hold the web's
rich-text codec (`Sources/FRUSRichText`) to the Mac app's own reading of RTF. Linux's Foundation
reads no RTF, so the app's reading is made on a Mac, by `tools/mac-golden rich-text` through
`scripts/make-golden`, and CI holds the codec to it (`Tests/FRUSParityTests/RichTextGoldenTests.swift`).

- `read/` holds hand-written RTF the app reads: one `read` case per file. Each is synthetic, and
  none is a Mac export. A new file needs `scripts/make-golden` before CI passes.
- `web/cases.json` holds runs, as the browser sends them, that the codec writes RTF for: one `web`
  case each. `web/<id>.rtf` is the codec's RTF for each, written by
  `scripts/swift run frus-parity rich-text-fixtures` (make-golden runs it natively first), which
  CI checks byte for byte. The app then reads each file back.

The golden's `written` cases are made by the harness itself, through the note editor's own code
(`tools/mac-golden/Sources/mac-golden/RichText.swift`), and every written and read case is also
rewritten: the codec reads it, writes it again, and the app reads that.
