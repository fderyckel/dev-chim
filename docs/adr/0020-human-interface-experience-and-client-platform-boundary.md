# ADR 0020: Human-interface experience and client-platform boundary

- Status: Conditionally Accepted
- Date: 2026-09-15
- Decision date: 2026-09-16
- Accountable owner: Product experience and platform engineering
- Deciders: Architecture review group, product owner, security architecture, and web/mobile engineering
- Supersedes: None

## Context

People judge Chimwemwe by whether everyday school work is clear, fast, forgiving, and trustworthy on the device in front of them. The platform must support an excellent browser experience for high-density office and leadership work and an excellent phone experience for high-frequency, time-sensitive work. A single domain and policy boundary must not force both devices into the same screen layout or interaction model.

Ash resources are declarative and introspectable, but they are not a school-ERP user interface. Treating them as a generic CRUD screen generator would make critical workflows feel generic and could confuse presentation with authorization. Conversely, independently reimplementing types, permitted actions, error handling, and policy assumptions in each client would create drift.

The system context already treats the Next.js experience as a client of the Phoenix/Ash/PostgreSQL core. Phase 0 and the bounded Phase 1 core explicitly exclude a production web or mobile application. This ADR records the accepted browser-first product/client boundary and its native-client conditions; it does not authorize implementation.

## Decision drivers

- A first-class, accessible phone experience for brief, frequent, contextual work.
- A first-class browser experience for keyboard-driven, dense, multi-step, and reporting work.
- One coherent product language without pretending that phone and desktop layouts should be identical.
- One typed, versioned action contract without a client-side policy engine.
- Measured usability, accessibility, latency, recovery, and offline behaviour rather than framework promises.
- A reversible client boundary if Ash, its generated interface, or a presentation technology later changes.

## Considered options

1. TypeScript/React clients: a Next.js browser experience and an Expo/React Native iOS and Android companion, sharing contracts and design foundations while allowing platform-specific screens.
2. A responsive browser application only, with no native mobile application.
3. One Expo/React Native Web component tree for browser and native platforms.
4. A Phoenix-rendered interface as the sole user-facing application.

## Decision

Conditionally adopt TypeScript and React as the client family. Next.js/React is the primary responsive browser experience. Expo/React Native remains deferred until a measured workflow depends on native capabilities or mobile resilience, such as push notifications, camera or scanner input, secure device integration, or explicitly designed offline capture; it is not required merely because the product has a phone layout.

The product shares a design language, not a forced common screen tree.

- Phone flows prioritize the next task, clear status, one-handed input, short forms, and safe recovery. Representative candidates include attendance capture, approvals, messages, notifications, and contextual lookup.
- Browser flows prioritize overview, search, keyboard use, data density, multi-column comparison, bulk review or correction, and reporting.
- Each workflow receives an intentional phone, browser, or dual-surface design. A browser data grid is not compressed into a phone screen, and a mobile tab layout is not imposed on office work.

Share only the things that should be consistent: semantic design tokens, terminology and localization keys, icons and content rules, status and error vocabulary, accessibility requirements, analytics event semantics, the generated TypeScript API client, and portable workflow validation that does not decide authorization. Keep component implementations, navigation, layout, input density, keyboard interactions, and device integrations platform-specific whenever user needs differ.

Ash resources, named actions, policies, and PostgreSQL constraints remain authoritative. An approved public API exposes only named reads and actions, then produces a versioned OpenAPI contract and generated TypeScript client as proposed by ADR 0014. Neither client accepts a caller-selected tenant placement or grants itself a capability. The server establishes actor, tenant, assurance, purpose, module gates, and policy; client affordances can make permitted work discoverable but never authorize it.

The governed resource descriptor from ADR 0019 may supply compatible field primitives such as public labels, help, portable types, constraints, approved relationships, and allowlisted actions. It may support safe form/view building where patterns repeat. It must not become a universal screen generator, publish a private field or action, encode policies or tenant routing, or replace deliberately designed task flows.

Navigation and personalization use the real tenant-defined capability graph and relationships. School job titles such as learner, guardian, educator, or administrator are examples of user context, not fixed production role constants or client-side authorization rules.

## Consequences

### Positive

- Users receive interfaces suited to their device and task rather than architecture-shaped generic CRUD screens.
- Browser and native clients share trustworthy contracts and product language while retaining the freedom to feel natural on their platforms.
- Explicit actions, server-side policy, and stable errors make corrections, retries, conflict handling, and support understandable across clients.
- The public API and descriptor boundaries limit coupling to Ash and preserve a Phoenix/Ecto fallback.

### Negative

- Two client implementations require deliberate product, design-system, API-version, accessibility, and release ownership.
- Component sharing is selective; teams must resist optimizing a shared component tree at the expense of desktop or mobile usability.
- Offline-capable workflows require idempotency, visible pending and failed states, sync/retry rules, conflict resolution, device-data classification, and security review; they cannot be treated as ordinary cached reads.
- Native release, notification permission, device support, and accessibility testing add operating work beyond a responsive browser application.

## Security, privacy, operability, and migration effects

Every client request passes the same authenticated Phoenix/Ash action boundary. The server resolves trusted tenant placement from authenticated context, re-authorizes reads and mutations, applies field and query filtering, and returns non-disclosing errors. Clients must not send or retain a repository, placement, policy decision, or capability assertion as authority.

Browser and native caches, local storage, notifications, deeplinks, analytics, realtime channels, and offline queues are tenant-qualified, classified, minimized, and revocable. A cached view, hidden control, generated form, or offline copy never remains authoritative after a capability, module, or tenant context changes. Any mobile offline mutation uses the named action's explicit idempotency and concurrency contract, shows `pending`, `saved`, `needs attention`, or `failed` status in words as well as colour, and fails safely when it cannot re-establish trusted context.

Accessibility is a product acceptance requirement, not a styling pass. Browser flows must support keyboard operation, visible focus, clear errors, assistive technology semantics, and responsive reflow. Mobile controls must have sufficient touch targets, understandable labels, and non-colour status cues. The exact target level and test tooling remain quality-attribute decisions; [WCAG 2.2](https://www.w3.org/TR/WCAG22/) and platform accessibility guidance are starting evidence, not proof of compliance.

The generated TypeScript client is a build artifact from the checked OpenAPI contract, never a replacement policy engine. Client upgrades follow explicit API and descriptor compatibility rules. Telemetry records only approved, classified interaction evidence and never unredacted child or restricted school data.

## Validation evidence

Current evidence is limited to the contract boundary, not user-experience proof. The generated JSON:API and TypeScript-client pressure-test in ADR 0014 establishes a candidate for named actions, policy preservation, stable errors, idempotency, tenant-safe pagination, OpenAPI drift detection, and a typed request envelope. The resource-authoring scenario and ADR 0019 establish candidate descriptor/experience-metadata boundaries. [AshJsonApi's OpenAPI support](https://ash-json-api.hexdocs.pm/open-api.html) and [Expo's web support](https://docs.expo.dev/workflow/web/) demonstrate technical feasibility only.

Before a production client or workflow ships, accountable reviewers must require:

1. Journey research and high-fidelity prototypes for at least one time-critical phone workflow, one browser-dense operational workflow, and one shared correction or handoff workflow. Attendance capture through desktop review and correction is a representative candidate, not an authorized business module.
2. Usability sessions with representative school users, declared success measures for completion, errors, recovery, confidence, and time, and recorded changes to the design.
3. Browser and mobile accessibility acceptance checks, including keyboard and screen-reader paths, target sizes, focus visibility, error identification, reduced motion, text scaling, and non-colour status communication.
4. Contract tests proving both clients use only public, versioned named actions and remain fail-closed for missing, stale, cross-tenant, revoked, or inactive context.
5. An explicit per-workflow online, offline-read, offline-write, retry, conflict, notification, local-data-retention, and device-loss policy before any native offline feature ships.
6. Measured responsiveness, degraded-network behaviour, and observability targets with accountable owners; a loading spinner alone is not a recovery design.

No current prototype, client application, user study, native release, or accessibility certification exists. Planned validation is not evidence of a top-quality interface.

## Fallback and exit cost

If the native companion is not justified by validated workflows, retain the responsive browser experience and do not change the authoritative core. If Next.js, Expo, React Native, or an Ash-generated transport proves unsuitable, replace the client implementation or use the ADR 0014 thin REST/OpenAPI adapter while preserving the named-action, tenant, error, idempotency, and compatibility contracts.

The exit cost grows only after a production client exists. Keep it bounded by owning semantic tokens, public API schemas, descriptor compatibility, and client tests in Chimwemwe-controlled packages rather than exposing Ash internals or relying on a proprietary screen generator.

## Review triggers

- User research shows that the proposed browser or native surface does not meet a critical school workflow's usability or accessibility target.
- A workflow needs offline writes, device capabilities, notifications, or realtime behaviour beyond the approved client contract.
- A shared component or universal-renderer approach materially harms desktop data density, browser semantics, or native usability.
- A public action, generated transport, descriptor, or client-version contract cannot express a required workflow safely.
- A privacy, tenant-isolation, device-loss, notification, cache, or local-data-retention review finds a material gap.

## Related records

- [System context](../architecture/system-context.md)
- [ADR 0001](0001-modular-monolith-and-service-boundaries.md)
- [ADR 0002](0002-ash-adoption-criteria-and-fallback.md)
- [ADR 0003](0003-tenant-model-and-optional-postgresql-rls.md)
- [ADR 0005](0005-domain-action-and-state-transition-convention.md)
- [ADR 0014](0014-primary-api-and-generated-typescript-client.md)
- [ADR 0019](0019-domain-model-authoring-and-governed-metadata.md)
- [Threat model](../security/threat-model.md)
