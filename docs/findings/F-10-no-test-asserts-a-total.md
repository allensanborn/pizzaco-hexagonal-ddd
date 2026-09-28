# F-10 — No test anywhere asserts a computed total

| | |
|---|---|
| **Severity** | Medium |
| **Category** | Test coverage |
| **Confidence** | Confirmed by execution |
| **Location** | `src/test/java/com/pizzaco/order/**` |

## What happens

The suite is green. `./gradlew test` passes. And yet [F-01](F-01-client-controlled-pricing.md),
[F-02](F-02-toppings-never-charged.md) and [F-05](F-05-free-delivery-counts-line-items.md) are
all live pricing defects. This finding is why: **no test in the repository asserts a money
value that the system computed.**

| Test | What it asserts about money |
| --- | --- |
| `PizzaOrderTest` | Nothing — subtotal, fee and total are passed in as literals and never checked. |
| `PlaceOrderServiceTest` | Nothing — asserts `status`, `paymentReference`, and store size. |
| `OrderFlowIntegrationTest` | Nothing — asserts `$.status` only. |
| `HexagonalArchitectureTest` | N/A — package dependency rule. |

Two of those tests *construct toppings with a cost* and then never check the effect:
`PlaceOrderServiceTest` sends a `0.50` Cheese, `OrderFlowIntegrationTest` sends a `1.00`
Pepperoni. Both pass while the cost is discarded.

`DeliveryFeeCalculator` — the only real business rule in the codebase — has **no unit test at
all**, despite being the most testable class in the project: two inputs, no dependencies.

## Why it matters

The tests assert that the *machinery* runs: statuses change, the store is written, a
reference comes back. They never assert that the *arithmetic* is right. That is why three
independent pricing bugs coexist with a passing build, and it is the reason a reader of this
repo could reasonably believe pricing works.

For a repository whose purpose is to demonstrate a testable architecture, this is the most
consequential gap: the architecture *is* highly testable — `PlaceOrderServiceTest` wires the
whole use case with four lambdas and no Spring, which is exactly the payoff hexagonal
promises — and that testability is then spent on assertions that cannot fail.

## Suggested fix

1. Unit-test `DeliveryFeeCalculator` directly: at/over/under the 3-pizza threshold, at/over
   the 5-mile radius, and crucially a single line item with `quantity: 3`.
2. Assert `result.total()` in `PlaceOrderServiceTest` for a known basket.
3. Assert `$.total` in `OrderFlowIntegrationTest` — it already sends a priced topping.

## Related

- [F-01 — The client sets the price](F-01-client-controlled-pricing.md)
- [F-02 — Toppings are never charged](F-02-toppings-never-charged.md)
- [F-05 — The free-delivery rule counts line items](F-05-free-delivery-counts-line-items.md)
