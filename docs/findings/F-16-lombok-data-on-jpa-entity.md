# F-16 — Lombok `@Data` on a JPA entity

| | |
|---|---|
| **Severity** | Low |
| **Category** | Persistence design |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/infrastructure/persistence/OrderEntity.java:15` |

## What happens

```java
@Data
@Entity
@Table(name = "orders")
public class OrderEntity { ... }
```

`@Data` generates `equals`, `hashCode` and `toString` across **all** fields, including the
`@Lob` `itemsJson`.

## Why it matters

This is a well-known JPA anti-pattern, for three reasons:

1. **`hashCode` over mutable fields.** An entity's hash changes when any field is set. An
   entity placed in a `HashSet` before flush becomes unfindable afterwards.
2. **`equals`/`hashCode` touch the `@Lob`.** Any equality check or hash forces the full CLOB
   into the comparison — and, with lazy loading, can trigger loading it.
3. **`toString` dumps the entire order payload.** Logging an entity writes the customer's
   address, contact details and full item JSON into the log.

None of these fire today because `OrderEntity` is short-lived — created in `toEntity`, handed
to `save`, discarded — and is never put in a collection or logged. It is a latent trap rather
than a live bug.

## Suggested fix

Replace `@Data` with `@Getter` and `@Setter`, and either omit `equals`/`hashCode` entirely
(letting identity semantics apply) or implement them over the `@Id` alone. Exclude
`itemsJson` from `toString`.

Note `@AllArgsConstructor` is load-bearing here — `OrderRepository.toEntity` calls the
eleven-argument constructor positionally, which is itself fragile: adding a field or
reordering two same-typed fields (`deliveryAddress` and `customerContact` are both `String`)
compiles fine and corrupts data silently. A builder would be safer.

## Related

- [F-15 — Line items are stored as an opaque JSON blob](F-15-opaque-json-line-items.md)
