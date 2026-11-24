# The fixture volumes' semantic shards

The three fixture volumes' Tier-2 shards, a shard a volume, for check 9's kernel half on the fixtures (PLAN's S26c). They are the vectors' host's own files, `joshbotts/frus-semantic-vectors` at `9be645e9c0d6c5beb6aef998416fd3304de52761`, under `generations/89481b18/shards/`, the generation the pinned app's bundled tier names, and each is the length and the SHA-256 the bundled `semantic-shards-manifest.json` names for it, which `SHA256SUMS` repeats:

| File | Documents | Bytes |
| --- | --- | --- |
| `frus1894Nicaragua.vec` | 138 | 71,272 |
| `frus1961-63v06.vec` | 120 | 61,984 |
| `frus1969-76ve09p1.vec` | 128 | 66,112 |

199,368 bytes in all. They are the only shards committed: the image holds all 553, which its build fetches from the host (`docker/fetch-vectors`), and they are model outputs derived from the public-domain Foreign Relations of the United States series, as the host's NOTICE says.

`tools/mac-golden neighbours`, which `scripts/make-golden` runs on the owner's Mac, writes each vectored fixture document's ten nearest by the kit's two stages over these shards through the app's own store, `fixtures/golden/semantic/neighbours.json`; `frus-parity neighbours` and `SemanticNeighboursTests` make the same lists on Linux through the server's store and hold them to the Mac's, in rows, order and score bits. The server's own tests open them as the image's folder (`SemanticVectorsTests`, `SemanticRouteTests`, `SemanticCommandTests`), and `VectorsImageTests` holds each to the bundled manifest. A pin move that moves the bundled `semantic-*` files to another generation copies the three shards of that generation here again, and remakes the golden file.
