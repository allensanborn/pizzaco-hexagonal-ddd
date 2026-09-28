# Code review findings

A review of the Pizzaco Order Service, carried out alongside the C4 diagrams in
[`../architecture/`](../architecture/). One file per issue.

Findings marked **Confirmed by execution** were reproduced by running the code, not inferred
from reading it. The evidence lines quoted in those files came from driving
`PlaceOrderService` directly with a throwaway characterisation test, which was removed
afterwards — the repository's own suite is unchanged and still passes.

## Summary

| # | Finding | Severity | Category | Confidence |
| --- | --- | --- | --- | --- |
| [F-01](F-01-client-controlled-pricing.md) | The client sets the price | **Critical** | Security | Execution |
| [F-02](F-02-toppings-never-charged.md) | Toppings are never charged | **High** | Correctness | Execution |
| [F-03](F-03-payment-outside-transaction.md) | Payment is taken outside any transaction | **High** | Data integrity | Inspection |
| [F-04](F-04-no-authentication.md) | No authentication or authorization anywhere | **High** | Security | Inspection |
| [F-05](F-05-free-delivery-counts-line-items.md) | Free-delivery rule counts line items, not pizzas | **High** | Business rule | Execution |
| [F-06](F-06-cancellation-without-refund.md) | Cancellation takes the money and says nothing | Medium | Correctness | Inspection |
| [F-07](F-07-no-idempotency.md) | No idempotency on order placement | Medium | Resilience | Inspection |
| [F-08](F-08-no-optimistic-locking.md) | Concurrent transitions overwrite each other | Medium | Concurrency | Inspection |
| [F-09](F-09-demo-grade-persistence-config.md) | Demo-grade persistence config, H2 console open | Medium | Security | Inspection |
| [F-10](F-10-no-test-asserts-a-total.md) | No test asserts a computed total | Medium | Test coverage | Execution |
| [F-11](F-11-ports-seam-never-exercised.md) | The ports seam is built but never exercised | Medium | Design | Inspection |
| [F-12](F-12-aggregate-constructed-three-times.md) | The aggregate is constructed three times | Low | Domain modelling | Inspection |
| [F-13](F-13-clockport-bypassed.md) | ClockPort is bypassed inside the domain | Low | Testability | Inspection |
| [F-14](F-14-redundant-read.md) | Placement discards its result and re-reads | Low | Efficiency | Inspection |
| [F-15](F-15-opaque-json-line-items.md) | Line items stored as an opaque JSON blob | Low | Persistence | Inspection |
| [F-16](F-16-lombok-data-on-jpa-entity.md) | Lombok `@Data` on a JPA entity | Low | Persistence | Inspection |
| [F-17](F-17-inconsistent-value-object-rigour.md) | Value-object rigour applied inconsistently | Low | Domain modelling | Inspection |

## The headline

**Three independent pricing defects coexist with a green build.** F-01, F-02 and F-05 are all
live, and `./gradlew test` passes, because of F-10: no test in the repository asserts a money
value the system computed. Measured directly:

| Scenario | Actual | Expected |
| --- | --- | --- |
| 10.00 pizza + 2.50 topping + 5.00 delivery | `15.00` | `17.50` |
| 3 pizzas as one line item (qty 3), 1 mile | `35.00` | `30.00` |
| 3 pizzas as three line items, 1 mile | `30.00` | `30.00` |
| Client declares the pizza costs 0.01 | `5.01` | rejected |

The middle two are the same three pizzas to the same address, £5 apart purely on the shape of
the JSON.

## What the repository gets right

This is worth stating plainly, because the list above is one-sided and the architecture is
genuinely good:

- **The hexagon is real and enforced.** `core` has no Spring annotations and no imports from
  `infrastructure`, and `HexagonalArchitectureTest` fails the build if that changes. Most
  repositories claiming this do not check it.
- **`CoreWiringConfig` is a true composition root.** The framework touches the core in exactly
  one file.
- **`PizzaOrder` is a properly immutable aggregate.** Every transition returns a new instance
  and rejects an illegal source state, so the lifecycle invariant lives in the domain rather
  than being scattered across services.
- **The architecture is highly testable, and demonstrably so.** `PlaceOrderServiceTest` wires
  the entire use case with four lambdas and no Spring container. That is exactly the payoff
  hexagonal architecture promises — which makes F-10 the more frustrating: the testability is
  there and is spent on assertions that cannot fail.

The recurring theme across F-01, F-02, F-05, F-10 and F-11 is the same one: **the structure is
sound and the substance inside it is unfinished.** The ports exist but nothing is ever swapped
through them; the domain services exist but the one real rule miscounts; the tests exist but
assert only that the machinery ran.

## Suggested order of work

1. **F-10 first.** Write the failing tests for the pricing bugs before fixing them, so the
   fixes are demonstrably correct and cannot regress.
2. **F-01, F-02, F-05** — the pricing defects, with F-17 as the enabling change for F-01.
3. **F-04, F-09** — close the unauthenticated progress endpoint and the open H2 console.
4. **F-03, F-07, F-08** — the transaction, idempotency and locking gaps, which are one
   coherent piece of work about making writes safe.
5. The rest as cleanup.
