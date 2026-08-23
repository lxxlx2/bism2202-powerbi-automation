# BISM2202 Power BI Assessment - Version A

Student Name: __________

Student ID: __________

## Q1

What is the top 20 locations based on count of order number?

[Insert Power BI screenshot: screenshots/Q01.png]

Observation:

Atlanta, GA ranked first with 78 orders, followed by Milwaukee, WI with 71 and Louisville, KY with 69. The horizontal ranking makes the difference between the leading locations easy to compare.

## Q2

What is the average Delivery Duration (min) by Pizza Size?

[Insert Power BI screenshot: screenshots/Q02.png]

Observation:

Large pizzas had the longest average delivery duration at 34.17 minutes, while Small pizzas had the shortest at 21.86 minutes. XL pizzas were close to Large pizzas at 33.08 minutes.

## Q3

What is the share of orders by Pizza Size?

[Insert Power BI screenshot: screenshots/Q03.png]

Observation:

Medium pizzas accounted for the largest share, with 429 orders (42.73%). Small pizzas had the smallest share, with 132 orders (13.15%).

## Q4

How many orders were placed with each Payment Method?

[Insert Power BI screenshot: screenshots/Q04.png]

Observation:

Card was the most common payment method with 276 orders, only five more than UPI at 271. Hut Points and Domino's Cash were much less common, at 24 and 23 orders respectively.

## Q5

What is the share of orders by Traffic Level?

[Insert Power BI screenshot: screenshots/Q05.png]

Observation:

Medium traffic represented the largest share of orders at 39.64% (398 orders). High traffic accounted for 32.67%, while Low traffic represented 27.69%.

## Q6

What is the average Toppings Count for weekend vs. weekday orders?

[Insert Power BI screenshot: screenshots/Q06.png]

Observation:

Weekday orders averaged 3.40 toppings, compared with 3.27 on weekends. The difference was small, at about 0.13 toppings per order.

## Q7

Which locations have the highest average Delivery Duration (min)?

[Insert Power BI screenshot: screenshots/Q07.png]

Observation:

Fort Wayne, IN and Newark, NJ had the highest average delivery duration at 50.00 minutes. Laredo, Lexington, Minneapolis, and Orlando followed at 45.00 minutes, so several locations shared the next-highest result.

## Q8

How many orders were placed during peak hours vs. non-peak?

[Insert Power BI screenshot: screenshots/Q08.png]

Observation:

Peak hours contained 949 orders (94.52%), compared with only 55 non-peak orders (5.48%). Most observations in this dataset therefore fall in the peak-hour category.

## Q9

How does order volume trend across Order Month?

[Insert Power BI screenshot: screenshots/Q09.png]

Observation:

Order volume was highest in August with 117 orders, followed by September with 105. July was the lowest month with 49 orders. These totals combine the same month across all source years, as requested by the Order Month wording.

## Q10

What is the average Toppings Count by Pizza Size?

[Insert Power BI screenshot: screenshots/Q10.png]

Observation:

XL pizzas had the highest average toppings count at 4.99, followed by Large pizzas at 3.97. Small pizzas had the lowest average at 1.69 toppings.

## Q11

Which 2 restaurants have the lowest average Delay (min) i.e., the fastest, most reliable performers?

[Insert Power BI screenshot: screenshots/Q11.png]

Observation:

Little Caesars recorded the lowest average delay at 16.62 minutes. Domino's was second at 17.02 minutes, so these are the two lowest-delay restaurants under the assignment definition.

## Q12

Which 5 Pizza Types have the highest average Delivery Duration (min)?

[Insert Power BI screenshot: screenshots/Q12.png]

Observation:

Stuffed Crust had the highest average delivery duration at 39.52 minutes. Gluten-Free (32.44), Cheese Burst (32.26), Thai Chicken (31.67), and Sicilian (30.86) completed the top five.

## Q13

How does order volume vary by Order Hour across a typical day?

[Insert Power BI screenshot: screenshots/Q13.png]

Observation:

The largest hourly order volume occurred at 19:00 with 328 orders. The nearby 18:00 and 20:00 periods were also busy, with 312 and 306 orders, while the remaining observed hours were much quieter.

## Q14

What is the average delay (min) by Traffic Level?

[Insert Power BI screenshot: screenshots/Q14.png]

Observation:

Average delay increased across the traffic categories: 15.46 minutes for Low, 17.86 for Medium, and 19.16 for High traffic. The pattern shows an association between heavier traffic and longer delay in this dataset.

## Q15

What proportion of orders fall into each Pizza Complexity category?

[Insert Power BI screenshot: screenshots/Q15.png]

Observation:

Pizza Complexity 6 was the largest category, with 308 orders (30.68%). Complexity 12 represented 22.81% and Complexity 20 represented 20.12%, while categories 3 and 15 each contained only two orders.

## Q16

Build a table of average Delivery Duration and Delay by Restaurant Name and use the Fx (Format by field value) button to visually highlight the fastest and slowest restaurants.

[Insert Power BI screenshot: screenshots/Q16.png]

Observation:

The conditional formatting identifies Papa John's as the fastest restaurant by average delivery duration at 28.19 minutes, while Domino's was slowest at 30.26 minutes. Little Caesars had the lowest average delay at 16.62 minutes, whereas Marco's Pizza had the highest at 18.44 minutes. The fastest delivery-duration restaurant is therefore not the same as the lowest-delay restaurant.

## Q17

How does order volume vary by Order Hour, alongside average Delay (min)?

[Insert Power BI screenshot: screenshots/Q17.png]

Observation:

Order volume peaked at 19:00 with 328 orders, but the highest average delay occurred at 20:00 at 19.97 minutes. The volume and delay peaks did not fully coincide. The 21:00 delay was also high at 19.75 minutes, but that hour contained only three orders and should be read cautiously.

## Q18

How does average Topping Density vary by Pizza Type, alongside order volume?

[Insert Power BI screenshot: screenshots/Q18.png]

Observation:

Non-Veg had the largest order volume at 216 and an average topping density of 0.760. Cheese Burst combined high volume (188 orders) with the highest average density, 0.845. The supplied density field equals toppings per kilometre, so it should not be interpreted as a pure pizza-size measure.

## Q19

What is the percentage breakdown of orders by Traffic Level within each Payment methods, filterable by order time?

[Insert Power BI screenshot: screenshots/Q19.png]

Observation:

Traffic composition differed by payment method. High traffic made up 44.57% of Card orders, Medium traffic was largest for Cash (48.02%) and UPI (47.60%), and Low traffic was largest for Wallet (44.71%). Hut Points was 95.83% High traffic, but it contained only 24 orders, so its percentage is based on a small group.

## Q20

Design three different charts or tables that use conditional formatting (or highlight them by using different colors) in a single dashboard. Explain why each one matters, what it represents, how they should be read together, and what insights emerge from viewing them as a whole.

[Insert Power BI screenshot: screenshots/Q20.png]

Observation:

The restaurant matrix compares average delivery duration and average delay by restaurant and uses conditional color highlighting to make the strongest and weakest values easy to identify. The traffic-level column chart compares average delay across Low, Medium, and High traffic, while the hourly line chart shows when order demand is concentrated during the day. Together, the three views connect restaurant performance, delivery conditions, and time-of-day demand.

Papa John's had the shortest average delivery duration at 28.19 minutes, while Marco's Pizza had the highest average delay at 18.44 minutes. High traffic recorded the highest average delay at 19.16 minutes. Order volume reached its maximum at 19:00 with 328 orders, with 18:00 and 20:00 also busy at 312 and 306 orders. These results highlight where operational attention may be most useful while keeping the interpretation descriptive rather than causal.

