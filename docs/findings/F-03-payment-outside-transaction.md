# F-03 — Payment is taken outside any transaction, before persistence

| | |
|---|---|
| **Severity** | High |
| **Category** | Correctness / data integrity |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/core/application/service/PlaceOrderService.java:79-90` |

## What happens

`PlaceOrderService.placeOrder` charges the customer, **then** saves the order:

```java
// PlaceOrderService.java:79-90
var paymentResult = paymentProcessor.processPayment(command.customerId(), total);
if (!paymentResult.success()) {
    throw new PaymentFailedException(...);
}

PizzaOrder confirmedOrder = submittedOrder.confirm(new PaymentReference(...));
orderStore.save(confirmedOrder);          // <-- can fail after the money is taken

notificationPort.notifyCustomer(...);
```

Nothing in the call chain is `@Transactional` — not the service (it is deliberately
Spring-free), not the controller, not `OrderRepository`. Spring Data's `save` therefore runs
in its own short transaction, and there is no enclosing unit of work.

## Why it matters

If `orderStore.save` throws — constraint violation, connection loss, serialisation failure —
the customer has been charged for an order that does not exist. There is no compensating
action, no retry, and no record to reconcile against, because the payment reference only
ever existed in the local variable that is now unwinding.

The same gap makes the notification unreliable in the other direction: a failure in
`notifyCustomer` propagates out of the use case *after* the order is persisted, so the caller
sees a 500 for an order that was successfully placed and paid for.

This is currently masked because `StripePaymentAdapter` cannot fail and H2 in-memory rarely
does. It becomes a live money-losing bug the moment either is made real.

## Suggested fix

Two parts, in order of importance:

1. **Persist before charging.** Save the order in `Submitted`, charge, then transition to
   `Confirmed` and save again. A stranded `Submitted` order is recoverable; a stranded
   charge is not.
2. **Introduce an explicit transaction boundary.** Since the core must stay Spring-free,
   either put `@Transactional` on a thin infrastructure facade that delegates to the use
   case, or add a `TransactionPort` the core invokes and the infrastructure implements.
   The latter fits the existing port vocabulary.

Make the notification best-effort — a failure to notify should not fail the order.

## Related

- [F-07 — No idempotency on order placement](F-07-no-idempotency.md)
- [F-11 — The ports seam is built but never exercised](F-11-ports-seam-never-exercised.md)
