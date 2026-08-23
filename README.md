# BISM2202 Windows 一体化交接包

## 先说结论

这个包已经把能可靠自动化的部分全部脚本化：Windows 环境检查与安装、源数据复算、材料打开、真实 Power BI 窗口截图的自动命名与保存、截图回填 Word、最终验收和 ZIP 打包。

Power BI 的 20 个可视化页面和 `.pbix` **仍需在 Power BI Desktop 中按指南创建**。普通 PowerShell 没有受支持的接口，可以在一个空白本地 PBIX 中可靠地自动点击生成 20 个 Visual；使用固定坐标盲点会因分辨率、缩放、Power BI 版本和窗格位置变化而把字段放错。脚本不会伪造 PBIX，也不会用 Python 图冒充 Power BI 截图。

## `build_deliverables.py` 到底是干什么的

它是“Word 报告生成器”，不是 Power BI 生成器。

第一次运行时，`Version_A/screenshots` 和 `Version_B/screenshots` 里还没有真实截图，所以 Word 中只能出现 20 个明确的截图占位框。你在 Windows Power BI 做完图后，把截图保存成 `Q01.png` 到 `Q20.png`，再运行本包的 `06_截图回填Word.ps1`。该脚本会调用 `build_deliverables.py`，重新生成 Word，并把每张图自动插到对应题目下：

- `Q01.png` 插入 Question 1；
- `Q02.png` 插入 Question 2；
- ……
- `Q20.png` 插入 Question 20。

它还会重建题目要求、DAX、两版答案、检查表和状态文件。它**不会**创建截图、不会控制 Power BI、不会生成 `.pbix`。

## 新的一键目录：`automation`

最终把整个包放在 Windows 的 `C:\BISM2202`。以下文件各做一件明确的事：

| 文件 | 作用 |
|---|---|
| `environment_check.ps1` | 只检查 Windows 版本/ARM 补丁、内存、分辨率、缩放、Python 和 Power BI，写环境报告 |
| `setup_windows.ps1` | 用 winget 安装 Git、Python 3.12、PowerShell 7、Edge/WebView2、VC++ Runtime、Power BI，再装 Python 包 |
| `run_all.ps1` | 按顺序做环境检查、安装、复查和数据/报告准备 |
| `build_powerbi_project.py` | 复算原始 Excel、重建项目材料、准备 A/B 目录；不会伪造 PBIX |
| `capture_pages.py` | 连接已经打开的真实 Power BI Desktop，按页面名 Q01–Q20 自动切页并截真实窗口 |
| `validate_powerbi.py` | 检查 PBIX 大小，并可让 Power BI 重新打开它，验证不是假文件 |
| `validate_screenshots.py` | 检查 Q01–Q20 是否齐全、尺寸是否达标、是否重复，并核对截图元数据 |
| `finalize_reports.py` | 调用 `build_deliverables.py` 把真实截图插入 Word，再整理成 `Student_A`/`Student_B` |
| `logs/` | 保存每一步日志；出错时先看这里 |

也就是说，`build_deliverables.py` 的位置在最后半段：Power BI 页面和截图先真实存在，它才负责把图放进 Word。它不能替代 Power BI，也不会从 Python 生成假图。

## 每个文件夹是做什么的

| 路径 | 用途 | 是否提交 |
|---|---|---|
| `INPUTS/Assignment1_BISM2202_pizza_sell_data.xlsx` | 老师给的原始数据，只读使用，不要覆盖 | 通常不提交，除非老师要求 |
| `INPUTS/...BISM2202.docx` | 老师的作业说明原件 | 不提交 |
| `PROJECT/BISM2202_OUTPUT/COMMON/analysis_results.xlsx` | Python 复算出的 Q1–Q20 数值基准，用来核对 Power BI | 不提交 |
| `PROJECT/BISM2202_OUTPUT/COMMON/DAX_MEASURES.md` | 在 Power BI 中建立字段和 Measure 时复制使用 | 不提交 |
| `PROJECT/BISM2202_OUTPUT/Version_A/POWERBI_ZERO_BEGINNER_GUIDE_A.md` | Version A 从导入到 Q20 的逐步操作指南 | 不提交 |
| `PROJECT/BISM2202_OUTPUT/Version_B/POWERBI_ZERO_BEGINNER_GUIDE_B.md` | Version B 的替代视觉方案 | 不提交 |
| `Version_A或B/screenshots/Q01.png...Q20.png` | 真实 Power BI 截图，Word 生成器从这里取图 | 随 Word 内嵌；是否另交看老师要求 |
| `Version_A/BISM2202_Assignment_A.pbix` | Version A 的真实 Power BI 源文件 | **必须提交到 Blackboard** |
| `Version_A/BISM2202_Report_A.docx` | Version A 的最终 Word 报告 | **按老师要求提交** |
| `Version_B/...` | Version B 对应文件，作用相同 | 选择 B 时提交 |
| `WINDOWS_SCRIPTS/` | 自动化脚本 | 不提交 |

## Windows 需要什么

- Windows 10 或 Windows 11；建议 64 位，至少 4 GB RAM；
- 分辨率建议 1440×900 或更高，显示缩放建议 100%；
- Microsoft Power BI Desktop；
- Microsoft Edge WebView2 Runtime；
- Python 3.12，以及 `pandas`、`openpyxl`、`python-docx`、`Pillow`；
- 不要求安装 Microsoft Excel；原始 `.xlsx` 可直接由 Power BI 和 Python 读取；
- 打开/终检 Word 报告时建议安装 Microsoft Word 或 LibreOffice。

Windows on ARM 也可运行 Power BI Desktop，但应先完成 Windows Update；微软要求包含 2025-09 累积更新 KB5065789 或更新版本。

## 正确使用顺序

1. 把整个 `BISM2202_WINDOWS_PACKAGE` 解压到 Windows 本地磁盘，例如 `C:\BISM2202_WINDOWS_PACKAGE`。不要直接在 ZIP 内运行。
2. 右键开始菜单，打开 **Windows PowerShell**。如果安装软件失败，再用“以管理员身份运行”。
3. 进入包目录后执行：

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass -Force
   .\WINDOWS_SCRIPTS\00_开始.ps1 -Version A
   ```

4. `00_开始.ps1` 会检查/安装环境、复算数据并打开 Version A 的指南、DAX、Excel 数据位置和 Power BI Desktop。
5. 在 Power BI 中完全按照指南建立 Q01–Q20，第一次保存为：
   `PROJECT\BISM2202_OUTPUT\Version_A\BISM2202_Assignment_A.pbix`。
6. 每完成一页，切到该页并使用：

   ```powershell
   .\WINDOWS_SCRIPTS\05_抓取PowerBI截图.ps1 -Version A
   ```

   脚本会找到 Power BI 窗口、按 `Q01.png` 至 `Q20.png` 自动命名保存。你只需按提示切换到正确页面并按 Enter。截图前最好在 Power BI 中把 Visual 打开到焦点模式/全屏，确保标题、坐标轴、图例和标签清楚。
7. 20 张截图和 PBIX 都完成后运行：

   ```powershell
   .\WINDOWS_SCRIPTS\06_截图回填Word.ps1 -Version A
   .\WINDOWS_SCRIPTS\07_最终验收并打包.ps1 -Version A
   ```

8. 打开最终 Word 人工看一遍，再提交 `SUBMISSION_READY_VERSION_A` 中的 Word 和 PBIX。

选择 Version B 时，把所有命令中的 `A` 改为 `B`。两版数据答案相同，但视觉样式不同；**最终只需选一版完成和提交**。

## 为什么不是一个按钮完全无人值守

`00_开始.ps1` 能连续完成所有不会破坏结果的自动步骤，并在 Power BI 制图处停下。Power BI 本地 Desktop 不提供用于从空白 PBIX 建 20 页 Visual 的普通命令行接口；微软的 PBIR/项目接口需要先由 Power BI 建立有效项目，自动截图的 REST API又要求报告已发布到有权限/容量的 Power BI Service。当前包没有你的学校 Power BI Service 凭据，也不会替你上传数据。

所以最稳妥的分工是：脚本负责环境、数据、文件、截图命名、Word 回填和 QA；人在 Power BI 中负责视觉布局与字段拖放。这能保证交付物是真实、可打开、可核对的 Power BI 作业。
