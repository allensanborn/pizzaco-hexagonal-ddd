# F-04 — No authentication or authorization anywhere

| | |
|---|---|
| **Severity** | High |
| **Category** | Security |
| **Confidence** | Confirmed by inspection |
| **Location** | `build.gradle`, `src/main/java/com/pizzaco/order/infrastructure/web/PizzaWebController.java` |

## What happens

There is no Spring Security dependency in `build.gradle`, no security configuration, and no
authentication or authorization check on any endpoint. Every route is open:

| Endpoint | Who can call it today |
| --- | --- |
| `POST /orders` | anyone |
| `GET /orders/{orderId}` | anyone with the UUID |
| `POST /orders/{orderId}/progress` | anyone with the UUID |

`customerId` is a `@NotBlank String` taken from the request body. It is passed to
`PaymentProcessor.processPayment` and otherwise never used — it is not checked against a
caller identity, because there isn't one.

## Why it matters

Three distinct problems, in increasing order of severity:

1. **Order data is readable by UUID.** A UUID is unguessable, so this is weak-but-not-absent
   protection for `GET`. Delivery address and contact details are returned.
2. **Anyone can drive another customer's order lifecycle.** `POST /orders/{orderId}/progress`
   will happily mark a stranger's order `Delivered`, or `Cancelled`. See
   [F-06](F-06-cancellation-without-refund.md).
3. **`customerId` is an unauthenticated assertion.** The caller names the account to charge.
   Combined with [F-01](F-01-client-controlled-pricing.md), a caller chooses both who pays
   and how much.

## Suggested fix

The progress endpoint is the urgent one, and the architecture already points at the answer:
the README says those transitions should come from the kitchen and delivery contexts, not
from a public HTTP route. Until those exist, at minimum:

1. Add `spring-boot-starter-security`.
2. Authenticate the customer and derive `customerId` from the principal rather than the body.
3. Put `POST /orders/{orderId}/progress` behind a separate service-to-service credential,
   or remove it from the public API and drive it from a test fixture.

## Related

- [F-01 — The client sets the price](F-01-client-controlled-pricing.md)
- [F-06 — Cancellation does not refund](F-06-cancellation-without-refund.md)
- [F-09 — Demo-grade persistence configuration](F-09-demo-grade-persistence-config.md)
