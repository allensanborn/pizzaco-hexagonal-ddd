# F-02 — Toppings are never charged

| | |
|---|---|
| **Severity** | High |
| **Category** | Correctness / revenue |
| **Confidence** | Confirmed by execution |
| **Location** | `src/main/java/com/pizzaco/order/core/domain/model/PizzaLineItem.java:23-25` |

## What happens

`Topping` carries an `extraCost`. The API accepts it, validates it (`@DecimalMin("0.0")`),
the domain stores it, and the repository serialises it to the database. It is never added
to any total.

```java
// PizzaLineItem.java:23-25
public Money lineTotal() {
    return priceAtPurchase.multiply(quantity);   // toppings ignored
}
```

`toppings` is a constructor parameter that is defensively copied (line 20) and then read by
nothing except serialisation.

## Evidence

One pizza at `10.00` with a `2.50` topping, one mile away (so a `5.00` delivery fee):

```
[CHAR] toppings: 15.00
```

Expected `17.50`. The `2.50` topping is silently dropped.

The repo's own examples exercise this bug and don't notice: the README's `curl` sends a
`1.00` Mushroom, and `OrderFlowIntegrationTest` sends a `1.00` Pepperoni. Neither asserts a
total — see [F-10](F-10-no-test-asserts-a-total.md).

## Why it matters

Every order containing toppings undercharges by the sum of its topping costs. Because the
value is accepted, stored and returned, the data looks correct at rest — an audit of the
persisted orders would show toppings with costs attached and totals that silently disagree
with them.

## Suggested fix

```java
public Money lineTotal() {
    Money perPizza = toppings.stream()
            .map(Topping::extraCost)
            .reduce(priceAtPurchase, Money::add);
    return perPizza.multiply(quantity);
}
```

Add a test that asserts a computed total for an order with toppings. Note this interacts
with [F-01](F-01-client-controlled-pricing.md): while the client supplies both the pizza
price and the topping cost, fixing the arithmetic only makes the wrong number bigger.

## Related

- [F-01 — The client sets the price](F-01-client-controlled-pricing.md)
- [F-10 — No test asserts a computed total](F-10-no-test-asserts-a-total.md)
