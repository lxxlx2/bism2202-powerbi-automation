# DAX Measures and Calculated Columns

Use the table name `PizzaOrders`. Before writing DAX, Power Query must replace the three occurrences of `Marco’s Pizza` with `Marco's Pizza` in `Restaurant Name`.

## Measures

```DAX
Order Count =
DISTINCTCOUNT(PizzaOrders[Order ID])

Avg Delivery Duration =
AVERAGE(PizzaOrders[Delivery Duration (min)])

Avg Toppings Count =
AVERAGE(PizzaOrders[Toppings Count])

Avg Delay =
AVERAGE(PizzaOrders[Delay (min)])

Avg Topping Density =
AVERAGE(PizzaOrders[Topping Density])

Order Share % =
DIVIDE(
    [Order Count],
    CALCULATE([Order Count], ALLSELECTED(PizzaOrders))
)

Traffic % Within Payment Method =
DIVIDE(
    [Order Count],
    CALCULATE(
        [Order Count],
        REMOVEFILTERS(PizzaOrders[Traffic Level])
    )
)

Delay Rank Asc =
RANKX(
    ALL(PizzaOrders[Restaurant Name]),
    [Avg Delay],
    ,
    ASC,
    DENSE
)
```

## Calculated columns

```DAX
Order Month-Year =
FORMAT(PizzaOrders[Order Time], "yyyy-MM")

Peak Hour Label =
IF(PizzaOrders[Is Peak Hour] = TRUE(), "Peak Hour", "Non-Peak Hour")

Weekend Label =
IF(PizzaOrders[Is Weekend] = TRUE(), "Weekend", "Weekday")
```

Because the label uses ISO `yyyy-MM`, sorting `Order Month-Year` ascending is also chronological. Do not use the source `Order Month` name alone, because that would combine the same month across different years.

## Version A field-value colors for Q16

```DAX
Delivery Duration Color A =
VAR CurrentValue = [Avg Delivery Duration]
VAR MinValue = MINX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delivery Duration]))
VAR MaxValue = MAXX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delivery Duration]))
RETURN SWITCH(TRUE(), CurrentValue = MinValue, "#C6EFCE", CurrentValue = MaxValue, "#FFC7CE", "#FFF2CC")

Delay Color A =
VAR CurrentValue = [Avg Delay]
VAR MinValue = MINX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delay]))
VAR MaxValue = MAXX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delay]))
RETURN SWITCH(TRUE(), CurrentValue = MinValue, "#C6EFCE", CurrentValue = MaxValue, "#FFC7CE", "#FFF2CC")
```

## Version B field-value colors for Q16

```DAX
Delivery Duration Color B =
VAR CurrentValue = [Avg Delivery Duration]
VAR MinValue = MINX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delivery Duration]))
VAR MaxValue = MAXX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delivery Duration]))
RETURN SWITCH(TRUE(), CurrentValue = MinValue, "#BFE3E0", CurrentValue = MaxValue, "#F4A261", "#E9EEF3")

Delay Color B =
VAR CurrentValue = [Avg Delay]
VAR MinValue = MINX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delay]))
VAR MaxValue = MAXX(ALL(PizzaOrders[Restaurant Name]), CALCULATE([Avg Delay]))
RETURN SWITCH(TRUE(), CurrentValue = MinValue, "#CDE8F6", CurrentValue = MaxValue, "#E76F51", "#EEF1F4")
```

## Expected global checks

- `[Order Count]` with no filter = 1,004.
- `[Avg Delivery Duration]` with no filter = 29.4920318725 minutes.
- `[Avg Delay]` with no filter = 17.6225498008 minutes.
- `Traffic % Within Payment Method` must sum to 100% inside every Payment Method and must respond to the Order Time slicer.
