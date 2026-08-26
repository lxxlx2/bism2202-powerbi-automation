# BISM2202 final Windows execution flow

This is the canonical post-teacher-feedback workflow.

## Design constraints

- Power BI PBIP/PBIX saving remains manual because automated Save As proved unreliable.
- Visual/source patching is automated.
- Screenshots are automated and hover-safe.
- Word rebuild, package validation, Git commit and push remain automated through Finalize.
- A and B remain separate deliverables.

## 1. Close Power BI and pull

```powershell
cd C:\BISM2202
git pull --ff-only origin main
```

## 2. Apply all visual fixes to both source projects

```powershell
pwsh -ExecutionPolicy Bypass -File .\automation\run_visual_polish.ps1 -Version Both
```

Required checkpoints:

- `VISUAL_POLISH_PYTHON_SYNTAX: PASS`
- `REMAINING_VISUAL_ISSUES_FIX: PASS`
- `VERSION_A_POLISH_PBIR_VALIDATION: PASS`
- `VERSION_B_POLISH_PBIR_VALIDATION: PASS`
- `TEACHER_FEEDBACK_RICH_VISUAL_POLISH: PASS`

Important final semantics:

- Q07 keeps the Power BI TopN=10 cutoff but retains all rows tied at the cutoff. Therefore the title no longer claims exactly ten displayed rows.
- Q15 uses the numeric Pizza Complexity scale in a deterministic high-to-low order and displays the share percentage. It no longer claims that the categories are ranked by share.
- Q09 keeps explicit English Month-Year labels.

## 3. Version A manual save

```powershell
Start-Process "C:\BISM2202\PROJECT\Version_A_PowerBI\BISM2202_Seed.pbip"
```

Inspect Q01, Q02, Q04, Q07, Q09, Q13, Q15 and Q20. Then:

1. `Ctrl+S` to save PBIP.
2. Save As / replace:
   `C:\BISM2202\PROJECT\BISM2202_OUTPUT\Version_A\BISM2202_Assignment_A.pbix`
3. Keep Power BI open.

## 4. Version A automated clean capture

In another PowerShell window:

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass -File .\automation\capture_clean_windows.ps1 -Version A
```

Required checkpoints:

- `CLEAN_CAPTURE_A: 20/20 PASS`
- `VERSION_A_SCREENSHOTS: 20 FRESH PASS`
- `VERSION_A_HOVER_SAFE_CAPTURE: PASS`

Then close Power BI.

## 5. Version B manual save

```powershell
Start-Process "C:\BISM2202\PROJECT\Version_B_PowerBI\BISM2202_Seed.pbip"
```

Perform the same visual checks. Then:

1. `Ctrl+S`.
2. Save As / replace:
   `C:\BISM2202\PROJECT\BISM2202_OUTPUT\Version_B\BISM2202_Assignment_B.pbix`
3. Keep Power BI open.

## 6. Version B automated clean capture

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass -File .\automation\capture_clean_windows.ps1 -Version B
```

Required checkpoints:

- `CLEAN_CAPTURE_B: 20/20 PASS`
- `VERSION_B_SCREENSHOTS: 20 FRESH PASS`
- `VERSION_B_HOVER_SAFE_CAPTURE: PASS`

Then close Power BI completely.

## 7. Finalize both versions

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass -File .\automation\teacher_feedback_workflow.ps1 -Stage Finalize
```

Finalize verifies the manually saved PBIX files and fresh screenshots, rebuilds both Word reports, validates 20 embedded images per report, rebuilds final packages, re-extracts/validates them, commits and pushes.

Final packages remain:

- `C:\BISM2202\FINAL_PACKAGES\BISM2202_Student_A_FINAL.zip`
- `C:\BISM2202\FINAL_PACKAGES\BISM2202_Student_B_FINAL.zip`

After the push, perform a final independent visual review of the GitHub screenshots and reports before delivery.
