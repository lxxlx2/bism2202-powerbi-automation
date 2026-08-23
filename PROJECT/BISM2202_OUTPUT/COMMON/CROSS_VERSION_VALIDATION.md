# Cross-Version Validation

**Overall baseline result: PASS**

Version A and Version B reports, guides, DAX, and QA targets are generated from the same `analysis_results.json`. No version-specific data filters or alternative calculations are used. This PASS covers the analytical baseline; final PBIX/screenshot reconciliation remains pending on Windows.

| Metric | Version A baseline | Version B baseline | Result |
|---|---|---|---|
| Total Orders | Shared Python result | Shared Python result | PASS |
| Top 20 Locations | Shared Python result | Shared Python result | PASS |
| Average Delivery Duration by Pizza Size | Shared Python result | Shared Python result | PASS |
| Pizza Size share | Shared Python result | Shared Python result | PASS |
| Payment Method counts | Shared Python result | Shared Python result | PASS |
| Traffic Level share | Shared Python result | Shared Python result | PASS |
| Weekend / Weekday Avg Toppings | Shared Python result | Shared Python result | PASS |
| Location Avg Delivery ranking | Shared Python result | Shared Python result | PASS |
| Peak / Non-Peak counts | Shared Python result | Shared Python result | PASS |
| Monthly order totals | Shared Python result | Shared Python result | PASS |
| Avg Toppings by Pizza Size | Shared Python result | Shared Python result | PASS |
| Bottom 2 restaurants by Avg Delay | Shared Python result | Shared Python result | PASS |
| Top 5 Pizza Types by Avg Delivery Duration | Shared Python result | Shared Python result | PASS |
| Hourly Order Count | Shared Python result | Shared Python result | PASS |
| Avg Delay by Traffic Level | Shared Python result | Shared Python result | PASS |
| Pizza Complexity share | Shared Python result | Shared Python result | PASS |
| Restaurant Avg Delivery Duration | Shared Python result | Shared Python result | PASS |
| Restaurant Avg Delay | Shared Python result | Shared Python result | PASS |
| Order Hour Avg Delay | Shared Python result | Shared Python result | PASS |
| Pizza Type Avg Topping Density | Shared Python result | Shared Python result | PASS |
| Payment Method x Traffic Level percentages | Shared Python result | Shared Python result | PASS |

## Fixed shared rules

- Source rows: 1,004; DISTINCTCOUNT(Order ID): 1,004.
- Restaurant typography normalization: `Marco’s Pizza` -> `Marco's Pizza` for 3 rows, in memory/Power Query only.
- Q9 aggregates Order Month across all available years and sorts January to December by Month Number.
- Q19 percentages use Payment Method as denominator and must respond to the Order Time slicer.
- If either PBIX differs from `analysis_results.xlsx`, mark `FAIL_DATA_INCONSISTENCY`, correct the visual/filter/aggregation, and repeat the check.
