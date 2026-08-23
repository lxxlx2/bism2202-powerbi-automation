# BISM2202 Windows automation

Copy this package to `C:\BISM2202`, then open PowerShell as Administrator only for the setup stage:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
cd C:\BISM2202\automation
.\environment_check.ps1
.\setup_windows.ps1
.\run_all.ps1 -Version Both
```

Every PowerShell and Python task writes evidence to `C:\BISM2202\automation\logs`.

After genuine Q01-Q20 pages exist in Microsoft Power BI Desktop and are named `Q01` through `Q20`:

```powershell
py -3.12 .\capture_pages.py --version A
py -3.12 .\validate_screenshots.py --version A
py -3.12 .\validate_powerbi.py --version A --reopen
py -3.12 .\finalize_reports.py --version A
```

`capture_pages.py` captures the real Power BI Desktop window. `finalize_reports.py` calls `build_deliverables.py` only after screenshots exist: it rebuilds the Word reports, inserts `Q01.png` under Question 1 through `Q20.png` under Question 20, and creates the final `Student_A`/`Student_B` folders. It never creates screenshots or a PBIX itself.
