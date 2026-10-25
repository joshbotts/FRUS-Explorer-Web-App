# RTF code pages

The generator of `Sources/FRUSRichText/RTFCodePageTables.swift` (S15d): the code pages the web's
rich-text codec decodes RTF text bytes in, as AppKit's RTF reader decodes them.

- `dump.swift` writes every byte from 0x80 of each code page the codec reads, and every lead and
  trail pair of a double-byte one, as this platform's Foundation decodes it.
- `generate.swift` writes the tables from two dumps: the Mac's, CFString's decoding, which
  AppKit's reader matched for every entry, and Linux's, from `swift:6.4-noble`'s Foundation, which
  the codec calls on Linux for the pairs the tables leave to it. A double-byte table holds what
  Linux reads otherwise as overrides.
- `make` runs both dumps, natively and through `scripts/swift --exec`, then the generator, on a Mac
  with Xcode and Docker. Run it through `upstream/FRUS-Explorer/Scripts/heavy.sh`.

Run it when `RichTextGoldenTests.theCodecReadsEveryCodePageAsTheAppDoes` names a code page after
the server image's Swift changes, or when the codec gains a page. Then run `scripts/make-golden`,
whose harness checks the codec against AppKit entry by entry, and review and commit both.
