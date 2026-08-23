# FINAL_STATUS

## Environment

- OS: **COMPLETE** - macOS 26.6.2, Apple M4 Max / arm64.
- Power BI Desktop: **BLOCKED** - not available natively on macOS and not installed.
- Can build PBIX here: **BLOCKED** - genuine PBIX creation requires Windows Power BI Desktop.

## COMMON

- Data read: **COMPLETE** - `/Users/jerson/Documents/教学接单/BISM2202_WINDOWS_PACKAGE/INPUTS/Assignment1_BISM2202_pizza_sell_data.xlsx` / Sheet1 / 1,004 rows / 25 columns.
- Instructor requirements read: **COMPLETE** - `/Users/jerson/Documents/教学接单/BISM2202_WINDOWS_PACKAGE/INPUTS/Data Visualization Using Microsoft Power BI Assessment Task Instructions 2026 Semester 2_BISM2202.docx`; 20 questions, 20 points, screenshot plus explanation for each question, report + PBIX submission.
- Data quality check: **COMPLETE** - quality findings and one typography normalization documented.
- Python validation: **COMPLETE** - reproducible script, JSON, and XLSX created.
- Q1-Q20 calculated: **COMPLETE** - Q1-Q19 numeric outputs plus Q20 validated support metrics.
- Cross-version validation: **COMPLETE** - PASS for the shared analytical baseline.

## Version_A

- Design: **COMPLETE** - traditional business analytics specification for Q01-Q20.
- Report answers: **COMPLETE** - data-backed English draft.
- DOCX: **COMPLETE** - screenshot placeholders are intentional until genuine images exist.
- Power BI pages: **PENDING** - requires Windows Power BI Desktop.
- Screenshots: **PENDING** - `PENDING_WINDOWS_POWERBI`; no fake screenshots created.
- PBIX: **PENDING** - `PENDING_WINDOWS_POWERBI`; no fake PBIX created.
- QA: **PENDING** - checklist is complete, but final visual/PBIX checks require Windows.

## Version_B

- Design: **COMPLETE** - distinct alternative visual system using the same data.
- Report answers: **COMPLETE** - data-backed English draft with visual-specific emphasis.
- DOCX: **COMPLETE** - screenshot placeholders are intentional until genuine images exist.
- Power BI pages: **PENDING** - requires Windows Power BI Desktop.
- Screenshots: **PENDING** - `PENDING_WINDOWS_POWERBI`; no fake screenshots created.
- PBIX: **PENDING** - `PENDING_WINDOWS_POWERBI`; no fake PBIX created.
- QA: **PENDING** - checklist is complete, but final visual/PBIX checks require Windows.

## MANUAL_STEPS_REMAINING

1. Use a Windows 10/11 x64 computer or a Windows virtual machine.
2. Install Microsoft Power BI Desktop.
3. Copy the source XLSX and the entire `BISM2202_OUTPUT` directory to Windows.
4. Choose Version A or Version B and open its `POWERBI_ZERO_BEGINNER_GUIDE_*.md`.
5. Import Sheet1, rename it `PizzaOrders`, and apply the documented 3-row Restaurant Name replacement in Power Query.
6. Create the DAX measures/columns and Q01-Q20 pages exactly as documented.
7. Save genuine screenshots to `screenshots/Q01.png` through `Q20.png`.
8. Save and reopen the genuine PBIX at the required filename.
9. Copy the project back and rerun `COMMON/build_deliverables.py` to insert screenshots into the DOCX.
10. Complete every QA/screenshot checkbox, review the Word report, and submit the report plus PBIX according to Turnitin/Blackboard instructions.
