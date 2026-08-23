# Deliverable QA Record

## Automated checks

- Result: `PASS`
- Source rows / distinct Order IDs: 1,004 / 1,004
- Q01 result rows: 20
- Q03, Q05, and Q15 shares: each sums to 100% within floating-point tolerance
- Q19 traffic percentages: each Payment Method sums to 100% within floating-point tolerance
- XLSX sheets: Summary, Q01-Q19, Q20_support, Data_Quality
- Spreadsheet formula/error token scan: no `#REF!`, `#DIV/0!`, `#VALUE!`, `#NAME?`, or `#N/A`
- Version A beginner-guide Q sections: 20
- Version B beginner-guide Q sections: 20
- Version A QA Q sections: 20
- Version B QA Q sections: 20
- Fake PBIX files created: 0
- Fake Power BI screenshots created: 0

## DOCX render and visual review

- Renderer: bundled headless LibreOffice through the Documents render workflow
- Version A: 21 pages rendered and every page visually inspected
- Version B: 21 pages rendered and every page visually inspected
- Clipping: none observed
- Overlap: none observed
- Broken page layout: none observed
- Missing screenshot placeholders: none observed
- Result: `PASS_WITH_EXPECTED_SCREENSHOT_PLACEHOLDERS`

## Source integrity

The two instructor-provided source files were read but not modified.

- Source XLSX SHA-256: `04527ca299bf62823516b1c1db6b2fb05afce6b67acf6fd8f37df3faffb31d09`
- Source DOCX SHA-256: `615c71d472ed71229fce73f6f96f8c0048f80c2ceaee44bfff1829bf829110f0`

Final Power BI visual, screenshot, and PBIX QA remains pending on Windows.
