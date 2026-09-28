# Architecture diagrams

C4 model of the Pizzaco Order Service, expressed as [Structurizr DSL](https://docs.structurizr.com/dsl).
`workspace.dsl` is the single source of truth; every image in `exports/` is generated from it.

These diagrams were **reverse-engineered from the code**, not written from intent. Where the
two disagree, the diagram follows the code and says so:

- **Simulated** (grey, dashed) — the code names the integration but never calls it.
- **Planned** (white, dotted) — does not exist in this repo in any form.
- **Stopgap** (purple) — exists only to stand in for something missing.

## Views

| View | Level | What it answers |
| --- | --- | --- |
| `SystemContext` | 1 | Who uses the service and what it depends on. |
| `Containers` | 2 | As-built: one Spring Boot deployable plus an in-memory store. |
| `ComponentsHexagon` | 3 | The ports-and-adapters seam, with actors, externals and wiring stripped out. |
| `Components` | 3 | Everything inside the Order API, including the composition root. |
| `PlaceOrder` | Dynamic | The 20 steps of `POST /orders`, as a sequence diagram. |
| `ProposedDeployment` | Deployment | **Not as-built.** What productionising this would take. |

Read [docs/01-overview.md](docs/01-overview.md) for the detail behind the boxes, including
eight observations about the code that the diagrams surfaced.

## Regenerating

```bash
cd docs/architecture
docker run --rm -v "$PWD:/work" -w /work structurizr/structurizr validate -workspace workspace.dsl
docker run --rm -v "$PWD:/work" -w /work structurizr/structurizr inspect  -workspace workspace.dsl
docker run --rm -v "$PWD:/work" -w /work structurizr/structurizr export   -workspace workspace.dsl -format plantuml -output exports

cd exports
docker run --rm -e PLANTUML_LIMIT_SIZE=16384 -v "$PWD:/data" -w /data plantuml/plantuml -tpng "structurizr-*.puml"
docker run --rm -e PLANTUML_LIMIT_SIZE=16384 -v "$PWD:/data" -w /data plantuml/plantuml -tsvg "structurizr-*.puml"
```

`PLANTUML_LIMIT_SIZE` matters: at PlantUML's 4096px default, three of these views are
silently clipped rather than failing.

To edit layout interactively instead:

```bash
docker run -it --rm -p 8080:8080 -v "$PWD/docs/architecture:/usr/local/structurizr" \
  structurizr/structurizr local
```
