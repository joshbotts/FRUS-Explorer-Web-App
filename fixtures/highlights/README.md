# Check 6 on the fixtures: highlights placed by offset

`samples.json` is the Swift half of SPEC's check 6 on the fixture volumes (PLAN's S15c). For each of
the 393 golden rows, in `fixtures/golden/render/manifest.json`'s order, it holds the flat text the
kit's `buildFlatText` makes from the row along the server's path, one full parse of its volume, as
its length in UTF-16 units and the SHA-256 of its UTF-8 bytes, with the kit's rendering version, and
highlights placed by offset over it:

- the whole row, whose length and digest stand for its text;
- its first and last words;
- a span across up to two of its blocks' boundaries (`buildFlatTextBlocks`), where one paragraph's
  last letter meets the next one's first with nothing between;
- a span holding its first line break, a `<br>` in the page;
- a few words at its middle.

Each carries the flat text between its offsets (`text`), and, where it differs, the selected text a
highlight there has, the kit's `flatTextExcerpt` (`selectedText`): across blocks, each one's part
joined by a blank line, as the app stores it. Colours follow `HighlightColor`'s order, and the last
sample of a row is stale. None ends on a line break, since the kit's renderer cannot end a range
after a `<br>`, and no text but the whole row's is longer than 160 units.

`web/e2e/highlights-check6.spec.ts` reads the file in CI's compose job and loads each row's page from
the server, as the reader's frame does, at the root and under a path. In Chromium it checks that the
page's rendering version is the row's, that the kit's offset engine builds the row's flat text, that
the page holds each sample's text between its offsets, read through the engine's map of the live
page, that the kit's selection bridge reads the kit's own range for each back to its offsets, and that
the kit's renderer draws one range for each, under its colour's name or the stale one's.
FRUSParityTests (`HighlightSamplesTests`) holds the file to the pinned kit: it makes the file again
and fails when a byte differs, and checks each sample's text and selected text against the kit's
flat text and excerpt. A pin move that changes a row's flat text fails until the file is written
again:

```bash
scripts/swift run frus-parity highlight-samples --out fixtures/highlights/samples.json
```
