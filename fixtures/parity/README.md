# Check 3: the query list

`queries.jsonl` holds the searches check 3 runs, one JSON object per line with the fields of `ParityQuery` in `Tests/ParityFormat/Queries.swift`: `id`, `rule`, `query`, `filters` and `notes`. A filter left out of `filters` takes the app's default, every Search in switch on and no other filter. `rules.tsv` lists the rules the queries cover, as an id, a source and a summary separated by tabs, with `#` comment lines. R01–R46 are the rules the user manual's §7.2 states, and the rest are behaviours beyond it.

Every rule has at least one query, and a query with a non-zero count on the three fixture volumes, except the refusals (R22, R36, R37) and two rules the fixtures cannot show: no fixture prints ł, ø or đ (R42), and the index holds no notes or summaries, so a search with document text off counts nothing (R55). The manual's own examples are kept verbatim, and where the fixtures give them no results their notes say so.

## Ids

The golden files key their records by id and record a digest of every query's id, text and filters (`QueryList.recordDigest`), so ids stay stable:

- Never renumber, reorder or reuse an id. Ids increase down `queries.jsonl`, and a gap is a retired id.
- Add a query by appending it with the next unused id.
- Change a query by appending the new version under a new id and removing the old line, which retires its id.
- After any change but to a note or a rule, regenerate the golden files with `scripts/make-golden`: the expressions on the Mac, and the counts and results from a three-volume export.

## Counts

A count is what the app's own `SearchService` returns over an index of exactly the three fixture volumes in `fixtures/tei`, never a larger library, because BM25 ranks with whole-index statistics. `fixtures/golden/queries.results.json` records each count with the top 50 and their scores. To check a new query before committing it, run it the same way against a scratch copy of such an index.
