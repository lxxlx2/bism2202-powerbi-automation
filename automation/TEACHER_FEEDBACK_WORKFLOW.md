# BISM2202 teacher-feedback Windows workflow

This workflow keeps the unreliable Power BI Save / Save As step manual while automating source patching, Q01-Q20 screenshots, Word rebuild, final ZIP validation, and GitHub push.

## What the patch changes

- Version A and Version B Q09 receive an English-only month label calculated column using explicit `en-US` formatting.
- Q09 uses the English text month label as its category and a hidden numeric month key for chronological sorting.
- A remains a line chart and B remains a column chart, preserving two distinct versions.
- Existing Q01-Q20 calculations are not replaced.
- The script fails if explicit Chinese characters remain in any `visual.json` file.
- Power BI Save and Save As are never automated by this workflow.

## 1. Pull and prepare

Close all Power BI Desktop windows, then run:

```powershell
cd C:\BISM2202
git pull --ff-only origin main
pwsh -ExecutionPolicy Bypass -File .\automation\teacher_feedback_workflow.ps1 -Stage Prepare
```

## 2. Version A manual save + automatic screenshots

Open A:

```powershell
Start-Process "C:\BISM2202\PROJECT\Version_A_PowerBI\BISM2202_Seed.pbip"
```

Verify Q09 is chronological and English, for example `Jan 2024`, `Feb 2024`, `Mar 2024`.

In Power BI Desktop:

1. Save the PBIP source normally.
2. Save As / replace:
   `C:\BISM2202\PROJECT\BISM2202_OUTPUT\Version_A\BISM2202_Assignment_A.pbix`
3. Leave Power BI open.

In another PowerShell window:

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass -File .\automation\teacher_feedback_workflow.ps1 -Stage CaptureA
```

After `CAPTURE_A: PASS`, close Power BI.

## 3. Version B manual save + automatic screenshots

Open B:

```powershell
Start-Process "C:\BISM2202\PROJECT\Version_B_PowerBI\BISM2202_Seed.pbip"
```

Verify Q09 is chronological and English.

In Power BI Desktop:

1. Save the PBIP source normally.
2. Save As / replace:
   `C:\BISM2202\PROJECT\BISM2202_OUTPUT\Version_B\BISM2202_Assignment_B.pbix`
3. Leave Power BI open.

In another PowerShell window:

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass -File .\automation\teacher_feedback_workflow.ps1 -Stage CaptureB
```

After `CAPTURE_B: PASS`, close Power BI.

## 4. Rebuild reports, package, validate, and push

With Power BI fully closed:

```powershell
cd C:\BISM2202
pwsh -ExecutionPolicy Bypass -File .\automation\teacher_feedback_workflow.ps1 -Stage Finalize
```

Expected final marker:

```text
TEACHER_FEEDBACK_FINAL_DELIVERY: PASS
GIT_PUSH: PASS
```

Final local files:

```text
C:\BISM2202\FINAL_PACKAGES\BISM2202_Student_A_FINAL.zip
C:\BISM2202\FINAL_PACKAGES\BISM2202_Student_B_FINAL.zip
```

Each final ZIP contains the matching final PBIX and DOCX. The report rebuild uses the fresh Q01-Q20 screenshots captured from the real Power BI source.
