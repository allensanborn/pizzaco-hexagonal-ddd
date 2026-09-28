# F-06 — Cancellation takes the money and says nothing

| | |
|---|---|
| **Severity** | Medium |
| **Category** | Correctness / domain completeness |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/core/domain/model/PizzaOrder.java:136-144`, `core/application/service/ProgressOrderService.java:49` |

## What happens

`POST /orders/{id}/progress` accepts `Cancelled` as a target status:

```java
// ProgressOrderService.java:49
case Cancelled -> order.cancel();
```

and the aggregate allows cancelling from any state except `Delivered`:

```java
// PizzaOrder.java:136-144
public PizzaOrder cancel() {
    if (status == OrderStatus.Delivered) {
        throw new IllegalStateException("Delivered orders cannot be cancelled");
    }
    if (status == OrderStatus.Cancelled) {
        return this;
    }
    return withStatus(OrderStatus.Cancelled);
}
```

An order can therefore be cancelled after it was paid for, after it was baked, and while it
is `OutForDelivery`. Three things do not happen:

1. **No refund.** `PaymentProcessor` has no refund or void operation at all. The
   `paymentReference` is carried on the aggregate and never used again.
2. **No notification.** `ProgressOrderService` notifies on `OutForDelivery` and `Delivered`
   only. A cancelled customer is told nothing.
3. **No downstream signal.** Nothing tells a kitchen to stop baking.

## Why it matters

Cancellation is the one lifecycle transition with a financial consequence, and it is the
one the domain models least. The README's lifecycle diagram
(`Confirmed → Baking → ReadyForDelivery → OutForDelivery → Delivered`) doesn't mention
`Cancelled` at all, yet the enum, the aggregate and the endpoint all support it — so it
reads as an afterthought that was never finished.

Combined with [F-04](F-04-no-authentication.md), any unauthenticated caller who learns an
order UUID can cancel a paid, in-flight order.

## Suggested fix

Decide whether cancellation is in scope. If it is:

1. Add a `refund(PaymentReference, Money)` operation to `PaymentProcessor`.
2. Restrict which states may be cancelled — `OutForDelivery` almost certainly should not be.
3. Notify on cancellation, and emit whatever the kitchen needs to stop work.

If it is not in scope, remove `Cancelled` from `OrderStatus` and from the progress endpoint
rather than leaving a partial implementation that looks supported.

## Related

- [F-03 — Payment is taken outside any transaction](F-03-payment-outside-transaction.md)
- [F-04 — No authentication or authorization](F-04-no-authentication.md)
