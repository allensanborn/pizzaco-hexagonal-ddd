workspace "Pizzaco Order Service" "C4 model of the Pizzaco order service, a DDD + Hexagonal Architecture showcase. Reverse-engineered from the code; the Simulated and Planned tags mark what the code does NOT do." {

    model {
        !impliedRelationships true

        customer = person "Customer" "Orders pizza and tracks it. Inferred: the API has no authentication."

        operator = person "Store Operator" "Advances order status by hand. A stand-in for the kitchen and delivery contexts." {
            tags "Stopgap"
        }

        pizzaco = softwareSystem "Pizzaco Order Service" "Owns the order aggregate from placement through to delivery." {
            !docs docs

            api = container "Order API" "Spring-free hexagonal core wrapped in web, persistence and integration adapters. Enforced by an ArchUnit test." "Java 21 / Spring Boot 3" {

                group "Inbound Adapters (infrastructure.web)" {
                    webController = component "Pizza Web Controller" "Exposes POST /orders, POST /orders/{id}/progress and GET /orders/{id}." "Spring @RestController" {
                        tags "Adapter"
                    }
                    exceptionHandler = component "Global Exception Handler" "Maps core exceptions onto 404, 402 and 400." "Spring @RestControllerAdvice" {
                        tags "Adapter"
                    }
                }

                group "Application / Use Cases (core.application)" {
                    placeOrder = component "Place Order Service" "PlaceOrderUseCase: validate, ETA, price, charge, confirm, persist, notify." "Plain Java, no Spring" {
                        tags "UseCase"
                    }
                    progressOrder = component "Progress Order Service" "ProgressOrderUseCase: drives the guarded lifecycle transitions." "Plain Java, no Spring" {
                        tags "UseCase"
                    }
                    getOrder = component "Get Order Service" "GetOrderUseCase: flattens the aggregate into an OrderView." "Plain Java, no Spring" {
                        tags "UseCase"
                    }
                }

                group "Domain (core.domain)" {
                    pizzaOrder = component "PizzaOrder Aggregate" "Immutable aggregate root. Owns the lifecycle invariants." "Plain Java + value objects" {
                        tags "Domain"
                    }
                    validation = component "Order Validation Service" "Rejects empty items, bad quantities, missing address or contact." "Domain service" {
                        tags "Domain"
                    }
                    pricing = component "Order Pricing Service" "Sums line totals; delegates the delivery fee." "Domain service" {
                        tags "Domain"
                    }
                    feeCalc = component "Delivery Fee Calculator" "Free delivery for 3+ pizzas within 5 miles, else a flat 5.00." "Domain service" {
                        tags "Domain"
                    }
                }

                group "Outbound Adapters (infrastructure)" {
                    orderRepo = component "Order Repository" "OrderStore port. Maps the aggregate to OrderEntity, items as JSON." "Spring @Component + Jackson" {
                        tags "Adapter"
                    }
                    jpaRepo = component "Order JPA Repository" "Spring Data CRUD on ORDER_ENTITY." "Spring Data JPA" {
                        tags "Adapter"
                    }
                    stripeAdapter = component "Stripe Payment Adapter" "PaymentProcessor port. SIMULATED: always succeeds, no HTTP call." "Spring @Component" {
                        tags "Adapter" "Simulated"
                    }
                    mapsAdapter = component "Google Maps ETA Adapter" "EtaProcessor port. SIMULATED: always 30 minutes, no HTTP call." "Spring @Component" {
                        tags "Adapter" "Simulated"
                    }
                    firebaseAdapter = component "Firebase Notification Adapter" "NotificationPort. SIMULATED: logs only, no HTTP call." "Spring @Component" {
                        tags "Adapter" "Simulated"
                    }
                    clock = component "Clock Port Bean" "ClockPort, as an Instant::now lambda." "Java method reference" {
                        tags "Adapter"
                    }
                }

                group "Composition Root (infrastructure.config)" {
                    wiring = component "Core Wiring Config" "The only place Spring touches the core." "Spring @Configuration" {
                        tags "Wiring"
                    }
                }
            }

            db = container "Order Store" "One denormalised row per order, items as JSON. In-memory: lost on restart." "H2 (in-memory)" {
                tags "Database" "Ephemeral"
            }

            dbTarget = container "Order Store (managed)" "PLANNED. The same logical store, durable. Appears only on the proposed deployment view." "PostgreSQL 16" {
                tags "Database" "Planned"
            }
        }

        stripe = softwareSystem "Stripe" "Card payment gateway. Named by the adapter, never contacted." {
            tags "External" "Simulated"
        }

        maps = softwareSystem "Google Maps Platform" "Travel-time source for the ETA. Named by the adapter, never contacted." {
            tags "External" "Simulated"
        }

        firebase = softwareSystem "Firebase Cloud Messaging" "Push channel for order updates. Named by the adapter, never contacted." {
            tags "External" "Simulated"
        }

        kitchen = softwareSystem "Kitchen Context" "PLANNED. Does not exist in this repo. Should own baking progress." {
            tags "External" "Planned"
        }

        delivery = softwareSystem "Delivery Context" "PLANNED. Does not exist in this repo. Should own the courier." {
            tags "External" "Planned"
        }

        # --- People to the system ---
        customer -> webController "Places an order, then polls its status" "JSON/HTTPS"
        operator -> webController "Advances the order lifecycle by hand" "JSON/HTTPS" "Stopgap"

        # --- Inbound adapter to input ports ---
        webController -> placeOrder "Invokes PlaceOrderUseCase" "In-process"
        webController -> progressOrder "Invokes ProgressOrderUseCase" "In-process"
        webController -> getOrder "Invokes GetOrderUseCase" "In-process"
        exceptionHandler -> webController "Advises, translating escaped exceptions" "Spring AOP"

        # --- Use cases to domain ---
        placeOrder -> validation "Validates the command with" "In-process"
        placeOrder -> pricing "Prices the order with" "In-process"
        placeOrder -> pizzaOrder "Drafts, prices, then confirms" "In-process"
        pricing -> feeCalc "Delegates the fee rule to" "In-process"
        progressOrder -> pizzaOrder "Asks for a guarded transition" "In-process"
        getOrder -> pizzaOrder "Reads state from" "In-process"

        # --- Use cases to output ports (adapters) ---
        placeOrder -> mapsAdapter "Estimates ETA via EtaProcessor" "In-process"
        placeOrder -> stripeAdapter "Charges the total via PaymentProcessor" "In-process"
        placeOrder -> orderRepo "Saves via OrderStore" "In-process"
        placeOrder -> firebaseAdapter "Confirms via NotificationPort" "In-process"
        placeOrder -> clock "Stamps placedAt via ClockPort" "In-process"
        progressOrder -> orderRepo "Loads and saves via OrderStore" "In-process"
        progressOrder -> firebaseAdapter "Notifies via NotificationPort" "In-process"
        getOrder -> orderRepo "Loads via OrderStore" "In-process"

        # --- Outbound adapters onward ---
        orderRepo -> pizzaOrder "Maps and rehydrates" "Jackson"
        orderRepo -> jpaRepo "Reads and writes entities through" "In-process"
        jpaRepo -> db "Reads from and writes to" "SQL/JDBC"
        stripeAdapter -> stripe "Would authorise payment against" "SIMULATED"
        mapsAdapter -> maps "Would request travel time from" "SIMULATED"
        firebaseAdapter -> firebase "Would push the update to" "SIMULATED"

        # --- Composition root ---
        wiring -> placeOrder "Constructs" "Spring bean" "Wiring"
        wiring -> progressOrder "Constructs" "Spring bean" "Wiring"
        wiring -> getOrder "Constructs" "Spring bean" "Wiring"
        wiring -> pricing "Constructs" "Spring bean" "Wiring"
        wiring -> validation "Constructs" "Spring bean" "Wiring"
        wiring -> feeCalc "Constructs" "Spring bean" "Wiring"
        wiring -> clock "Constructs" "Spring bean" "Wiring"

        # --- Planned integrations ---
        kitchen -> api "Should report Baking and ReadyForDelivery to" "PLANNED, event-driven" "Planned"
        delivery -> api "Should report OutForDelivery and Delivered to" "PLANNED, event-driven" "Planned"

        api -> dbTarget "Would read from and write to" "SQL/JDBC" "Planned"

        # --- PROPOSED deployment. None of this exists: the repo has no Dockerfile,
        # --- no compose file, no k8s manifests and no Spring profiles.
        deploymentEnvironment "Proposed Production" {
            aws = deploymentNode "Amazon Web Services" "PROPOSED. Nothing below exists in the repo today." "AWS eu-west-2" {
                tags "Proposed"

                alb = infrastructureNode "Application Load Balancer" "Terminates TLS and routes /orders. Would also carry the authentication the API currently lacks." "AWS ALB" {
                    tags "Proposed"
                }

                ecs = deploymentNode "Amazon ECS (Fargate)" "Stateless tasks. Safe to scale out only once the order store is external." "ECS Fargate" {
                    tags "Proposed"
                    task = deploymentNode "Order API Task" "The same Spring Boot container, unchanged." "Docker / Java 21" {
                        instances 3
                        tags "Proposed"
                        apiInstance = containerInstance api
                    }
                }

                rds = deploymentNode "Amazon RDS" "Managed PostgreSQL, Multi-AZ. REPLACES the embedded in-memory H2 - the application.yaml already runs H2 in PostgreSQL compatibility mode, so this is the intended destination." "PostgreSQL 16" {
                    tags "Proposed"
                    dbInstance = containerInstance dbTarget
                }
            }

            alb -> apiInstance "Routes order traffic to" "JSON/HTTPS"
        }
    }

    configuration {
        scope softwaresystem
    }

    views {
        systemContext pizzaco "SystemContext" "Level 1. Grey dashed boxes are integrations the code names but never calls. The two dotted contexts do not exist in this repo at all." {
            include *
            autolayout tb 300 150
        }

        container pizzaco "Containers" "Level 2, as-built. One Spring Boot deployable plus an in-memory database. Everything else is outside the boundary." {
            include *
            exclude dbTarget
            autolayout tb 300 150
        }

        component api "ComponentsHexagon" "Level 3, the hexagon only. Inbound adapters drive use cases, use cases orchestrate the domain, and outbound adapters satisfy the core's output ports. Actors, externals and wiring are omitted so the seam is the only thing to read." {
            include *
            exclude wiring
            exclude clock
            exclude exceptionHandler
            exclude customer
            exclude operator
            exclude stripe
            exclude maps
            exclude firebase
            exclude db
            autolayout lr 400 150
        }

        component api "Components" "Level 3, full. Everything inside the Order API, plus the actors, data store and external systems it touches. Dotted grey edges are Spring bean construction, not runtime calls." {
            include *
            autolayout tb 400 150
        }

        deployment pizzaco "Proposed Production" "ProposedDeployment" "PROPOSED, NOT AS-BUILT. The repo has no Dockerfile, no compose file, no k8s manifests and no Spring profiles, so nothing on this page exists yet. It shows what productionising the current containers would require: an external PostgreSQL in place of the embedded H2, TLS and authentication at the edge, and more than one task." {
            include *
            autolayout lr 300 150
        }

        dynamic api "PlaceOrder" "How POST /orders runs. Note that the aggregate is constructed three times before it is saved once, and that three of these steps reach systems that are only simulated." {
            customer -> webController "POST /orders with items, address and distance"
            webController -> placeOrder "placeOrder(command), store address hardcoded"
            placeOrder -> validation "validate(items, address, contact)"
            placeOrder -> mapsAdapter "estimateMinutes(...) via EtaProcessor"
            mapsAdapter -> maps "SIMULATED: no call, returns a hardcoded 30"
            placeOrder -> pricing "calculateSubtotal(items)"
            placeOrder -> pizzaOrder "submitted(...): a throwaway draft, so the fee rule can see the items"
            placeOrder -> pricing "calculateDeliveryFee(draft, miles)"
            pricing -> feeCalc "calculateFee: free for 3+ within 5 miles, else 5.00"
            placeOrder -> pizzaOrder "rehydrate(...): a second draft carrying the fee"
            placeOrder -> stripeAdapter "processPayment(...) via PaymentProcessor"
            stripeAdapter -> stripe "SIMULATED: no call, always succeeds"
            placeOrder -> pizzaOrder "confirm(ref): the only guarded step, Submitted to Confirmed"
            placeOrder -> orderRepo "save(order) via OrderStore"
            orderRepo -> jpaRepo "save(OrderEntity), items serialised to JSON"
            jpaRepo -> db "INSERT"
            placeOrder -> firebaseAdapter "notifyCustomer(...) via NotificationPort"
            firebaseAdapter -> firebase "SIMULATED: no call, logs only"
            webController -> getOrder "getOrder(id): a second read, PlaceOrderResult is discarded"
            getOrder -> orderRepo "findById(id) via OrderStore"
            autolayout lr 300 150
            properties {
                "plantuml.sequenceDiagram" "true"
            }
        }

        styles {
            element "Person" {
                shape person
                background #08427b
                color #ffffff
            }
            element "Stopgap" {
                background #6b5b95
                color #ffffff
            }
            element "Software System" {
                background #1168bd
                color #ffffff
            }
            element "Container" {
                background #438dd5
                color #ffffff
            }
            element "Component" {
                background #85bbf0
                color #000000
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Simulated" {
                background #b0b0b0
                color #ffffff
                border dashed
                opacity 60
            }
            element "Planned" {
                background #ffffff
                color #999999
                border dotted
                opacity 40
            }
            element "Database" {
                shape cylinder
            }
            element "Ephemeral" {
                border dashed
            }
            element "Domain" {
                background #f2c14e
                color #000000
            }
            element "UseCase" {
                background #6fcf97
                color #000000
            }
            element "Adapter" {
                background #85bbf0
                color #000000
            }
            element "Proposed" {
                background #ffffff
                color #999999
                border dotted
            }
            element "Wiring" {
                background #dddddd
                color #666666
                border dotted
            }
            relationship "Relationship" {
                thickness 2
            }
            relationship "Wiring" {
                style dotted
                color #999999
            }
            relationship "Planned" {
                style dashed
                color #999999
            }
            relationship "Stopgap" {
                style dashed
                color #6b5b95
            }
        }

        theme default
    }
}
