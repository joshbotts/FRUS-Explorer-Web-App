# The language family's clouds and references

What the server's Word Cloud reads (PLAN's S29d): the four files the app's cloud-vector generator,
`CloudVectorsRunner.run(tagger:cloudLenses:environment:)`, writes when it counts the corpus with the web's own
tagger, `FRUSLanguage` (`Sources/FRUSLanguage`), each naming the tagger's identity, with the run's provenance. The
image copies the folder to `/usr/share/frus-light/language`, the default of `FRUS_LANGUAGE_DIR`, and the server
reads every cloud from it, holding each file to its own tagger's identity, so that the web counts in one family;
FRUS Explorer's own bundled clouds, counted by Apple's NaturalLanguage, are read no more.

| File | What it holds |
| --- | --- |
| `cloud-vectors-core.json` | The corpus's and each of the 107 subseries' 50 most used words under each of the six lenses the references price: All terms, Descriptors, Concepts, Topics, Actions and Sentiment |
| `cloud-vectors-volumes.json` | The same for each of the catalogue's 553 volumes, a thin list flagged, which the page answers with its era's |
| `keyness-baseline.json` | The corpus reference in dictionary forms, the head of each lens with its true total, which Distinctive and the collocates rank against (S29f) |
| `keyness-baseline-printed.json` | The same reference counted as printed, from the same pass |
| `provenance.json` | The family, the corpus's commit, the pin, the catalogue's and the word lists' digests, the lenses, the day, and each file's length and SHA-256 |

`scripts/make-language --corpus <folder>` makes them again, through `frus-language clouds`, from a partial clone of
the corpus's volumes that it makes outside the repository; COORDINATION §5's pin-move checklist says when. Never edit
them by hand: `LanguageFamilyParityTests` holds each to its provenance, and the provenance to the tagger, the
catalogue and the word lists at the pin, and fails when any of them has moved.
