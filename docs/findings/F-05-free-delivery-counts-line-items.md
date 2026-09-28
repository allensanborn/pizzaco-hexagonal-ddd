# F-05 — The free-delivery rule counts line items, not pizzas

| | |
|---|---|
| **Severity** | High |
| **Category** | Correctness / business rule |
| **Confidence** | Confirmed by execution |
| **Location** | `src/main/java/com/pizzaco/order/core/domain/service/DeliveryFeeCalculator.java:14-19` |

## What happens

This is the only real business rule in the codebase, and it is wrong:

```java
// DeliveryFeeCalculator.java:13-20
public Money calculateFee(PizzaOrder order, double distanceInMiles) {
    // Rule: "Free delivery if you order 3 pizzas AND live within 5 miles"
    if (order.getItems().size() >= FAMILY_DISCOUNT_THRESHOLD
            && distanceInMiles <= FREE_DELIVERY_RADIUS_MILES) {
        return Money.ZERO;
    }
    return STANDARD_FEE;
}
```

`order.getItems().size()` counts **line items**, not pizzas. `PizzaLineItem.quantity` is
ignored — the comment directly above the bug says "3 pizzas".

## Evidence

Three identical pizzas at `10.00`, one mile away, expressed two ways:

```
[CHAR] qty3-one-line:    35.00   # one line item, quantity 3  -> pays 5.00 delivery
[CHAR] qty1-three-lines: 30.00   # three line items, qty 1    -> free delivery
```

Same three pizzas, same address, same distance. The customer pays **£5 more** for sending
their order as one line item instead of three. The outcome depends entirely on the shape of
the JSON, which no customer-facing UI would expose as a choice — but an API client can.

## Why it matters

It is exploitable in one direction (split your order into lines, ride free) and
overcharges in the other (order ten pizzas on one line, pay delivery). For a repository
whose stated purpose is demonstrating that business rules belong in the domain, the single
domain rule on display miscounts its own unit.

## Suggested fix

```java
int pizzaCount = order.getItems().stream()
        .mapToInt(PizzaLineItem::quantity)
        .sum();
```

While fixing it, take the parameter the rule actually needs. `calculateFee` uses nothing
from `PizzaOrder` except the item list, and accepting `List<PizzaLineItem>` removes the
reason the throwaway aggregate draft exists — see
[F-12](F-12-aggregate-constructed-three-times.md).

## Related

- [F-10 — No test asserts a computed total](F-10-no-test-asserts-a-total.md)
- [F-12 — The aggregate is constructed three times](F-12-aggregate-constructed-three-times.md)
