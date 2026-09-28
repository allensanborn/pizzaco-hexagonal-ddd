# F-07 — No idempotency on order placement

| | |
|---|---|
| **Severity** | Medium |
| **Category** | Correctness / resilience |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/infrastructure/web/PizzaWebController.java:46-61` |

## What happens

`POST /orders` accepts no idempotency key, and the server generates the order id itself
inside `PizzaOrder.submitted(...)`. Two identical requests produce two orders and two
charges.

There is no deduplication window, no client-supplied request id, and no natural key to
detect a repeat — `customerId` plus item list plus timestamp would collide legitimately for
a customer ordering the same thing twice.

## Why it matters

The failure mode is the ordinary one: a client times out, retries, and is charged twice.
This is made materially more likely by [F-03](F-03-payment-outside-transaction.md), where a
persistence failure *after* a successful charge produces exactly the 500 that prompts a
client retry — and that retry charges again.

It is also the normal reason a payment integration requires an idempotency key, which
`PaymentProcessor.processPayment(String customerId, Money amount)` has no parameter for.
Stripe's real API takes one; the port modelled on it does not.

## Suggested fix

1. Accept an `Idempotency-Key` header on `POST /orders`.
2. Persist it alongside the order with a unique constraint, and return the original order
   on a repeat rather than creating a second one.
3. Pass it through `PaymentProcessor` so the downstream charge is idempotent too — this is
   a port signature change, and is the kind of thing the ports abstraction exists to make
   easy.

## Related

- [F-03 — Payment is taken outside any transaction](F-03-payment-outside-transaction.md)
- [F-08 — No optimistic locking on status transitions](F-08-no-optimistic-locking.md)
