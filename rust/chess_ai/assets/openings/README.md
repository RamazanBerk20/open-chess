# Embedded Lichess Opening Book

`a.tsv` through `e.tsv` are an unmodified snapshot of the Lichess
[`chess-openings`](https://github.com/lichess-org/chess-openings) repository at
commit `17ee660257de02870636f36248e919f2e01d8e85`, retrieved on 2026-07-09.
They cover ECO volumes A through E and contain English opening names and PGN
lines. The Rust index converts the PGN into legal UCI moves at first use; no
network access is required at runtime.

The source describes the data as public-domain facts and releases any
copyrightable curation under the CC0 Public Domain Dedication. The full CC0
legal text is included as `CC0-1.0.txt`.
