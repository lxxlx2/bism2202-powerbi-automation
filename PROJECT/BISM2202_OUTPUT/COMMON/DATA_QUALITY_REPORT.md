# BISM2202 Data Quality Report

- Source: `/Users/jerson/Documents/教学接单/BISM2202_WINDOWS_PACKAGE/INPUTS/Assignment1_BISM2202_pizza_sell_data.xlsx`
- Sheet(s): Sheet1
- Analysis sheet: `Sheet1`
- Data rows: 1,004
- Columns: 25
- Duplicate Order ID rows: 0
- Duplicate complete rows: 0
- Missing required fields: None

## Trust decision

The dataset is usable for Q1–Q20 with one documented in-memory text normalization. No source rows are deleted or edited. Restaurant-level calculations normalize the typographic apostrophe in `Marco’s Pizza` to `Marco's Pizza`; the Power BI guide applies the same Power Query replacement so Python and Power BI use one grain.

## Material findings

- No missing values, duplicate Order IDs, duplicate rows, unparseable dates, or negative/zero distances were found.
- The source contains 188 orders in 2026 even though the scenario says 2024–2025. All 1,004 rows are retained because no question authorizes a year filter.
- Three rows use the typographic variant Marco’s Pizza. It is normalized to Marco's Pizza in memory and must be replaced the same way in Power Query.
- Is Delayed exactly matches Delivery Duration (min) > 30, not the dictionary rule Delay (min) > 0. None of Q1–Q20 uses Is Delayed.
- Topping Density exactly equals Toppings Count / Distance (km), while the dictionary describes a relationship to pizza size. Q18 uses the supplied field as instructed.
- Revenue is mentioned in the scenario but no revenue field exists and none of the 20 questions asks for revenue.

## Fields, types, nulls, and unique values

| Field | Raw dtype | Nulls | Unique (incl. null) |
|---|---:|---:|---:|
| Order ID | object | 0 | 1004 |
| Restaurant Name | object | 0 | 6 |
| Location | object | 0 | 84 |
| Order Time | datetime64[ns] | 0 | 968 |
| Delivery Time | datetime64[ns] | 0 | 980 |
| Delivery Duration (min) | int64 | 0 | 8 |
| Pizza Size | object | 0 | 4 |
| Pizza Type | object | 0 | 12 |
| Toppings Count | int64 | 0 | 5 |
| Distance (km) | float64 | 0 | 25 |
| Traffic Level | object | 0 | 3 |
| Payment Method | object | 0 | 6 |
| Is Peak Hour | bool | 0 | 2 |
| Is Weekend | bool | 0 | 2 |
| Delivery Efficiency (min/km) | float64 | 0 | 40 |
| Topping Density | float64 | 0 | 37 |
| Order Month | object | 0 | 12 |
| Payment Category | object | 0 | 2 |
| Estimated Duration (min) | float64 | 0 | 25 |
| Delay (min) | float64 | 0 | 54 |
| Is Delayed | bool | 0 | 2 |
| Pizza Complexity | int64 | 0 | 10 |
| Traffic Impact | int64 | 0 | 3 |
| Order Hour | int64 | 0 | 8 |
| Restaurant Avg Time | float64 | 0 | 6 |

## Boolean fields

- `Is Peak Hour`: {'True': 949, 'False': 55}
- `Is Weekend`: {'False': 718, 'True': 286}
- `Is Delayed`: {'False': 794, 'True': 210}

## Date checks

- `Order Time`: 2024-01-05T18:30:00 to 2026-07-07T20:00:00; unparseable = 0
- `Delivery Time`: 2024-01-05T18:45:00 to 2026-07-07T20:30:00; unparseable = 0
- Orders by year: {'2024': 443, '2025': 373, '2026': 188}

## Consistency checks (mismatch counts)

- `order_month_matches_order_time`: 0
- `order_hour_matches_order_time`: 0
- `delivery_duration_matches_timestamps`: 0
- `delay_matches_actual_minus_estimated`: 0
- `delivery_efficiency_matches_duration_per_km`: 0
- `topping_density_matches_toppings_per_km`: 0
- `restaurant_avg_time_matches_group_average`: 195
- `delivery_before_order`: 0
- `is_delayed_disagrees_with_dictionary_rule_delay_gt_zero`: 794
- `is_delayed_disagrees_with_actual_rule_duration_gt_30`: 0

## Numeric ranges

| Field | Count | Min | Mean | Max |
|---|---:|---:|---:|---:|
| Delivery Duration (min) | 1004 | 15 | 29.492 | 50 |
| Toppings Count | 1004 | 1 | 3.36255 | 5 |
| Distance (km) | 1004 | 2 | 4.94562 | 10 |
| Delivery Efficiency (min/km) | 1004 | 4.16667 | 6.39701 | 12.5 |
| Topping Density | 1004 | 0.266667 | 0.714684 | 1.5 |
| Estimated Duration (min) | 1004 | 4.8 | 11.8695 | 24 |
| Delay (min) | 1004 | 9 | 17.6225 | 30.08 |
| Pizza Complexity | 1004 | 1 | 9.46813 | 20 |
| Traffic Impact | 1004 | 1 | 2.0498 | 3 |
| Order Hour | 1004 | 12 | 18.6912 | 21 |
| Restaurant Avg Time | 1004 | 26.6667 | 29.492 | 30.2865 |

## Analytical implications

- Use `DISTINCTCOUNT(Order ID)` for all order counts; `Order ID` is unique across all 1,004 rows.
- Do not filter out 2026 unless the instructor explicitly requests a 2024–2025-only correction.
- Use the actual `Order Time` month number to sort `Order Month` January through December.
- Treat `Pizza Complexity` as a categorical grouping even though its source type is numeric.
- Do not use `Is Delayed` to answer delay questions; Q11/Q14/Q16/Q17 use the numeric `Delay (min)` field.
- Q18 uses the supplied `Topping Density` field and reports the definition mismatch as a caveat, without inventing a replacement formula.
