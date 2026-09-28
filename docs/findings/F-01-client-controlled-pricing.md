# F-01 — The client sets the price

| | |
|---|---|
| **Severity** | Critical |
| **Category** | Security / trust boundary |
| **Confidence** | Confirmed by execution |
| **Location** | `src/main/java/com/pizzaco/order/infrastructure/web/OrderRequestDTO.java:22`, `PizzaWebController.java:94` |

## What happens

`POST /orders` accepts `priceAtPurchase` **from the request body** and uses it verbatim as
the price of the pizza. The server never consults a menu, a price list, or any catalogue —
there isn't one in the codebase. Whatever the caller says a pizza costs is what the caller
is charged.

```java
// OrderRequestDTO.java:19-25
public record ItemDTO(
        @NotBlank String size,
        @NotBlank String crustType,
        @NotNull @Positive BigDecimal priceAtPurchase,   // <-- caller-supplied
        @Positive int quantity,
        @NotNull List<@Valid ToppingDTO> toppings) {}
```

```java
// PizzaWebController.java:94
new Money(item.priceAtPurchase()),
```

The only constraint is `@Positive`, which `0.01` satisfies.

## Evidence

Driving `PlaceOrderService` directly with a Large pizza priced at `0.01`, one mile away:

```
[CHAR] client-priced: 5.01
```

`5.01` = the caller's `0.01` pizza plus the `5.00` delivery fee. The order is accepted,
"paid", confirmed, and persisted.

## Why it matters

This is the classic trust-boundary failure. `PizzaSize` and `CrustType` are free-text
strings, so there is nothing server-side that could even derive a correct price. Every
other control in the system — the aggregate's invariants, the validation service, the
payment step — operates faithfully on a number the attacker chose.

Note this is not merely theoretical for a demo: the showcase is explicitly about putting
business rules in the domain, and the single most important business rule (what a pizza
costs) lives in the client.

## Suggested fix

Introduce a menu/catalogue the server owns, and price line items from it:

1. Make `PizzaSize` and `CrustType` enums (see [F-17](F-17-inconsistent-value-object-rigour.md)).
2. Add a `PriceList` / `MenuPort` the domain consults to resolve `(size, crust, toppings)`
   to a `Money`.
3. Remove `priceAtPurchase` from `ItemDTO` entirely. Keep it as a field *on the persisted
   aggregate* — recording the price at the time of purchase is correct; accepting it from
   the customer is not.

## Related

- [F-02 — Toppings are never charged](F-02-toppings-never-charged.md)
- [F-10 — No test asserts a computed total](F-10-no-test-asserts-a-total.md)
- [F-17 — Inconsistent value-object rigour](F-17-inconsistent-value-object-rigour.md)
