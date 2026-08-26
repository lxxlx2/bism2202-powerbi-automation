# BISM2202 Mini Dashboard Final Execution Flow

This is the canonical Windows sequence after the teacher requested richer Power BI visuals.

## What the upgrade changes

The existing question visual remains the primary answer. Q01, Q04, Q07, Q09, Q13 and Q15 are upgraded into mini dashboards by adding three KPI cards above the original visual. Q20 already has three visuals and is left structurally intact.

The visual upgrade also keeps the earlier fixes:

- Q07 tied Top-N wording is accurate.
- Q09 uses English Month-Year labels in chronological order.
- Q15 uses deterministic Pizza Complexity ordering.
- A and B keep distinct palettes.
- Explicit Chinese text in visual definitions is rejected.

Saving PBIP and exporting/replacing PBIX remain manual because automated Power BI Save As has been unreliable on this Windows VM.

## 1. Close Power BI and pull latest main

```powershell
cd C:\BISM2202
git pull --ff-only origin main
Get-Process PBIDesktop -ErrorAction SilentlyContinue
```

The last command must return nothing.

## 2. Apply the complete visual upgrade to A and B

```powershell
pwsh -ExecutionPolicy Bypass `
  -File .\automation\run_visual_polish.ps1 `
  -Version Both
```

Required success lines include:

```text
VISUAL_POLISH_PYTHON_SYNTAX: PASS
REMAINING_VISUAL_ISSUES_FIX: PASS
MINI_DASHBOARD_UPGRADE: PASS
VERSION_A_POLISH_PBIR_VALIDATION: PASS
VERSION_B_POLISH_PBIR_VALIDATION: PASS
TEACHER_FEEDBACK_RICH_VISUAL_POLISH: PASS
```

## 3. Open and review Version A

```powershell
Start-Process "C:\BISM2202\PROJECT\Version_A_PowerBI\BISM2202_Seed.pbip"
```

Review checkpoints:

- Q01: three KPI cards above Top 20 Location chart.
- Q04: three KPI cards above Payment Method ranking.
- Q07: three KPI cards above location-duration ranking; Fort Wayne and Newark remain tied at 50.00.
- Q09: three KPI cards above the 31-point Jan 2024 to Jul 2026 English timeline.
- Q13: three KPI cards above hourly volume; 19:00 remains 328 orders.
- Q15: three KPI cards above complexity share visual.
- Q20: existing three-visual dashboard remains readable.
- No blank/error visuals and no visible Chinese in report content.

If approved, manually press Ctrl+S, then Save As/replace:

```text
C:\BISM2202\PROJECT\BISM2202_OUTPUT\Version_A\BISM2202_Assignment_A.pbix
```

Keep Power BI open.

## 4. Capture all A screenshots automatically

In another PowerShell window:

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass `
  -File .\automation\capture_clean_windows.ps1 `
  -Version A
```

Required:

```text
CLEAN_CAPTURE_A: 20/20 PASS
VERSION_A_SCREENSHOTS: 20 FRESH PASS
VERSION_A_HOVER_SAFE_CAPTURE: PASS
```

Then close Version A.

## 5. Open, review and save Version B

```powershell
Start-Process "C:\BISM2202\PROJECT\Version_B_PowerBI\BISM2202_Seed.pbip"
```

Use the same review checkpoints. If approved, Ctrl+S and Save As/replace:

```text
C:\BISM2202\PROJECT\BISM2202_OUTPUT\Version_B\BISM2202_Assignment_B.pbix
```

Keep Power BI open.

## 6. Capture all B screenshots automatically

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass `
  -File .\automation\capture_clean_windows.ps1 `
  -Version B
```

Required:

```text
CLEAN_CAPTURE_B: 20/20 PASS
VERSION_B_SCREENSHOTS: 20 FRESH PASS
VERSION_B_HOVER_SAFE_CAPTURE: PASS
```

Then close Power BI completely.

## 7. Rebuild reports, validate and package

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass `
  -File .\automation\teacher_feedback_workflow.ps1 `
  -Stage Finalize
```

Expected final packages:

```text
C:\BISM2202\FINAL_PACKAGES\BISM2202_Student_A_FINAL.zip
C:\BISM2202\FINAL_PACKAGES\BISM2202_Student_B_FINAL.zip
```

After Finalize pushes the updated state, perform an independent GitHub review of the final 40 screenshots, both reports and both packages before submission.
