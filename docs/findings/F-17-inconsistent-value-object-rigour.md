# F-17 — Value-object rigour is applied inconsistently

| | |
|---|---|
| **Severity** | Low |
| **Category** | Domain modelling |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/core/domain/model/` |

## What happens

The domain model is mostly exemplary — `Money` enforces non-negativity and scale,
`EtaMinutes` rejects non-positive values, `OrderId`, `CustomerContact`, `DeliveryAddress`
and `PaymentReference` all validate in compact constructors, and `OrderStatus` is a proper
enum.

Two closed sets are modelled as open strings:

```java
public record PizzaSize(String value) { ... }   // "Large", "large", "banana"
public record CrustType(String value) { ... }   // "Thin", "THIN", ""
```

Both reject only null and blank. `"banana"` is a valid pizza size.

## Why it matters

Size and crust are exactly as closed a set as `OrderStatus`, which *is* an enum — so the
inconsistency is internal to the model rather than a matter of taste. The consequences:

- No server-side validation that a requested pizza actually exists.
- Case-sensitivity is unmanaged: `"Large"` and `"large"` are different pizzas to this system,
  and both are stored verbatim in the item JSON.
- It is a precondition for [F-01](F-01-client-controlled-pricing.md). A price list can only
  be keyed off a closed set; with free-text sizes there is nothing the server could look a
  price up *by*, which is part of why the price is taken from the client instead.

Two smaller observations in the same area:

- `Money` rejects negative values but permits zero, so a free pizza is representable. That is
  probably intentional for toppings; worth stating.
- `Topping.extraCost` is validated and stored but never used in any calculation — see
  [F-02](F-02-toppings-never-charged.md).

## Suggested fix

Make `PizzaSize` and `CrustType` enums, matching `OrderStatus`. The DTO layer already
converts strings to domain types in `PizzaWebController.toDomainItems`, so the translation
point exists; an unknown value becomes an `IllegalArgumentException`, which
`GlobalExceptionHandler` already maps to `400`.

This is the enabling change for fixing [F-01](F-01-client-controlled-pricing.md).

## Related

- [F-01 — The client sets the price](F-01-client-controlled-pricing.md)
- [F-02 — Toppings are never charged](F-02-toppings-never-charged.md)
