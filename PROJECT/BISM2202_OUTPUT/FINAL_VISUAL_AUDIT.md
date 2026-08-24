# BISM2202 Final Visual Audit

Audit date: 2026-08-24 (Asia/Bangkok)

Evidence base: both final PBIX files were opened successfully in Power BI Desktop; PBIX structure validation passed; each version has 20 distinct 2882 x 1466 canvas captures created by Windows UI Automation from the real Power BI Desktop window; both 21-page Word reports were rendered and visually inspected.

| Question | Version A | Version B | Binding / sort / format evidence | Final status |
|---|---|---|---|---|
| Q01 | Top 20 location bar chart | Top 20 location bar chart | Location + Order Count; descending Top 20; English labels | PASS |
| Q02 | Pizza-size delivery column chart | Pizza-size delivery column chart | Pizza Size + Avg Delivery Duration; English labels | PASS |
| Q03 | Pizza-size share column chart | Pizza-size share bar chart | Pizza Size + Order Share; percentages shown | PASS |
| Q04 | Payment-method bar chart | Payment-method bar chart | Payment Method + Order Count; English labels | PASS |
| Q05 | Traffic-level share bar chart | Traffic-level share column chart | Traffic Level + Order Share; percentages shown | PASS |
| Q06 | Weekday/weekend column chart | Weekday/weekend column chart | Weekend Label + Avg Toppings Count | PASS |
| Q07 | Highest-duration location bar chart | Highest-duration location bar chart | Location + Avg Delivery Duration; descending | PASS |
| Q08 | Peak/non-peak column chart | Peak/non-peak bar chart | Peak Hour Label + Order Count | PASS |
| Q09 | Month-Year line chart | Month-Year column chart | 31 points, 2024-01 through 2026-07; Order Month-Year ascending; 2024-08 = 86 | PASS |
| Q10 | Pizza-size topping column chart | Pizza-size topping column chart | Pizza Size + Avg Toppings Count | PASS |
| Q11 | Bottom-two restaurant delay bar chart | Bottom-two restaurant delay bar chart | Restaurant Name + Avg Delay; lowest two | PASS |
| Q12 | Top-five pizza-type delivery bar chart | Top-five pizza-type delivery bar chart | Pizza Type + Avg Delivery Duration; Top 5 | PASS |
| Q13 | Hourly order column chart | Hourly order column chart | Order Hour + Order Count; numeric hour order | PASS |
| Q14 | Traffic-level delay column chart | Traffic-level delay column chart | Traffic Level + Avg Delay | PASS |
| Q15 | Pizza-complexity share bar chart | Pizza-complexity share column chart | Pizza Complexity + Order Share; percentages shown | PASS |
| Q16 | Restaurant performance matrix with conditional formatting | Restaurant performance matrix with conditional formatting | Restaurant Name, Avg Delivery Duration, Avg Delay; English `Total`; two-field colour formatting | PASS |
| Q17 | Hourly volume and delay, two visuals | Hourly volume and delay, two visuals | Order Hour ascending; Order Count and Avg Delay | PASS |
| Q18 | Pizza-type order volume and topping density | Pizza-type order volume and topping density | Pizza Type, Order Count, Avg Topping Density | PASS |
| Q19 | Payment-method traffic percentage matrix + Order Time slicer | Payment-method traffic percentage matrix + Order Time slicer | Rows sum to 100%; English `Total`; Between slicer visible and interactive | PASS |
| Q20 | Three-visual operations dashboard | Three-visual operations dashboard | Restaurant matrix; Traffic Level bars (High red, Low blue, Medium yellow); Order Hour line sorted ascending | PASS |

## Required assertions

- Q09 Month-Year correction, Version A: PASS
- Q09 Month-Year correction, Version B: PASS
- Q13 hourly order, Version A: PASS
- Q13 hourly order, Version B: PASS
- Q16 two-field conditional formatting, Version A: PASS
- Q16 two-field conditional formatting, Version B: PASS
- Q19 percentage calculation and English Total, Version A: PASS
- Q19 percentage calculation and English Total, Version B: PASS
- Q19 Order Time slicer, Version A: PASS
- Q19 Order Time slicer, Version B: PASS
- Q20 three traffic colours and three visuals, Version A: PASS
- Q20 three traffic colours and three visuals, Version B: PASS
- Version A screenshots Q01-Q20: PASS (20/20, distinct, real Power BI captures)
- Version B screenshots Q01-Q20: PASS (20/20, distinct, real Power BI captures)
- Version A report: PASS (21 pages, 20 embedded screenshots, rendered cleanly)
- Version B report: PASS (21 pages, 20 embedded screenshots, rendered cleanly)
- Version A PBIX: PASS (saved, structure validated, reopened successfully)
- Version B PBIX: PASS (saved, structure validated, reopened successfully)
- Visible Chinese in submission screenshots/reports, Version A: NONE
- Visible Chinese in submission screenshots/reports, Version B: NONE
