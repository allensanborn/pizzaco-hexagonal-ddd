# Pizzaco Order Service — architecture notes

These notes were reverse-engineered from the source at `allensanborn/pizzaco-hexagonal-ddd`.
They record detail that would make the diagram boxes unreadable if inlined, and they are
deliberate about separating **what the code does** from **what the names imply**.

## The hexagon

The repo delivers on its central claim. `core` contains no Spring annotations and no
imports from `infrastructure`, and an ArchUnit test (`HexagonalArchitectureTest`) enforces
both. `CoreWiringConfig` is a genuine composition root: it constructs the plain-Java use
cases and domain services as beans, so the framework touches the core in exactly one file.

Ports are split the way the pattern intends:

| Direction | Port | Implemented by |
| --- | --- | --- |
| Inbound | `PlaceOrderUseCase` | `PlaceOrderService` |
| Inbound | `ProgressOrderUseCase` | `ProgressOrderService` |
| Inbound | `GetOrderUseCase` | `GetOrderService` |
| Outbound | `OrderStore` | `OrderRepository` |
| Outbound | `PaymentProcessor` | `StripePaymentAdapter` |
| Outbound | `EtaProcessor` | `GoogleMapsEtaAdapter` |
| Outbound | `NotificationPort` | `FirebaseNotificationAdapter` |
| Outbound | `ClockPort` | `Instant::now` lambda in `CoreWiringConfig` |

`PizzaOrder` is an immutable aggregate root: every transition returns a new instance and
`requireCurrentStatus` rejects an illegal source state, so the lifecycle invariant lives in
the domain rather than in a service.

## What the diagram marks as Simulated

Three adapters carry the names of real SaaS products but contact nothing. They have no SDK
dependency, no HTTP client, and no credentials — each logs a line and returns a canned value:

- `StripePaymentAdapter` — always returns success with a random reference. **No failure path
  is reachable in a running system**, so `PaymentFailedException` and its 402 handler are
  dead code outside the unit tests.
- `GoogleMapsEtaAdapter` — always returns 30 minutes, ignoring both addresses.
- `FirebaseNotificationAdapter` — returns a random message id. Nothing reaches the customer.

The diagram styles these grey and dashed, and labels the edges "Would …", so the picture
cannot be mistaken for a claim that the integrations exist.

## What the diagram marks as Planned

`Kitchen Context` and `Delivery Context` do not exist in this repo in any form. They appear
as dotted, near-transparent boxes because the README names them as where status transitions
*should* come from. Today those transitions arrive instead from an unauthenticated
`POST /orders/{id}/progress`, which the README calls "demo progression" — modelled on the
diagram as the **Store Operator**, a stopgap actor in purple.

## Observations worth discussing

The code review that came out of this modelling exercise lives in
[`docs/findings/`](../../findings/README.md) — seventeen findings, one file each, severity
ordered. Three of them are pricing defects confirmed by running the code, and they coexist
with a passing build.

Start with [the findings index](../../findings/README.md).

## The seam is built but never used

Hexagonal architecture earns its keep when adapters can be swapped — a fake payment adapter
in dev, the real one in production. That swap is normally expressed with `@Profile`,
`@ConditionalOnProperty`, or separate bean definitions, and it is what makes the pattern pay
for its indirection.

This repo does none of it:

- no `@Profile`, `@ConditionalOnProperty`, `@Primary` or `@Qualifier` anywhere in `src/`
- exactly **one** implementation per outbound port
- no Dockerfile, no compose file, no Kubernetes manifests

So the simulated adapters are not a dev-profile choice — they are the *only* implementation,
selected by component scan at compile time. `Simulated` is therefore modelled as an element
tag on the component view, describing a permanent property of the code. If these were
`@Profile("local")` fakes with real adapters behind `@Profile("prod")`, that tag would belong
on a deployment view instead, as two environments of one container.

This is arguably the sharpest critique of the repo *as a showcase*: it demonstrates the
structure of ports and adapters without ever demonstrating the benefit.

## About the proposed deployment view

`ProposedDeployment` is the one view here that is **not** reverse-engineered. Nothing on it
exists. It is included to show what productionising the current containers would require:
an external PostgreSQL in place of the embedded H2, TLS and authentication at the edge, and
more than one task. The `Order Store (managed)` container is tagged `Planned` and is excluded
from the as-built Container view for that reason.

## Diagram provenance

Generated with the `drawing-c4-diagrams` skill from `workspace.dsl` in this directory.
Regenerate the images with:

```bash
cd docs/architecture
docker run --rm -v "$PWD:/work" -w /work structurizr/structurizr validate -workspace workspace.dsl
docker run --rm -v "$PWD:/work" -w /work structurizr/structurizr export -workspace workspace.dsl -format plantuml -output exports
cd exports
docker run --rm -e PLANTUML_LIMIT_SIZE=16384 -v "$PWD:/data" -w /data plantuml/plantuml -tpng "structurizr-*.puml"
```
