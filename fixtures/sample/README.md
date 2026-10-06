# The indexing sample

Twenty-four volumes from HistoryAtState/frus at the commit in `SOURCE`, the same as `fixtures/tei`'s,
for timing FRUSCoreKit's indexer beyond the three fixtures (session 6, phase 0's exit). They span
every era of the series and both ends of its sizes, from `frus1917-72PubDip` (0.5 MB) to
`frus1958-60v03mSupp` (13.1 MB), 165 MB in all, about 5% of the corpus. The TEI itself is never
committed (CLAUDE.md, rule 6): `SHA256SUMS` names the files and their hashes. To measure, copy
them from a clone into `.build/sample-tei/`, which git and Docker ignore, check them, and index
them with a release build:

```
mkdir -p .build/sample-tei
for f in $(cut -d' ' -f3 fixtures/sample/SHA256SUMS); do cp <clone>/volumes/$f .build/sample-tei/; done
(cd .build/sample-tei && shasum -a 256 -c ../../fixtures/sample/SHA256SUMS)
scripts/swift run -c release frus-parity index --tei .build/sample-tei --metrics --out .build/sample-index.db
```
