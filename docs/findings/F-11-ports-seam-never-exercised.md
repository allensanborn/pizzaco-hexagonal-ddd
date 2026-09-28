# F-11 — The ports seam is built but never exercised

| | |
|---|---|
| **Severity** | Medium |
| **Category** | Design / showcase value |
| **Confidence** | Confirmed by inspection |
| **Location** | repository-wide |

## What happens

Hexagonal architecture earns its indirection when adapters can be **swapped** — a fake
payment adapter in development, the real one in production. That swap is normally expressed
with `@Profile`, `@ConditionalOnProperty`, or alternative bean definitions.

This repository does none of it:

- no `@Profile`, `@ConditionalOnProperty`, `@Primary` or `@Qualifier` anywhere in `src/`
- exactly **one** implementation of each outbound port in `src/main`
- no `Dockerfile`, no compose file, no Kubernetes manifests, no second Spring profile

So `StripePaymentAdapter`, `GoogleMapsEtaAdapter` and `FirebaseNotificationAdapter` are not
development stand-ins that a profile replaces. They are the *only* implementations, selected
by component scan at compile time. Each logs a line and returns a hardcoded value:

| Adapter | Behaviour |
| --- | --- |
| `StripePaymentAdapter` | always succeeds, random reference, no HTTP call |
| `GoogleMapsEtaAdapter` | always returns 30 minutes, ignores both addresses |
| `FirebaseNotificationAdapter` | returns a random message id, nothing is delivered |

## Why it matters

The repo demonstrates the *structure* of ports and adapters without ever demonstrating the
*benefit*. A reader sees five ports and five adapters and no reason why the indirection
paid for itself, because nothing is ever substituted at the boundary it creates.

There is a second-order consequence. Because `StripePaymentAdapter` cannot fail,
`PaymentFailedException` and its `402` handler in `GlobalExceptionHandler` are unreachable in
a running system — they exist only for `PlaceOrderServiceTest`. The failure path is modelled
but dead.

It is worth being precise about what this is *not*: it is not a deployment concern. Ports
and adapters are a source-structure (C4 Level 3) property that lives inside one container.
It only becomes visible at deployment once a profile actually selects between adapters — and
that is exactly the step that is missing.

## Suggested fix

The smallest change that makes the point the repo is trying to make:

1. Rename the current adapters to what they are — `SimulatedPaymentAdapter`, etc. — and
   annotate them `@Profile("local")`.
2. Add a second implementation behind `@Profile("prod")`, even an unimplemented one that
   throws, so the seam has two sides.
3. Add a test that runs the use case against both.

Step 1 alone removes the most misleading thing about the repository: three classes named
after real SaaS products that never contact them.

## Related

- [F-09 — Demo-grade persistence configuration](F-09-demo-grade-persistence-config.md)
- [F-13 — ClockPort is bypassed inside the domain](F-13-clockport-bypassed.md)
