# F-08 — Concurrent status transitions silently overwrite each other

| | |
|---|---|
| **Severity** | Medium |
| **Category** | Correctness / concurrency |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/infrastructure/persistence/OrderEntity.java`, `core/application/service/ProgressOrderService.java:33-42` |

## What happens

`OrderEntity` has no `@Version` field, and `ProgressOrderService` performs a read-modify-write
with no locking:

```java
// ProgressOrderService.java:33-42
var current = orderStore.findById(command.orderId()).orElseThrow(...);
var progressed = transition(current, command.targetStatus());
orderStore.save(progressed);
```

Between the `findById` and the `save`, another request can transition the same order. The
second `save` wins and the first transition is lost — including its side effects, which have
already fired.

## Why it matters

The aggregate's guarded transitions are the centrepiece of this repo: `requireCurrentStatus`
makes an illegal transition impossible *in memory*. That guarantee does not survive
concurrency, because two threads can each load `Confirmed`, each legally transition, and each
save. The invariant the domain enforces so carefully is enforced against a stale snapshot.

A concrete interleaving:

1. Request A loads the order in `Baking`.
2. Request B loads the same order in `Baking`.
3. A transitions to `ReadyForDelivery` and saves.
4. B transitions to `ReadyForDelivery` and saves — no error, and a second
   "ready for delivery" is now the persisted truth.

With `OutForDelivery` and `Delivered` this also sends the customer duplicate notifications.

## Suggested fix

Add optimistic locking:

```java
@Version
private Long version;
```

and let `OptimisticLockException` surface as a `409 Conflict` through
`GlobalExceptionHandler`. This is cheap, and it restores the aggregate invariant across
concurrent writers, which is the whole point of having modelled it.

## Related

- [F-03 — Payment is taken outside any transaction](F-03-payment-outside-transaction.md)
- [F-07 — No idempotency on order placement](F-07-no-idempotency.md)
