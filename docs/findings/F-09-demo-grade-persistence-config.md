# F-09 — Persistence configuration is demo-grade and the H2 console is open

| | |
|---|---|
| **Severity** | Medium |
| **Category** | Security / operability |
| **Confidence** | Confirmed by inspection |
| **Location** | `src/main/resources/application.yaml` |

## What happens

```yaml
# application.yaml
spring:
  datasource:
    url: jdbc:h2:mem:pizzaco;MODE=PostgreSQL;DB_CLOSE_DELAY=-1   # line 5
  jpa:
    hibernate:
      ddl-auto: update                                            # line 11
  h2:
    console:
      enabled: true                                               # lines 13-15

kind: Application                                                 # line 17
```

Four separate issues in one file:

1. **The database is in-memory.** Every order is lost on restart. There is one profile, so
   this is the configuration in every environment.
2. **`ddl-auto: update`** lets Hibernate mutate the schema at boot. It is a known foot-gun
   outside development and silently diverges from any migration tooling.
3. **The H2 console is enabled.** With no Spring Security ([F-04](F-04-no-authentication.md)),
   `/h2-console` is reachable by anyone who can reach the app, and grants arbitrary SQL
   against the order database.
4. **`kind: Application`** at line 17 is a stray top-level key — it looks like a fragment of
   a Kubernetes manifest pasted into the wrong file. Spring ignores it, so it is harmless,
   but it is misleading.

## Why it matters

Items 1 and 2 are defensible for a showcase and are correctly reflected in the architecture
diagrams (the `Order Store` container is tagged `Ephemeral`). Item 3 is not defensible in any
environment: an unauthenticated SQL console over the order table is a full compromise of the
data this service owns, and it is enabled by default with nothing gating it.

The `MODE=PostgreSQL` setting is a good sign — it says the author intended PostgreSQL. That
intent is captured in the `ProposedDeployment` view.

## Suggested fix

1. Disable the H2 console, or confine it to a `local` profile and bind it behind
   authentication.
2. Move H2 to a `local`/`test` profile and add a real datasource for anything else. This is
   also the first concrete use for Spring profiles, which the repo currently has none of —
   see [F-11](F-11-ports-seam-never-exercised.md).
3. Replace `ddl-auto: update` with Flyway or Liquibase.
4. Delete the stray `kind: Application` key.

## Related

- [F-04 — No authentication or authorization](F-04-no-authentication.md)
- [F-11 — The ports seam is built but never exercised](F-11-ports-seam-never-exercised.md)
- [F-15 — Line items are stored as an opaque JSON blob](F-15-opaque-json-line-items.md)
