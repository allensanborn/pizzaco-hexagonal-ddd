# F-13 — ClockPort is bypassed inside the domain

| | |
|---|---|
| **Severity** | Low |
| **Category** | Design / testability |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/core/domain/service/OrderPricingService.java:28-30` |

## What happens

The project models time as an output port — `ClockPort`, implemented as an `Instant::now`
lambda in `CoreWiringConfig`, so the core never reads the system clock. `PlaceOrderService`
uses it correctly, and `PlaceOrderServiceTest` supplies a fixed clock.

Then `OrderPricingService` reads the clock directly:

```java
// OrderPricingService.java:28-30
public Instant now() {
    return Instant.now();
}
```

This method is **unused** — nothing calls it — but it sits in a domain service, which is
precisely where a non-deterministic system call should never be.

## Why it matters

Low impact today because it is dead code. It matters as a trap: the next person who needs a
timestamp in the pricing path will find `pricingService.now()` sitting there looking
sanctioned, and will use it instead of `ClockPort`. At that point the pricing logic becomes
untestable at a fixed instant, and the port stops being an enforced boundary.

Note that the ArchUnit rule cannot catch this — it checks that `core` does not depend on
`infrastructure` or Spring, and `java.time.Instant` is neither.

## Suggested fix

Delete the method. If pricing ever genuinely needs the time, inject `ClockPort` into
`OrderPricingService` the same way `PlaceOrderService` receives it.

Consider extending `HexagonalArchitectureTest` to forbid `Instant.now()`, `LocalDate.now()`
and `System.currentTimeMillis()` inside `..core..` — the rule is easy to express in ArchUnit
and would make the port self-enforcing.

## Related

- [F-11 — The ports seam is built but never exercised](F-11-ports-seam-never-exercised.md)
