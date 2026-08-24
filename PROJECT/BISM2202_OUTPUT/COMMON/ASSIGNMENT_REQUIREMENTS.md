# BISM2202 Assessment Requirements (extracted from instructor DOCX)

- Source: `C:\BISM2202\INPUTS\Data Visualization Using Microsoft Power BI Assessment Task Instructions 2026 Semester 2_BISM2202.docx`
- Course: BISM2202
- Assessment: Data Visualization Using Microsoft Power BI - Assessment Task
- Total points: 20
- Number of questions: 20
- Scenario: pizza shop chain analysis; instructor text mentions operations in 2024–2025.

## Submission requirements

1. Submit the report to Turnitin.
2. Submit both the report and the Power BI `.pbix` file to Blackboard.
3. A submission without the `.pbix` attachment will not be marked.
4. For every question, insert the relevant Power BI visualization screenshot and then write the observation/answer/explanation.

## Questions and marks

- Q1 (0.5 pt): What is the top 20 locations based on count of order number?
- Q2 (0.5 pt): What is the average Delivery Duration (min) by Pizza Size?
- Q3 (0.5 pt): What is the share of orders by Pizza Size?
- Q4 (0.5 pt): How many orders were placed with each Payment Method?
- Q5 (0.5 pt): What is the share of orders by Traffic Level?
- Q6 (0.5 pt): What is the average Toppings Count for weekend vs. weekday orders?
- Q7 (0.5 pt): Which locations have the highest average Delivery Duration (min)?
- Q8 (0.5 pt): How many orders were placed during peak hours vs. non-peak?
- Q9 (1 pt): How does order volume trend by Month-Year?
- Q10 (1 pt): What is the average Toppings Count by Pizza Size?
- Q11 (1 pt): Which 2 restaurants have the lowest average Delay (min) i.e., the fastest, most reliable performers?
- Q12 (1 pt): Which 5 Pizza Types have the highest average Delivery Duration (min)?
- Q13 (1 pt): How does order volume vary by Order Hour across a typical day?
- Q14 (1 pt): What is the average delay (min) by Traffic Level?
- Q15 (1 pt): What proportion of orders fall into each Pizza Complexity category?
- Q16 (1 pt): Build a table of average Delivery Duration and Delay by Restaurant Name and use the Fx (Format by field value) button to visually highlight the fastest and slowest restaurants.
- Q17 (2 pt): How does order volume vary by Order Hour, alongside average Delay (min)?
- Q18 (2 pt): How does average Topping Density vary by Pizza Type, alongside order volume?
- Q19 (2 pt): What is the percentage breakdown of orders by Traffic Level within each Payment methods, filterable by order time?
- Q20 (2 pt): Design three different charts or tables that use conditional formatting (or highlight them by using different colors) in a single dashboard. Explain why each one matters, what it represents, how they should be read together, and what insights emerge from viewing them as a whole.

## Data dictionary

| Column | Description |
|---|---|
| Order ID | A unique identifier for each order. |
| Restaurant Name | The name of the restaurant preparing the order. |
| Location | The location where the restaurant or order is located. |
| Order Time | The date and time when the order was placed. |
| Delivery Time | The date and time when the order was delivered. |
| Delivery Duration (min) | The total time taken to deliver the order, measured in minutes. |
| Pizza Size | The size of the pizza ordered. |
| Pizza Type | The type or variety of pizza ordered. |
| Toppings Count | The number of toppings included on the pizza. |
| Distance (km) | The distance between the restaurant and the delivery destination, measured in kilometres. |
| Traffic Level | The level of traffic during the delivery, such as low, medium, or high. |
| Payment Method | The payment method used for the order. |
| Is Peak Hour | Indicates whether the order was placed during a peak delivery period. |
| Is Weekend | Indicates whether the order was placed on a weekend. |
| Delivery Efficiency (min/km) | The average delivery time per kilometre, calculated by dividing delivery duration by distance. |
| Topping Density | The number of toppings relative to the pizza size, representing the concentration of toppings. |
| Order Month | The month in which the order was placed. |
| Payment Category | A broader classification of the payment method used for the order. |
| Estimated Duration (min) | The estimated time required to deliver the order, measured in minutes. |
| Delay (min) | The difference between the actual delivery duration and the estimated delivery duration, measured in minutes. |
| Is Delayed | Indicates whether the delivery took longer than the estimated duration. |
| Pizza Complexity | A measure or category representing the complexity of the pizza based on factors such as size and number of toppings. |
| Traffic Impact | The estimated effect of traffic conditions on the delivery duration. |
| Order Hour | The hour of the day when the order was placed. |
| Restaurant Avg Time | The average delivery or preparation time associated with the restaurant. |

## Answer format

The instructor document provides alternating fields for each question: first the visualization screenshot/image, then the written observation/answer/explanation. No word-count requirement appears in the instructor DOCX.

## PBIX and screenshot requirements

A real Power BI `.pbix` must be submitted with the report. The instructor asks for screenshots of the relevant data visualizations for all 20 questions. This workspace does not fabricate either artifact.
