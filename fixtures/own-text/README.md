# A section's own text: the kit's fixture volumes

No volume in `fixtures/tei` prints text at a section's own level, so none has a row of a section's
own text, the row the app's Browse lists first in a section (joshbotts/FRUS-Explorer#1536, index
versions 68 and 70). These two files are the kit's own fixtures for those rows, copied from the
pinned `FRUSExplorerTests/FRUSCoreKit/IndexingPipelineTests.swift`, where each is a suite's
`volumeXML`, with the Swift literal's indentation removed and a newline added at the end:

| File | Suite | What its sections are there for |
| --- | --- | --- |
| `frus1969-76v01.xml` | `SectionOwnTextTests` (version 68) | a meeting's list of those present, a heading's footnote, an image, a subsection, a division inside, a section that holds only sections, a front-matter kind; and sections with no row: a heading alone, an empty paragraph, a list, a section with no id, a leaf |
| `frus1945-50Intel.xml` | `IndexVersion70Tests` (version 70) | heading footnotes, on a chapter and on a section that holds only sections; rows dated by their own text, by the span of their documents and not at all; a chapter whose subsection opens before its documents; the prose kinds the index now promotes |

They are not corpus volumes: each is a short test volume under a real volume's id, as the kit's
tests and the app's Browse tests index it. FRUSParityTests indexes both with FRUSCoreKit and checks
the API's rows against the kit's rule (`OwnTextAPIParityTests`), and fails, naming the file, when
either differs from its suite's literal at the pin: a pin move that changes a literal copies it here
again. The Compose smoke test mounts `frus1969-76v01.xml` beside `fixtures/tei`, and
`scripts/synthetic-export --own-text` adds four of its rows, as the kit indexes them, for the browser
suite, with `frus1969-76v01-outline.json`, the outline the kit stores for it, keys sorted, which
gives the reader its order. The same suite holds both to the kit's index of the file.
