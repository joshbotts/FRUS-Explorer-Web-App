# Upstream: where NARA's v2 answers put a record's record group (FRUS-Explorer#1908)

FRUS-Explorer#1942, merged as `a9abec6dadcce5741a89a2d001cb07bbb449fbff` on 2026-11-16.
- What the live answer showed: `recordGroupNumber` is not on the record and not in its `description`. It sits only on the `ancestors` member whose `levelOfDescription` is `recordGroup`, as an integer (`59`). `ancestors` sits on the record itself, not in `description`. This was read on 2026-11-16 for series 2839192 (lot 63 D 351, RG 59), from the Catalog website's keyless `catalog.archives.gov/proxy/records/search`. It serves the same index in the `/api/v2` shape (`body.hits.hits[]._source.record`), because `/api/v2/records/search` was answering every request with the website's HTML page that day (`server: AmazonS3`, `x-cache: Error from cloudfront`). A check against `/api/v2` itself is owed once it answers JSON again.
- The kit now also throws `NARACatalogError.decodingError` when a 2xx body is not a JSON object, and does not count that call. Before, it read such a body as no records. A JSON object of an unknown shape still reads as no records.
- The fixture: `FRUSExplorerTests/FRUSCoreKit/NARAAndZoteroClientHostTests.swift`, `NARALiveRecordGroupTests.liveAnswer`. It is compiled by `swift test` as well as Xcode, and holds no key and no header.

## The web's steps

1. **The pin move**, since the kit changed: move to a `v2` commit at or past `a9abec6d`, by COORDINATION §5's checklist. There is no API change and no new string.
2. **The stand-ins:** S22e's stand-ins of the Catalog API take the live shape, from the pull request's fixture.
   - Today `Tests/FRUSLightServerTests/OutsideServicesTests.swift` and `scripts/compose-smoke`'s stand-in answer with `recordGroupNumber` on the record or its `description`. Those shapes still read as before, so they keep passing, but they no longer show the live shape.
   - With the record group on the ancestor alone, a lot lookup through S22e's NARA proxy (`Sources/FRUSLightAPI/NARACatalog.swift`) must still resolve.
   - A stand-in that answers 200 with HTML now gets an error from the proxy, not an empty result. If the proxy maps the client's errors to responses, check what it sends for `decodingError`.
3. **The README:** the Known gaps line that begins "NARA and Zotero have been asked only through stand-ins", which says "a lot's lookup may find nothing until the kit reads it", should say what the live answer showed. The record group is on the `recordGroup` ancestor alone, and the kit reads it there since `a9abec6d`.
4. **Records:** a DEVLOG follow-up entry above Session 22e's.

## Taken

By S12d's pin move to the tag `1.0-release` (`08e8bac8`), which holds `a9abec6d` (the log's entry, Session 12d, which also stands for step 4's entry), steps 1 to 3:
- The stand-ins answer in the live shape: `OutsideServicesTests`' `ServiceStub.liveAnswer`, the record under `body.hits.hits[]._source` with its record group on its `recordGroup` ancestor alone, and the smoke test's nginx stand-in the same. A lot resolves through S22e's proxy, in one call.
- A stand-in that answers 200 with HTML gets `NARA_UNEXPECTED_ANSWER` (502), in the kit's sentence, "Could not interpret the NARA Catalog response.": the proxy maps `decodingError` as it did. It is kept nowhere, so the next search asks NARA again, and with the server's key its call is counted against the user as it was made, as every call the server makes is, NARA's answer or not (`aPageThatIsNotJSONIsAnErrorNotAnEmptyAnswer`).
- The README's NARA line says where the live answer puts the record group, and that the kit reads it there.

The live record also carries its scope note on the record itself, `scopeAndContentNote`, where the kit's `buildResult` reads `scopeContent` or `description.scopeAndContentNote`, so a live answer shows no scope note, on the Mac too: an upstream follow-up, named in the log's entry.
