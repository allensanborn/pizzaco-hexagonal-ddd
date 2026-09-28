# F-12 — The aggregate is constructed three times to place one order

| | |
|---|---|
| **Severity** | Low |
| **Category** | Design / domain modelling |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/core/application/service/PlaceOrderService.java:56-87` |

## What happens

`PlaceOrderService.placeOrder` builds `PizzaOrder` three times before saving it once:

1. **`PizzaOrder.submitted(...)`** — a throwaway "pricing draft", created with
   `Money.ZERO` as the delivery fee and the subtotal standing in as the total. It exists
   only so `DeliveryFeeCalculator` has a `PizzaOrder` to read the item list from.
2. **`PizzaOrder.rehydrate(...)`** — a second draft carrying the real fee and total,
   assembled field-by-field from the first draft's getters.
3. **`.confirm(paymentReference)`** — finally, the guarded transition to `Confirmed`.

## Why it matters

The middle step is the problem. `rehydrate` is a **persistence-reconstitution factory** —
its job is rebuilding an aggregate from a database row, which is why it accepts every field
including a caller-supplied status. Here it is used as a general-purpose domain mutator,
which means the use case can construct an aggregate in any state it likes, bypassing the
transition guards the aggregate exists to enforce.

That undermines the repo's own central claim. `PizzaOrder` is carefully immutable with
`requireCurrentStatus` on every transition, and then the primary use case reaches around
that design using the reconstitution door.

The first step is a smaller symptom of the same root cause, traced in
[F-05](F-05-free-delivery-counts-line-items.md): `calculateFee` takes a whole `PizzaOrder`
when it uses nothing but `order.getItems()`.

## Suggested fix

Change the fee rule's signature so the throwaway draft is unnecessary:

```java
public Money calculateFee(List<PizzaLineItem> items, double distanceInMiles)
```

Then the use case becomes: compute subtotal, compute fee, compute total, construct the
aggregate **once** via `submitted(...)`, then `confirm(...)`. Two constructions become one,
and `rehydrate` returns to being used only by `OrderRepository`, where it belongs.

Consider narrowing `rehydrate`'s visibility so the application layer cannot reach it.

## Related

- [F-05 — The free-delivery rule counts line items](F-05-free-delivery-counts-line-items.md)
- [F-14 — Order placement reads the order back it just created](F-14-redundant-read.md)
