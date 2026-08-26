# BISM2202 Rich Visual Workflow

This workflow implements the teacher feedback while preserving the assignment calculations.

## What the visual polish changes

- Q01: exact count labels, descending rank, Top 3 emphasis.
- Q02: exact average labels, descending average delivery duration.
- Q03: percentage labels, share ranking.
- Q04: exact counts, descending payment-method ranking.
- Q05: semantic traffic colors, percentage labels, share ranking.
- Q06: weekday/weekend colors and average labels.
- Q07: Top 10 only, exact average-minute labels, tied leaders use the same highlight.
- Q08: exact peak/non-peak counts.
- Q09: English Month-Year chronology retained; labels intentionally omitted to avoid clutter.
- Q10: exact average toppings labels and ranking.
- Q11: two lowest-delay restaurants, exact average labels, ascending delay.
- Q12: Top 5 pizza types, exact average labels, descending duration.
- Q13: exact hourly order labels; chronological category order preserved.
- Q14: semantic traffic colors and exact average-delay labels.
- Q15: percentage labels and descending share ranking.
- Q16/Q19: existing conditional formatting retained.
- Q17/Q18: existing multi-visual / multi-metric design retained.
- Q20: existing three-visual dashboard retained.

A and B use different coordinated palettes. No assignment calculation is changed by the polish script.

## Required execution order

1. Close all Power BI Desktop windows.
2. Pull GitHub and run `run_visual_polish.ps1 -Version Both`.
3. Open Version A PBIP and inspect the requested pages.
4. Manually Ctrl+S the PBIP and Save As/replace the final A PBIX.
5. Keep A open and run `teacher_feedback_workflow.ps1 -Stage CaptureA`.
6. Close A.
7. Open Version B PBIP, inspect, manually save PBIP and replace B PBIX.
8. Keep B open and run `teacher_feedback_workflow.ps1 -Stage CaptureB`.
9. Close all Power BI windows.
10. Run `teacher_feedback_workflow.ps1 -Stage Finalize`.

Saving PBIP/PBIX is intentionally manual because automated Save As has previously been unreliable in this environment.
