# 27B ledger aggregation audit

This audit separates historical experiment records from valid promotion
evidence. It does not delete or rewrite raw results.

The following rows are not valid promotion headlines because they selected
quality-passing subsets, used an upper median, or combined runs after seeing
their outcomes: `Q003-Q005`, `L153`, `K198`, `L199`, `K410`, `K434`, `K441`,
`M473-M476`, and `L524`. They remain useful diagnostics but are classified as
`invalid-aggregation` for promotion purposes.

The later `R1000`, `R1001`, and `R1004` rows used complete fresh five-run sets
and passed all five strict quality checks. They supersede the invalid historical
headlines for the 27B target only. They provide no evidence for the 35B target.
