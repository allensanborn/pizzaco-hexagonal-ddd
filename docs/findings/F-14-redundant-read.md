# F-14 — Order placement discards its result and reads the order back

| | |
|---|---|
| **Severity** | Low |
| **Category** | Efficiency |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/java/com/pizzaco/order/infrastructure/web/PizzaWebController.java:47-61` |

## What happens

`PlaceOrderUseCase.placeOrder` returns a `PlaceOrderResult` carrying the order id, status,
total, ETA and payment reference — everything the `201` response needs. The controller
throws it away and fetches the order again:

```java
// PizzaWebController.java:50-60
var result = placeOrderUseCase.placeOrder(...);

var orderView = getOrderUseCase.getOrder(result.orderId());   // second read
return ResponseEntity.status(HttpStatus.CREATED).body(toResponse(orderView));
```

`result` is used for exactly one thing: supplying the id to look itself up.

## Why it matters

A wasted database round trip on the hottest write path. It is also a correctness smell
rather than merely a performance one — the response is assembled from a *re-read* of state
that was just written, so the two can disagree under concurrency, and the endpoint's
behaviour now depends on the read path as well as the write path.

The reason it happens is a shape mismatch: `PlaceOrderResult` and `GetOrderUseCase.OrderView`
carry overlapping but not identical fields (`OrderView` adds `deliveryAddress` and
`placedAt`, which `OrderResponseDTO` needs). The second read papers over that gap.

## Suggested fix

Add `deliveryAddress` and `placedAt` to `PlaceOrderResult` and map the `201` body directly
from it. The extra read then disappears, and the write path stops depending on the read path.

## Related

- [F-08 — Concurrent status transitions overwrite each other](F-08-no-optimistic-locking.md)
- [F-12 — The aggregate is constructed three times](F-12-aggregate-constructed-three-times.md)
