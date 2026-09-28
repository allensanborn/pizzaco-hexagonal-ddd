# F-15 — Line items are stored as an opaque JSON blob

| | |
|---|---|
| **Severity** | Low |
| **Category** | Persistence design |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/infrastructure/persistence/OrderEntity.java:49-51`, `OrderRepository.java` |

## What happens

The whole item list is serialised into a single CLOB column:

```java
// OrderEntity.java:49-51
@Lob
@Column(nullable = false, columnDefinition = "CLOB")
private String itemsJson;
```

`OrderRepository` writes it with `objectMapper.writeValueAsString(order.getItems())` and
reads it back through a `TypeReference<List<PizzaLineItem>>`.

## Why it matters

Three consequences, none fatal, all compounding:

1. **Nothing can be queried by order contents.** "How many Large thin-crust pizzas did we
   sell?" is unanswerable in SQL. For an *order* service this is a plausible near-term
   requirement.
2. **The JSON is schema-coupled to the domain record.** `PizzaLineItem` is serialised
   structurally, so renaming a component or changing its shape silently breaks
   deserialisation of every historical row. There is no version marker in the payload and no
   migration path.
3. **`JsonProcessingException` is rethrown as `UncheckedIOException`**, which
   `GlobalExceptionHandler` does not handle — so a deserialisation failure surfaces as a bare
   `500`.

Choosing a blob is a legitimate trade for a showcase, and it does keep the aggregate
boundary clean. The issue is that it is undocumented and unversioned, so the trade looks
accidental rather than chosen.

## Suggested fix

Either commit to the blob and make it safe — add a schema version field, map to an explicit
persistence DTO rather than serialising the domain record directly, and handle
`UncheckedIOException` in the exception handler — or model line items as a child table with
`@OneToMany`, which is what the queryability of an order service will eventually want.

## Related

- [F-09 — Demo-grade persistence configuration](F-09-demo-grade-persistence-config.md)
- [F-16 — Lombok @Data on a JPA entity](F-16-lombok-data-on-jpa-entity.md)
