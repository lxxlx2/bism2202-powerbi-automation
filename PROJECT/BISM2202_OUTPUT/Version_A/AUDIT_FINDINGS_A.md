# Version A Audit Findings

Audit basis:
- Instructor requirements in `COMMON/ASSIGNMENT_REQUIREMENTS.md`
- Ground-truth calculations in `COMMON/analysis_results.json`
- Current PBIR visual definitions in `PROJECT/Version_A_PowerBI`
- Successful 20-page Desktop capture cycle
- Desktop render issues observed during the review cycle

## Current assessment

| Question | Status before final audit fixes | Finding |
|---|---|---|
| Q01 | PASS | Clustered bar, Location + Order Count, Top 20 filter, descending sort. |
| Q02 | PASS | Pizza Size + Avg Delivery Duration. |
| Q03 | FAIL | Treemap query is structurally bound, but Desktop rendered one giant `Order Count` block. Replace with a robust percentage chart. |
| Q04 | PASS | Payment Method + Order Count. |
| Q05 | FAIL | Same treemap construction as Q03; treated as unreliable for final submission. Replace with a robust percentage chart. |
| Q06 | PASS | Weekend Label + Avg Toppings Count. |
| Q07 | PASS | Location + Avg Delivery Duration, Top 10 and descending sort. |
| Q08 | PASS | Peak Hour Label + Order Count. |
| Q09 | FIX | Uses a DAX `FORMAT(..., "MMMM")` label under a zh-CN semantic-model culture. Replace with explicit English month labels to eliminate locale risk. |
| Q10 | PASS | Pizza Size + Avg Toppings Count. |
| Q11 | PASS | Restaurant Name + Avg Delay, Bottom 2 and ascending sort. |
| Q12 | PASS | Pizza Type + Avg Delivery Duration, Top 5 and descending sort. |
| Q13 | PASS | Order Hour + Order Count. |
| Q14 | PASS | Traffic Level + Avg Delay. |
| Q15 | FIX | Current chart uses Order Count while the question explicitly asks for proportion. Replace the value with an overall order-share percentage measure. |
| Q16 | FIX | Data and field-value conditional formatting are correct; grand-total row renders localized Chinese text. Hide matrix totals for final English-only capture. |
| Q17 | PASS | Two coordinated native visuals: order volume by hour and average delay by hour. This directly answers the “alongside” requirement. |
| Q18 | PASS | Two coordinated native visuals: order volume by pizza type and average topping density by pizza type. |
| Q19 | PASS | Payment Method + traffic legend + within-payment percentage measure; Order Time slicer is present. Final render still needs screenshot QA. |
| Q20 | FIX | Three different visual types exist and the matrix has conditional colors. Hide localized matrix total and give the traffic/hourly views distinct explicit colors. Align report prose with the actual three visuals. |

## Fix policy

`automation/final_audit_fixes.ps1` applies the required fixes without changing the underlying 1,004-order dataset:
- adds `Order Share Overall` (percentage)
- adds explicit English month labels
- rebuilds Q03, Q05, Q09 and Q15 with robust native visuals
- removes matrix totals from Q16 and Q20
- gives Q20 non-matrix visuals distinct colors
- preserves English-only subtitles/titles
- validates PBIR after changes

After the script runs, the report must be opened in Power BI Desktop and captured again with `publish_review_cycle.ps1`. A second review is required before Version A is considered final.
