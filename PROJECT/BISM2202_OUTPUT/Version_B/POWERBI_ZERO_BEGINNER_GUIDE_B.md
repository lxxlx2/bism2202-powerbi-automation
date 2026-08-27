# Power BI 零基础操作指南 - Version B

> 本指南以 Power BI Desktop 2026 界面为基准。新版可能启用 On-object interaction：如果右侧没有旧版 Visualizations pane，请选中 Visual 后直接在图上点 Build a visual / Add data；格式设置可双击 Visual 或右键 Format。两种界面使用相同字段槽位。

## 0. 你需要准备

1. 一台 Windows 10/11 x64 电脑或 Windows 虚拟机。macOS 没有原生 Power BI Desktop。
2. 从 Microsoft Store 安装 **Microsoft Power BI Desktop**。打开后选择空白报告。
3. 把整个 `BISM2202_OUTPUT` 目录和原始 Excel `Assignment1_BISM2202_pizza_sell_data.xlsx` 复制到 Windows 本地磁盘。不要改原始 Excel。
4. 确认右侧能看到 Data、Visualizations/Build、Filters 三个区域。若看不到，打开 View（视图）选项卡，在 Panes 中勾选相应窗格。

## 1. 导入 Excel 并执行唯一的数据清洗

1. 在 Power BI Desktop 顶部功能区点 **Home > Get data > Excel workbook**。
2. 选择 `Assignment1_BISM2202_pizza_sell_data.xlsx`，点 **Open**。
3. Navigator 左侧勾选 `Sheet1`。右侧预览应显示 25 个字段。
4. 不要直接点 Load；点 **Transform Data**，进入 Power Query Editor。Load 会直接载入，Transform Data 可先修正字段名和值。
5. 左侧 Queries 对 `Sheet1` 右键 > Rename，输入 `PizzaOrders`。
6. 选中 `Restaurant Name` 列，点 **Transform > Replace Values**。Value to Find 粘贴弯引号版本 `Marco’s Pizza`，Replace With 输入直引号版本 `Marco's Pizza`，点 OK。Applied Steps 应新增 Replaced Value。只会影响 3 行。
7. 逐列检查类型图标：Order ID/Restaurant/Location/Pizza Size/Pizza Type/Traffic Level/Payment Method/Order Month/Payment Category 为 Text；Order Time/Delivery Time 为 Date/Time；Is Peak Hour/Is Weekend/Is Delayed 为 True/False；Toppings Count、Pizza Complexity、Traffic Impact、Order Hour 为 Whole Number；其余数值字段为 Decimal Number（Delivery Duration 也可为 Whole Number）。
8. 点 **Home > Close & Apply**。返回报告画布后，Data pane 应出现 `PizzaOrders`。
9. 在左侧 Table view（表格图标）检查总行数为 1,004；不要过滤或删除 2026 行。

## 2. 创建 Measures 和 Columns

1. 在右侧 Data pane 对 `PizzaOrders` 右键 > **New measure**；也可先选中表，再点 Home > Calculations > New measure。顶部会出现公式栏。
2. 逐个复制 `COMMON/DAX_MEASURES.md` 中的 Measures。每粘贴一条按 Enter，确认表下出现计算器图标。
3. 对 `PizzaOrders` 右键 > **New column**，逐个创建 `Order Month Start`、`Peak Hour Label`、`Weekend Label`。`Order Month Start = DATE(YEAR(PizzaOrders[Order Time]), MONTH(PizzaOrders[Order Time]), 1)`，格式设为 `yyyy-MM`。
4. Q09 必须使用真实日期字段 `Order Month Start` 并设为 Ascending；不要使用源字段 `Order Month`，否则不同年份的同名月份会被错误合并。
5. 选中各平均值 Measure，在 Measure tools 把 Format 设为 Decimal number；Avg Delivery/Avg Delay 设 2 位，Avg Toppings/Avg Topping Density 设 2 或 3 位。Order Count 设 Whole number。

## 3. 新增与重命名页面

1. 报告底部点 `+` 新建页面。双击页面标签，依次创建并命名 Q01、Q02、…、Q19、Q20 Dashboard。
2. 每个 Q01–Q19 页面只放该题核心 Visual；Q19 另加 Order Time slicer；Q20 放 3 个核心 Visual。
3. 每做完一页立即 Ctrl+S。第一次保存时选择 Save As，Version A 保存为 `BISM2202_Assignment_A.pbix`，Version B 保存为 `BISM2202_Assignment_B.pbix`。

## 4. 通用界面操作

- 插入 Visual：先点画布空白处，再点 Visualizations pane 中的图表图标。新版 On-object 界面可点画布上的 Build a visual 再选择图表类型。
- 拖字段：从 Data pane 展开 `PizzaOrders`，把列或 Measure 拖到 Build visual 的 X-axis、Y-axis、Legend、Values、Rows、Column Y-axis、Line Y-axis 等槽位。
- 改汇总：字段槽位右边点下拉箭头，选 Count、Distinct count 或 Average。本指南优先拖已验证的 Measures，避免默认 Sum。
- 改标题/标签：选中 Visual > Format visual（油漆刷）> General > Title；数据标签通常在 Visual > Data labels。
- 排序：Visual 右上角 `...` > Sort axis/Sort by > 指定字段 > Ascending/Descending。
- Visual filter：先选 Visual，再在 Filters pane 的 Filters on this visual 中展开字段卡。Top N 选择 Top、输入 N、把 Measure 拖到 By value，点 Apply filter。
- 截图：确保只截完整 Visual、标题、轴/图例、标签；使用 Windows Snipping Tool，保存到对应 `screenshots/Qxx.png`。

## 5. Q1–Q20 独立步骤

### Q01 - What is the top 20 locations based on count of order number?

**目标 Visual：** Clustered column chart  
**字段槽位：** X-axis: Location; Y-axis: [Order Count]  
**筛选/排序/格式：** Top N = 20; descending; labels readable  
**标题：** `Top 20 Order Locations`

1. 在底部单击页面 `Q01`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered column chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Location; Y-axis: [Order Count]**。Measure 带计算器图标，普通列没有。
4. 保持 Visual 选中，在 Filters pane > Filters on this visual 中展开类别字段，Filter type 选 Top N；Show items 选 Top；输入 20；把 [Order Count] 拖到 By value；点 Apply filter。
5. 点 Visual 右上 `...` > Sort by [Order Count] > Descending。若 Q7 因并列显示超过 10 个位置，这是正常的 tie 行为，两个版本必须保留相同并列项。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Top 20 Order Locations`。
8. 核对 Python 基准：Atlanta, GA = 78; Milwaukee, WI = 71; Louisville, KY = 69.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q01.png`。

### Q02 - What is the average Delivery Duration (min) by Pizza Size?

**目标 Visual：** Clustered bar chart  
**字段槽位：** Y-axis: Pizza Size; X-axis: [Avg Delivery Duration]  
**筛选/排序/格式：** Data labels on; 1 decimal  
**标题：** `Delivery Time across Pizza Sizes`

1. 在底部单击页面 `Q02`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered bar chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Y-axis: Pizza Size; X-axis: [Avg Delivery Duration]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Data labels on; 1 decimal。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Delivery Time across Pizza Sizes`。
8. 核对 Python 基准：Large = 34.17; Medium = 27.53; Small = 21.86; XL = 33.08 minutes.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q02.png`。

### Q03 - What is the share of orders by Pizza Size?

**目标 Visual：** Clustered bar chart  
**字段槽位：** Y-axis: Pizza Size; X-axis: [Order Share Overall]  
**筛选/排序/格式：** Percentage labels; descending by share  
**标题：** `Pizza Size Order Distribution`

1. 在底部单击页面 `Q03`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered bar chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Y-axis: Pizza Size; X-axis: [Order Share Overall]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Percentage labels; descending by share。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 在 Format visual > Detail labels/Data labels 中开启 Category 和 Percent of total；若选项名称不同，展开 Labels 的内容选项，确保截图同时能看出类别和百分比。
7. 在 Format visual > General > Title 开启标题并输入 `Pizza Size Order Distribution`。
8. 核对 Python 基准：Medium = 429 (42.73%); Small = 132 (13.15%); total = 1,004.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q03.png`。

### Q04 - How many orders were placed with each Payment Method?

**目标 Visual：** Clustered bar chart  
**字段槽位：** Y-axis: Payment Method; X-axis: [Order Count]  
**筛选/排序/格式：** Descending by [Order Count]  
**标题：** `Payment Method Order Ranking`

1. 在底部单击页面 `Q04`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered bar chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Y-axis: Payment Method; X-axis: [Order Count]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Descending by [Order Count]。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Payment Method Order Ranking`。
8. 核对 Python 基准：Card 276; UPI 271; Wallet 208; Cash 202; Hut Points 24; Domino's Cash 23.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q04.png`。

### Q05 - What is the share of orders by Traffic Level?

**目标 Visual：** Clustered column chart  
**字段槽位：** X-axis: Traffic Level; Y-axis: [Order Share Overall]  
**筛选/排序/格式：** Percentage labels; descending by share  
**标题：** `Traffic-Level Order Mix`

1. 在底部单击页面 `Q05`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered column chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Traffic Level; Y-axis: [Order Share Overall]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Percentage labels; descending by share。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 在 Format visual > Detail labels/Data labels 中开启 Category 和 Percent of total；若选项名称不同，展开 Labels 的内容选项，确保截图同时能看出类别和百分比。
7. 在 Format visual > General > Title 开启标题并输入 `Traffic-Level Order Mix`。
8. 核对 Python 基准：Low 278 (27.69%); Medium 398 (39.64%); High 328 (32.67%).
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q05.png`。

### Q06 - What is the average Toppings Count for weekend vs. weekday orders?

**目标 Visual：** Clustered bar chart  
**字段槽位：** Y-axis: Weekend Label; X-axis: [Avg Toppings Count]  
**筛选/排序/格式：** Data labels on; 2 decimals  
**标题：** `Topping Levels on Weekends and Weekdays`

1. 在底部单击页面 `Q06`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered bar chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Y-axis: Weekend Label; X-axis: [Avg Toppings Count]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Data labels on; 2 decimals。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Topping Levels on Weekends and Weekdays`。
8. 核对 Python 基准：Weekday = 3.40; Weekend = 3.27.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q06.png`。

### Q07 - Which locations have the highest average Delivery Duration (min)?

**目标 Visual：** Clustered column chart  
**字段槽位：** X-axis: Location; Y-axis: [Avg Delivery Duration]  
**筛选/排序/格式：** Top N = 10; descending; retain ties  
**标题：** `Slowest Delivery Locations`

1. 在底部单击页面 `Q07`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered column chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Location; Y-axis: [Avg Delivery Duration]**。Measure 带计算器图标，普通列没有。
4. 保持 Visual 选中，在 Filters pane > Filters on this visual 中展开类别字段，Filter type 选 Top N；Show items 选 Top；输入 10；把 [Avg Delivery Duration] 拖到 By value；点 Apply filter。
5. 点 Visual 右上 `...` > Sort by [Avg Delivery Duration] > Descending。若 Q7 因并列显示超过 10 个位置，这是正常的 tie 行为，两个版本必须保留相同并列项。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Slowest Delivery Locations`。
8. 核对 Python 基准：Fort Wayne and Newark = 50.00; four locations = 45.00; retain visible ties.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q07.png`。

### Q08 - How many orders were placed during peak hours vs. non-peak?

**目标 Visual：** Clustered column chart  
**字段槽位：** X-axis: Peak Hour Label; Y-axis: [Order Count]  
**筛选/排序/格式：** Data labels on  
**标题：** `Orders in Peak and Non-Peak Periods`

1. 在底部单击页面 `Q08`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered column chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Peak Hour Label; Y-axis: [Order Count]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Data labels on。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 在 Format visual > Detail labels/Data labels 中开启 Category 和 Percent of total；若选项名称不同，展开 Labels 的内容选项，确保截图同时能看出类别和百分比。
7. 在 Format visual > General > Title 开启标题并输入 `Orders in Peak and Non-Peak Periods`。
8. 核对 Python 基准：Peak Hour = 949; Non-Peak Hour = 55.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q08.png`。

### Q09 - How does order volume trend across Order Month?

**目标 Visual：** Clustered column chart  
**字段槽位：** X-axis: Order Month Start; Y-axis: [Order Count]  
**筛选/排序/格式：** Order Month Start ascending; displayed as yyyy-MM from 2024-01 to 2026-07  
**标题：** `Order Volume by Month-Year`

1. 在底部单击页面 `Q09`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered column chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Order Month Start; Y-axis: [Order Count]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Order Month Start ascending; displayed as yyyy-MM from 2024-01 to 2026-07。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. X-axis 必须使用真实日期字段 `Order Month Start`（显示为 yyyy-MM），不是源字段 `Order Month`；Visual 右上 `...` > Sort axis > Order Month Start > Ascending。应出现 31 个时间点，从 2024-01 到 2026-07。
7. 在 Format visual > General > Title 开启标题并输入 `Order Volume by Month-Year`。
8. 核对 Python 基准：31 chronological points from 2024-01 to 2026-07; 2024-08 = 86; 2024-09 = 75; total = 1,004.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q09.png`。

### Q10 - What is the average Toppings Count by Pizza Size?

**目标 Visual：** Clustered bar chart  
**字段槽位：** Y-axis: Pizza Size; X-axis: [Avg Toppings Count]  
**筛选/排序/格式：** Data labels on; 2 decimals  
**标题：** `Toppings across Pizza Sizes`

1. 在底部单击页面 `Q10`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered bar chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Y-axis: Pizza Size; X-axis: [Avg Toppings Count]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Data labels on; 2 decimals。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Toppings across Pizza Sizes`。
8. 核对 Python 基准：Small 1.69; Medium 2.77; Large 3.97; XL 4.99.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q10.png`。

### Q11 - Which 2 restaurants have the lowest average Delay (min) i.e., the fastest, most reliable performers?

**目标 Visual：** Clustered column chart  
**字段槽位：** X-axis: Restaurant Name; Y-axis: [Avg Delay]  
**筛选/排序/格式：** Visual filter [Delay Rank Asc] <= 2; ascending  
**标题：** `Most Reliable Restaurants by Average Delay`

1. 在底部单击页面 `Q11`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered column chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Restaurant Name; Y-axis: [Avg Delay]**。Measure 带计算器图标，普通列没有。
4. 把 Measure `[Delay Rank Asc]` 拖到 Filters on this visual，设置 `is less than or equal to 2`，点 Apply filter。
5. Visual 右上 `...` > Sort by [Avg Delay] > Ascending，只应显示 Little Caesars 与 Domino's。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Most Reliable Restaurants by Average Delay`。
8. 核对 Python 基准：Little Caesars = 16.62; Domino's = 17.02.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q11.png`。

### Q12 - Which 5 Pizza Types have the highest average Delivery Duration (min)?

**目标 Visual：** Clustered column chart  
**字段槽位：** X-axis: Pizza Type; Y-axis: [Avg Delivery Duration]  
**筛选/排序/格式：** Top N = 5; descending  
**标题：** `Pizza Types with Longest Delivery Times`

1. 在底部单击页面 `Q12`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered column chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Pizza Type; Y-axis: [Avg Delivery Duration]**。Measure 带计算器图标，普通列没有。
4. 保持 Visual 选中，在 Filters pane > Filters on this visual 中展开类别字段，Filter type 选 Top N；Show items 选 Top；输入 5；把 [Avg Delivery Duration] 拖到 By value；点 Apply filter。
5. 点 Visual 右上 `...` > Sort by [Avg Delivery Duration] > Descending。若 Q7 因并列显示超过 10 个位置，这是正常的 tie 行为，两个版本必须保留相同并列项。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Pizza Types with Longest Delivery Times`。
8. 核对 Python 基准：Stuffed Crust 39.52; Gluten-Free 32.44; Cheese Burst 32.26; Thai Chicken 31.67; Sicilian 30.86.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q12.png`。

### Q13 - How does order volume vary by Order Hour across a typical day?

**目标 Visual：** Area chart  
**字段槽位：** X-axis: Order Hour; Y-axis: [Order Count]  
**筛选/排序/格式：** Order Hour ascending; markers optional  
**标题：** `Orders across a Typical Day`

1. 在底部单击页面 `Q13`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Area chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Order Hour; Y-axis: [Order Count]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Order Hour ascending; markers optional。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 确认 X-axis 使用 Whole Number `Order Hour`，不是把它当日期或文本；排序必须是 12、13、14、17、18、19、20、21。
7. 在 Format visual > General > Title 开启标题并输入 `Orders across a Typical Day`。
8. 核对 Python 基准：18:00 = 312; 19:00 = 328; 20:00 = 306.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q13.png`。

### Q14 - What is the average delay (min) by Traffic Level?

**目标 Visual：** Clustered bar chart  
**字段槽位：** Y-axis: Traffic Level; X-axis: [Avg Delay]  
**筛选/排序/格式：** Cool-to-warm ordered colors; labels on  
**标题：** `Traffic Conditions and Average Delay`

1. 在底部单击页面 `Q14`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered bar chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Y-axis: Traffic Level; X-axis: [Avg Delay]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Cool-to-warm ordered colors; labels on。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Traffic Conditions and Average Delay`。
8. 核对 Python 基准：Low 15.46; Medium 17.86; High 19.16.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q14.png`。

### Q15 - What proportion of orders fall into each Pizza Complexity category?

**目标 Visual：** Clustered column chart  
**字段槽位：** X-axis: Pizza Complexity; Y-axis: [Order Share Overall]  
**筛选/排序/格式：** Percentage labels  
**标题：** `Pizza Complexity Mix`

1. 在底部单击页面 `Q15`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Clustered column chart**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**X-axis: Pizza Complexity; Y-axis: [Order Share Overall]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Percentage labels。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 在 Format visual > Detail labels/Data labels 中开启 Category 和 Percent of total；若选项名称不同，展开 Labels 的内容选项，确保截图同时能看出类别和百分比。
7. 在 Format visual > General > Title 开启标题并输入 `Pizza Complexity Mix`。
8. 核对 Python 基准：Complexity 6 = 308 (30.68%); 12 = 229 (22.81%); 20 = 202 (20.12%).
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q15.png`。

### Q16 - Build a table of average Delivery Duration and Delay by Restaurant Name and use the Fx (Format by field value) button to visually highlight the fastest and slowest restaurants.

**目标 Visual：** Matrix  
**字段槽位：** Rows: Restaurant Name; Values: [Avg Delivery Duration], [Avg Delay]  
**筛选/排序/格式：** Fx > Field value using Version B color measures  
**标题：** `Restaurant Speed and Delay Matrix`

1. 在底部单击页面 `Q16`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Matrix**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Rows: Restaurant Name; Values: [Avg Delivery Duration], [Avg Delay]**。Measure 带计算器图标，普通列没有。
4. 在 Build visual 的 Values 区，点 `[Avg Delivery Duration]` 右侧下拉箭头 > Conditional formatting > Background color（新版也可到 Format visual > Cell elements 找 Fx）。
5. Conditional formatting 对话框中 Format style 选 Field value；What field should we base this on/Based on field 选 `[Delivery Duration Color B]`；Summarization 选 First；点 OK。
6. 对 `[Avg Delay]` 重复：Background color > Fx > Format style = Field value > Based on field = `[Delay Color B]` > OK。确认不是手工逐格上色。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Restaurant Speed and Delay Matrix`。
8. 核对 Python 基准：Fastest duration Papa John's 28.19; slowest Domino's 30.26; lowest delay Little Caesars 16.62; highest delay Marco's Pizza 18.44.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q16.png`。

### Q17 - How does order volume vary by Order Hour, alongside average Delay (min)?

**目标 Visual：** Two coordinated charts  
**字段槽位：** Bar: Order Hour + [Order Count]; Line: Order Hour + [Avg Delay]  
**筛选/排序/格式：** Compare volume and delay by hour  
**标题：** `When Order Pressure and Delay Rise`

1. 在底部单击页面 `Q17`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Two coordinated charts**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Bar: Order Hour + [Order Count]; Line: Order Hour + [Avg Delay]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Compare volume and delay by hour。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 在 Format visual 展开 Secondary y-axis，设为 On，并开启左右轴标题；Order Count 使用整数轴，平均值使用 1–2 位小数。
7. 在 Format visual > General > Title 开启标题并输入 `When Order Pressure and Delay Rise`。
8. 核对 Python 基准：Order peak 19:00 = 328; delay peak 20:00 = 19.97.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q17.png`。

### Q18 - How does average Topping Density vary by Pizza Type, alongside order volume?

**目标 Visual：** Two coordinated charts  
**字段槽位：** Bar: Pizza Type + [Order Count]; Line: Pizza Type + [Avg Topping Density]  
**筛选/排序/格式：** Compare volume and density  
**标题：** `Pizza Type Volume and Topping Density`

1. 在底部单击页面 `Q18`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Two coordinated charts**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Bar: Pizza Type + [Order Count]; Line: Pizza Type + [Avg Topping Density]**。Measure 带计算器图标，普通列没有。
4. 设置 Visual：Compare volume and density。若字段默认显示 Sum，点字段槽位右侧下拉箭头，改用指定 Measure 或 Average/Distinct count。
5. 点 Visual 右上 `...`，按题意完成排序；然后在 Format visual 中把 Data labels 开启，并按需要设置 1–2 位小数。
6. 在 Format visual 展开 Secondary y-axis，设为 On，并开启左右轴标题；Order Count 使用整数轴，平均值使用 1–2 位小数。
7. 在 Format visual > General > Title 开启标题并输入 `Pizza Type Volume and Topping Density`。
8. 核对 Python 基准：Non-Veg volume 216/density 0.760; Cheese Burst volume 188/density 0.845.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q18.png`。

### Q19 - What is the percentage breakdown of orders by Traffic Level within each Payment methods, filterable by order time?

**目标 Visual：** Percentage matrix + slicer  
**字段槽位：** Rows: Payment Method; Columns: Traffic Level; Values: [Order Share Within Payment]; slicer: Order Time  
**筛选/排序/格式：** Slicer style Between; each row totals 100%  
**标题：** `Traffic Composition inside Payment Methods`

1. 在底部单击页面 `Q19`，再单击画布空白处，确保没有选中别的 Visual。
2. 在 Visualizations/Build visual 中选择 **Percentage matrix + slicer**。若图标名称不确定，把鼠标停在图标上等待工具提示。
3. 从 Data pane 展开 `PizzaOrders`，按以下位置逐个拖字段：**Rows: Payment Method; Columns: Traffic Level; Values: [Order Share Within Payment]; slicer: Order Time**。Measure 带计算器图标，普通列没有。
4. 单击画布空白处，插入 Slicer visual；把 `Order Time`（不要用 Date hierarchy）拖入 Field。
5. 选中 slicer，Format visual > Visual > Slicer settings > Options > Style 选 Between。拖动左右端点，确认 100% stacked chart 会变化，再恢复完整日期范围。
6. 检查轴标题、图例和数据标签没有遮挡；必要时拉宽 Visual，不要缩小到看不清字段名。
7. 在 Format visual > General > Title 开启标题并输入 `Traffic Composition inside Payment Methods`。
8. 核对 Python 基准：Each Payment Method totals 100%; Card High = 44.57%; Cash Medium = 48.02%; UPI Medium = 47.60%; Wallet Low = 44.71%.
9. Ctrl+S 保存 PBIX；用 Windows Snipping Tool 截完整 Visual，保存为 `screenshots/Q19.png`。

### Q20 - Design three different charts or tables that use conditional formatting (or highlight them by using different colors) in a single dashboard. Explain why each one matters, what it represents, how they should be read together, and what insights emerge from viewing them as a whole.

**目标 Visual：** Dashboard: matrix + bar + line  
**字段槽位：** Restaurant Speed and Delay; Average Delay by Traffic Condition; Hourly Demand Pattern  
**筛选/排序/格式：** Three independently styled visuals  
**标题：** `Pizza Order and Delivery Performance Overview`

1. 在底部单击页面 `Q20 Dashboard`，再单击画布空白处，确保没有选中别的 Visual。
2. 插入 Clustered bar chart：Y-axis 放 Location，X-axis 放 [Order Count]；Filters on this visual 设 Top 10 by [Order Count]，降序。放在左上。
3. 插入 Clustered column chart：X-axis 放 Pizza Type，Y-axis 放 [Avg Delivery Duration]；设 Top 5 by [Avg Delivery Duration]，降序。放在左下。
4. 插入 100% stacked bar chart：Y-axis 放 Payment Method，Legend 放 Traffic Level，X-axis 放 [Order Count]。在右侧插入 Slicer，字段放 Order Time，Format > Slicer settings > Options > Style 选 Between。
5. 插入 Text box 作为页面标题 `Pizza Order and Delivery Performance Overview`。调整布局，使三个主 Visual 和 slicer 都不重叠。
6. 单击不同图形部分，确认交叉高亮有意义；若某个 Visual 变成空白，检查字段槽位和 Visual-level filters。
7. 核对 Python 基准：Exactly three main visuals, differentiated colors or conditional formatting, and an integrated explanation based on validated earlier results.
8. 保存 PBIX，用 Snipping Tool 截取完整 dashboard，保存为 `screenshots/Q20.png`。

## 6. 最终保存、截图和报告插图

1. 确认 20 个页面名称完整；Q19 slicer 可互动；Q16 两个字段都使用 Fx > Field value；Q20 有三张主要 Visual。
2. File > Save As，把 PBIX 保存到 `Version_B/BISM2202_Assignment_B.pbix`。关闭后重新打开一次，确认数据和 Visual 没有错误。
3. 检查 `screenshots/Q01.png` 到 `Q20.png` 都是真实 Power BI 截图。不要使用 Python/Excel 图代替。
4. 把项目复制回本机后，在项目根目录运行 bundled Python：`python BISM2202_OUTPUT/COMMON/build_deliverables.py`。脚本会自动把已存在的截图插入 DOCX。
5. 打开 `BISM2202_Report_B.docx`，逐题核对截图数字、标题和英文 observation 完全一致。

## 官方界面参考

- https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-excel-stunning-report
- https://learn.microsoft.com/en-us/power-bi/create-reports/power-bi-on-object-interaction
- https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-slicer-visual
- https://learn.microsoft.com/en-us/power-bi/create-reports/desktop-conditional-table-formatting
- https://learn.microsoft.com/en-us/power-bi/visuals/power-bi-visualization-combo-chart
