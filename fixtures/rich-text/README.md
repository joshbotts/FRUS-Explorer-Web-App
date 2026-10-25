# Rich-text fixtures

The inputs of the golden spans, `fixtures/golden/rich-text/spans.json` (S15d), which hold the web's
rich-text codec (`Sources/FRUSRichText`) to the Mac app's own reading of RTF. Linux's Foundation
reads no RTF, so the app's reading is made on a Mac, by `tools/mac-golden rich-text` through
`scripts/make-golden`, and CI holds the codec to it (`Tests/FRUSParityTests/RichTextGoldenTests.swift`).

- `read/` holds hand-written RTF the app reads: one `read` case per file. Each is synthetic, and
  none is a Mac export. A new file needs `scripts/make-golden` before CI passes. Besides the
  shapes Apple's writer makes, they hold what probes of AppKit found on 24 Oct 2026 and the codec
  follows: which code page each text byte is in, how `\f`, `\plain`, `\ansi`, `\mac`, `\pc` and
  `\ansicpg` set it and how far each holds, and how AppKit holds text bytes, at which words it
  decodes them and what it drops (`code-page-*.rtf`); the fonts and baseline offsets that break
  AppKit's runs (`fonts-applied.rtf`, `plain-no-font-zero.rtf`, `baseline-up-down.rtf`,
  `nosupersub.rtf`); a `\u`'s fallback text and `\uc`'s scope (`unicode-skip.rtf`), U+FFFD
  (`replacement-character.rtf`), control symbols, `\*` and a field's own text; `\bin`, a
  document's start, and the links AppKit percent-encodes (`link-characters.rtf`). A reading the
  codec does not follow, such as text in a code page it does not read, or a link whose host holds
  what a host may not, is no case here, since every case must read as the app reads it.
- `web/cases.json` holds runs, as the browser sends them, that the codec writes RTF for: one `web`
  case each. `web/<id>.rtf` is what the server stores for them, the runs made canonical
  (`RichTextRuns.canonical`) and written by the codec, written by
  `scripts/swift run frus-parity rich-text-fixtures` (make-golden runs it natively first), which
  CI checks byte for byte. The app then reads each file back, to the canonical runs.

The golden's `written` cases are made by the harness itself, through the note editor's own code
(`tools/mac-golden/Sources/mac-golden/RichText.swift`), and every written and read case is also
rewritten: the codec reads it, writes its runs in canonical form, as the server stores a web edit,
and the app reads that. The golden also holds the app's reading of every text byte of each code page
the codec reads, and of every pair of a double-byte one (ParityFormat's `RichTextCodePages`), as a
digest that the codec's reading must match on Linux too. The codec's code page tables
(`Sources/FRUSRichText/RTFCodePageTables.swift`) are made by `tools/rtf-code-pages/make`.
