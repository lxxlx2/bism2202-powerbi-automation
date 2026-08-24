# BISM2202 Power BI Assessment - Version B

Student Name: __________

Student ID: __________

## Q1

What is the top 20 locations based on count of order number?

[Insert Power BI screenshot: screenshots/Q01.png]

Observation:

The compact ranking keeps Atlanta, GA as the leading location at 78 orders, ahead of Milwaukee, WI (71) and Louisville, KY (69). The alternative orientation emphasizes the size gap among the top demand locations.

## Q2

What is the average Delivery Duration (min) by Pizza Size?

[Insert Power BI screenshot: screenshots/Q02.png]

Observation:

The bars place Large pizzas at the longest average delivery time, 34.17 minutes. Small pizzas are clearly lower at 21.86 minutes, while XL and Large are relatively close.

## Q3

What is the share of orders by Pizza Size?

[Insert Power BI screenshot: screenshots/Q03.png]

Observation:

The treemap gives the largest area to Medium pizzas, which generated 429 orders or 42.73% of the total. Small pizzas occupy the smallest area at 132 orders or 13.15%.

## Q4

How many orders were placed with each Payment Method?

[Insert Power BI screenshot: screenshots/Q04.png]

Observation:

The horizontal ranking shows Card (276) and UPI (271) as the two dominant payment methods. Wallet and Cash follow at 208 and 202, while the two restaurant-specific methods each have fewer than 25 orders.

## Q5

What is the share of orders by Traffic Level?

[Insert Power BI screenshot: screenshots/Q05.png]

Observation:

Medium traffic forms the largest block at 398 orders (39.64%). High traffic contributes 328 orders (32.67%) and Low traffic contributes 278 (27.69%).

## Q6

What is the average Toppings Count for weekend vs. weekday orders?

[Insert Power BI screenshot: screenshots/Q06.png]

Observation:

Weekday orders average 3.40 toppings and weekend orders average 3.27. The short bars are close, confirming that the observed difference is only about 0.13.

## Q7

Which locations have the highest average Delivery Duration (min)?

[Insert Power BI screenshot: screenshots/Q07.png]

Observation:

Fort Wayne and Newark form the highest pair at 50.00 minutes. Four more locations share 45.00 minutes, so the column view should retain and clearly label tied results at the filter boundary.

## Q8

How many orders were placed during peak hours vs. non-peak?

[Insert Power BI screenshot: screenshots/Q08.png]

Observation:

The columns show a strong imbalance: 949 Peak Hour orders versus 55 Non-Peak Hour orders. Peak periods represent 94.52% of all orders in the source.

## Q9

How does order volume trend across Order Month?

[Insert Power BI screenshot: screenshots/Q09.png]

Observation:

The 31 Month-Year columns run chronologically from 2024-01 to 2026-07. The largest point is 2024-08 with 86 orders, followed by 2024-09 with 75; the series then falls to 44 in 2024-10. The 2024-05 point is lowest at 6 orders, while 2026-07 contains 7 orders through 7 July only.

## Q10

What is the average Toppings Count by Pizza Size?

[Insert Power BI screenshot: screenshots/Q10.png]

Observation:

XL stands out with an average of 4.99 toppings, while Small averages only 1.69. Large and Medium fall between them at 3.97 and 2.77.

## Q11

Which 2 restaurants have the lowest average Delay (min) i.e., the fastest, most reliable performers?

[Insert Power BI screenshot: screenshots/Q11.png]

Observation:

Little Caesars is the first low-delay performer at 16.62 minutes, followed by Domino's at 17.02. The two-column comparison uses the same bottom-two ranking as Version A.

## Q12

Which 5 Pizza Types have the highest average Delivery Duration (min)?

[Insert Power BI screenshot: screenshots/Q12.png]

Observation:

Stuffed Crust is separated from the other top-five pizza types at 39.52 minutes. The next four range from 30.86 to 32.44 minutes, led by Gluten-Free.

## Q13

How does order volume vary by Order Hour across a typical day?

[Insert Power BI screenshot: screenshots/Q13.png]

Observation:

The area is concentrated around 18:00–20:00. Order volume reaches 328 at 19:00, with 312 at 18:00 and 306 at 20:00; other observed hours contribute relatively few orders.

## Q14

What is the average delay (min) by Traffic Level?

[Insert Power BI screenshot: screenshots/Q14.png]

Observation:

The ordered bars rise from 15.46 minutes under Low traffic to 17.86 under Medium and 19.16 under High traffic. The color progression reinforces the observed association without treating it as causal proof.

## Q15

What proportion of orders fall into each Pizza Complexity category?

[Insert Power BI screenshot: screenshots/Q15.png]

Observation:

Complexity 6 occupies the largest treemap area with 30.68% of orders. Complexity 12 and 20 add 22.81% and 20.12%, so these three categories together dominate the mix.

## Q16

Build a table of average Delivery Duration and Delay by Restaurant Name and use the Fx (Format by field value) button to visually highlight the fastest and slowest restaurants.

[Insert Power BI screenshot: screenshots/Q16.png]

Observation:

The matrix highlights different leaders for the two measures. Papa John's is fastest on average delivery duration at 28.19 minutes, while Little Caesars has the lowest average delay at 16.62 minutes. Domino's has the longest average duration (30.26), and Marco's Pizza has the highest average delay (18.44).

## Q17

How does order volume vary by Order Hour, alongside average Delay (min)?

[Insert Power BI screenshot: screenshots/Q17.png]

Observation:

The alternative combo styling shows that demand reaches its maximum at 19:00 (328 orders), while average delay reaches its maximum one hour later at 20:00 (19.97 minutes). This separation is easier to see when the delay line is emphasized on its own axis. The 21:00 value is based on only three orders.

## Q18

How does average Topping Density vary by Pizza Type, alongside order volume?

[Insert Power BI screenshot: screenshots/Q18.png]

Observation:

Cheese Burst has the highest average topping density at 0.845 while still recording 188 orders. Non-Veg has the greatest volume at 216 with density 0.760, whereas Gluten-Free is lower at 0.582. The supplied metric is toppings per kilometre, which limits a pizza-only interpretation.

## Q19

What is the percentage breakdown of orders by Traffic Level within each Payment methods, filterable by order time?

[Insert Power BI screenshot: screenshots/Q19.png]

Observation:

The percentage matrix compares Traffic Level composition within each Payment Method while retaining the Between-style Order Time slicer context. Card is 44.57% High traffic; Cash and UPI are mainly Medium traffic at 48.02% and 47.60%; Wallet is mainly Low traffic at 44.71%. Every payment-method row totals 100%, while small groups such as Hut Points (24 orders) and Domino's Cash (23) should be interpreted cautiously.

## Q20

Design three different charts or tables that use conditional formatting (or highlight them by using different colors) in a single dashboard. Explain why each one matters, what it represents, how they should be read together, and what insights emerge from viewing them as a whole.

[Insert Power BI screenshot: screenshots/Q20.png]

Observation:

Three coordinated views align restaurant comparison, delivery conditions, and demand timing. The Restaurant Performance matrix highlights the two averages by restaurant, the traffic columns compare average delay across Low, Medium, and High conditions, and the hourly line traces order volume.

Papa John's records the shortest average delivery duration at 28.19 minutes, whereas Marco's Pizza records the highest average delay at 18.44 minutes. High traffic reaches 19.16 minutes of average delay, and the hourly curve reaches 328 orders at 19:00. Read together, the views locate operational pressure without implying a causal relationship.

