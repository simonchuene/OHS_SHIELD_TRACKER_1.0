# OHS Shield Tracker — MVP 1 Build Prompt

You are a Principal Software Architect, Senior Flutter Engineer, Enterprise UX Designer, PostgreSQL Data Architect, and Occupational Health & Safety (OHS) Subject Matter Expert.

Your task is to design and build an enterprise-grade Occupational Health & Safety (OHS) Performance Management Platform. The system must be suitable for medium and large organizations and should align with **ISO 45001** principles.

**Focus ONLY on MVP Version 1.**

---

## PROJECT STATUS (updated 2026-08-06)

> Living status note. The requirements below are unchanged (canonical). This block records what has actually been built and hardened. Full decision/hardening log: `DECISIONS_LEDGER.md` (§8 compile pass, §9–§10 device testing).

**Build: complete.** The MVP1 sequence (Prompts 1–18 + 4C/5A/8A) is implemented — all 11 feature modules (Auth/User-Mgmt, Hazards, Risk, Incidents, Investigations, CAPA, Inspections, Dashboard, Reporting, Notifications, Audit), offline-first sync (outbox + cache + LWW/field-merge), RLS + `app.*` helpers, and 4 Edge Functions (`user-admin`, `workflow-transition`, `inspection-item-fail`, `notify-fanout`). Toolchain in use: Flutter 3.44.6 / Dart 3.12.2 (target pin 3.24.5). Tests green.

**Deployed & device-tested.** Running against a live Supabase backend on Android (emulator + tablets). Two hardening rounds (§9 2026-08-04, §10 2026-08-05) fixed: the universal blank-screen theme bug, sync-on-launch/enqueue, action-controller & session-expiry auth bugs, the stale read-after-write (transitions needing a second tap), and several list/dashboard defects.

**Recent product enhancements (2026-08-05), extending — not redesigning — the master design system:**
- Dashboard **Today's Priorities**: top open hazards + CAPAs + incidents, ranked severity → overdue → soonest-due → most-recently-updated; two-line KPI labels; safety-score 7-day trend delta.
- **Hazard ↔ CAPA linkage** surfaced on both detail pages (list + navigate).
- **CAPA**: owner may start work without Supervisor rank (RLS 0016); overdue now triggers the day *after* the due date; risk filter = band-or-more-severe.
- **Loading UX**: shimmer skeletons replace spinners (dashboard, hazard/CAPA list & detail); Actions page defaults to a status-grouped list.
- **Branding (2026-08-06)**: OHS launcher/adaptive icon replaces the default Flutter icon (also rebrands the Android 12 splash); brand-green native launch background; animated in-app splash with the icon in a squircle. On-screen branding renders the PNG raster, not the SVG — `flutter_svg` drops the gauge's dash pattern and would draw the safety arc as a full circle.
- Android `compileSdk` pinned to 36.

**Known pre-release TODO:** remove the DEBUG-ONLY corporate-CA trust (`DevHttpOverrides` + `assets/dev/corporate_ca.pem`, gated to `kDebugMode`) before any public/release build.

**Deferred (post-MVP1, unchanged):** licensing/seats (MVP2), server-side `dashboard-aggregates`, JWT-claims access-token hook, Realtime.

---

## BUSINESS GOAL

The application must help organizations:
- Identify workplace hazards
- Assess risk
- Investigate incidents
- Manage corrective actions
- Track safety performance
- Improve compliance
- Provide management visibility

This is **NOT** a simple incident reporting application.

The system must follow the workflow:

**Hazard Reported → Risk Assessment → Investigation → Corrective Action → Verification → Closure**

---

## PRODUCT POSITIONING

This application is an enterprise Occupational Health & Safety Management System. It must support:
- Financial Institutions
- Mining
- Manufacturing
- Logistics
- Utilities
- Construction
- Government

The design and architecture must be suitable for organizations starting with **10–50 employees**, but scalable to support larger multi-site organizations in future phases.

---

## APPLICATION THEME (MASTER DESIGN SYSTEM)

The application UI/UX must strictly follow the OHS Performance Tracking Application design guide below and serve as the **MASTER DESIGN SYSTEM** for MVP 1, MVP 2, and MVP 3. All future phases must inherit and extend this system — they must **never** redesign it. Future MVPs may introduce new components but must not replace or fundamentally change the colors, typography, navigation patterns, component styling, spacing system, or overall visual language established here. The final product must feel like one continuously evolving enterprise OHS platform.

### Design System Governance

This application will evolve through multiple phases:

| Phase | Focus |
|---|---|
| MVP 1 | Core Safety Operations |
| MVP 2 | Enterprise OHS Management |
| MVP 3 | AI-Powered Safety Intelligence |

### Design Philosophy

Professional · Enterprise Grade · Safety Focused · Compliance Oriented · Data Driven · Executive Friendly · Mobile First · Field Worker Friendly · Minimal · Clean · Accessible · High Usability · WCAG 2.1 AA Compliant

The application should feel similar to modern HSE software platforms and corporate compliance systems (e.g., ServiceNow Mobile, Microsoft Power Apps Mobile, EcoOnline, Intelex, Cority). The design should prioritize fast data capture, readability, risk visibility, compliance visibility, safety performance visibility, and decision support.

### Mobile Layout System

This application is **MOBILE FIRST**. Design all screens primarily for a **390 x 844** viewport. Support Android phones, iPhones, Android tablets, and iPads. Tablet layouts should be responsive enhancements of the mobile design.

**Do NOT generate** desktop layouts, desktop sidebars, desktop navigation, or desktop-specific workflows.

**Grid System:** 16px gutters, 16px margins.

**Spacing Scale:** 4 · 8 · 12 · 16 · 24 · 32 · 40 · 64 (px). Use spacing tokens consistently throughout all modules.

### Typography

- **Font Family:** Inter (fallback: Roboto)
- **Heading 1:** 32px, Bold
- **Heading 2:** 24px, Semi-Bold
- **Heading 3:** 18px, Semi-Bold
- **Body Text:** 14–16px
- **Caption:** 12px

All MVPs must use identical typography tokens and hierarchy.

### Color System

| Token | Hex | Purpose |
|---|---|---|
| Primary Green | `#2E7D32` | Compliance, Success, Completed Actions |
| Warning Amber | `#F9A825` | Warnings, Attention Required, Medium Risk |
| Critical Red | `#C62828` | Critical Risk, Overdue Actions, Non-Compliance, Incidents |
| Information Blue | `#1565C0` | Links, Insights, Reports, AI Features |
| Background | `#F5F5F5` | Screen background |
| Card Background | `#FFFFFF` | Card surfaces |
| Primary Text | `#212121` | Primary text |
| Secondary Text | `#9E9E9E` | Secondary/helper text |

These colors must remain unchanged across MVP 1, MVP 2, and MVP 3.

### Card Design

- **Default Card:** White background, 12px radius, soft shadow.
- **Metric Card:** Icon, KPI value, trend indicator.
- **CAPA Card:** Title, owner, due date, status.
- **Risk Card:** Risk level, risk score, owner, status.

All future cards introduced in MVP 2 and MVP 3 must inherit the same styling.

### Button Design

- **Primary:** Filled Green
- **Secondary:** Outlined Blue
- **Danger:** Filled Red
- **Text/Link:** Link style

Use the same button system throughout all MVPs.

### Form Design

Use text fields, dropdowns, date pickers, toggles, checkboxes, radio buttons. All forms must support validation, error states, helper text, and required indicators. Forms should prioritize quick field capture for mobile users.

### Tables & Lists

Row height 56px. Support search, filter, sort, pagination. Prefer mobile-friendly lists over large data tables.

### Dashboards & Analytics

Use KPI cards, donut charts, line charts, bar charts, risk heatmaps.

**Dashboard Information Priority:**
1. Safety KPIs
2. Compliance KPIs
3. Risk Indicators
4. Open Actions
5. Incident Trends

All dashboards introduced in future MVPs must follow the same card layouts, chart styles, colors, and typography.

### Navigation

**Bottom Navigation:** Dashboard · Hazards · Actions · More

The navigation structure established in MVP 1 becomes the permanent navigation framework. Future modules must be added under "More" without redesigning navigation.

- **MVP 2 additions:** Health, Training, Compliance, Contractors, Permits, Documents
- **MVP 3 additions:** AI Copilot, Risk Intelligence, Knowledge Hub, Automation, Digital Twin

### Iconography

Use **Material Icons Rounded** or **Lucide Icons**. Examples: Dashboard `layout-grid` · Incidents `alert-triangle` · CAPA `check-circle` · Risk Register `shield` · Committee `users` · Reports `bar-chart-2` · Settings `settings`. Maintain consistent icon style across all MVPs.

### Accessibility

Must comply with **WCAG 2.1 AA**: minimum 44x44 touch targets, screen reader support, keyboard navigation, tooltips, high contrast support. Accessibility standards must remain consistent across all phases.

### Dark Mode

Generate both Light and Dark themes. Dark Mode must use the same spacing, typography, hierarchy, navigation, and component design patterns.

### AI Design Rules (Reference for MVP 3)

Even though AI features ship in MVP 3, note now so the design system anticipates it: do **not** use purple AI themes, neon effects, consumer chatbot styling, or experimental UI. Use Information Blue (`#1565C0`) with existing cards, typography, buttons, and navigation — AI must feel like a native extension of the platform, not a bolt-on.

### Avoid (All MVPs)

Desktop-focused layouts · Consumer social media styling · Gamification themes · Neon colors · Excessive animations · Glassmorphism · Gaming aesthetics · Inconsistent component styles

---

### SIGNATURE DESIGN SYSTEM (Anti-Generic Layer)

The rules above (colors, typography, spacing) are **locked and must never change.** However, using only default Material 3 components with these tokens will produce a generic, templated look. To avoid this, the following signature elements are **mandatory** and must be treated as first-class parts of the design system — inherited by MVP 2 and MVP 3 exactly like colors and typography.

**1. Brand Motif — The Progress Ring Shield**
The application icon is a rounded shield containing a health/protection cross, wrapped by a **circular progress ring** (mostly closed, with a small gap — read as a completion/compliance indicator), plus a small circular grey checkmark badge. This ring + shield + checkmark language is the app's core structural motif and must be extended into the UI as **functional components**, not just decoration:
- **The progress ring becomes the shape language for all radial/completion indicators** app-wide: the Dashboard's Risk Compass (see Item 3), CAPA completion rings, inspection completion rings, and onboarding progress all use this same "ring with a gap, closing as it nears completion" visual — directly derived from the logo, not arbitrary.
- **The user avatar frame** uses a thin circular ring border (~8px at mobile scale, white or Primary Green depending on surface, with a small intentional gap echoing the logo) instead of a plain circle.
- **A "Compliance Checkmark Badge"** — cropped directly from the source icon asset (the exact grey circle + green checkmark, not a redrawn icon) — is a reusable signature component overlaid on avatars, cards, or list rows to indicate "verified," "closed," "compliant," or "passed inspection" states, instead of a generic green check icon.
- **The shield-with-cross silhouette** is used as a subtle low-opacity (4–8%) background watermark on the Dashboard hero header only, and as the base shape for splash screen and login branding.
This ties APPLICATION BRANDING and APPLICATION THEME together structurally, not just by color — directly resolving any perceived conflict between the two.

**1a. Exact Icon Reproduction Rule (MANDATORY, No Exceptions)**
The application icon supplied by the product owner (SVG/PNG source asset) must be used **verbatim, pixel-exact, with zero AI reinterpretation or redrawing**, in every placement: launcher icon, splash screen, login branding, header logo chip, and app store listings. Development and design tooling (including any AI-assisted design generation) must treat the source icon file as a **fixed binary asset to be imported and resized/cropped only** — never regenerated, restyled, or approximated from a text description. Only the following two derivative crops are permitted, and only because they are direct crops of the original file (not redraws):
1. The full icon tile (as supplied) — used for the header logo chip, splash screen, and launcher icon.
2. The isolated circular checkmark badge — cropped directly from the source asset — reused as the "Compliance Checkmark Badge" component described in Item 1.
No other derivative, simplified, or "inspired by" version of the icon may be created. If a hexagonal, faceted, or otherwise stylized reinterpretation of the icon appears anywhere in generated designs, it must be rejected and rebuilt using the actual source file.

**AI-generation handoff (mandatory):** Because a text-based model cannot see or embed a binary it was not given, generated code and design output must reference the icon by its **asset path as a fixed placeholder** (e.g. `assets/branding/app_icon.svg`) — wired up by a human against the real supplied file — and must **never** hallucinate, redraw, or emit an approximated inline SVG/vector of the icon. Any inline vector art the model produces for the watermark (Item 4) or the ring/shield/cross motif is explicitly a *derived line-art treatment*, not a substitute for the launcher/splash/header logo, which must always point to the real asset file.

**1b. Brand Accent Color — Use Sparingly, Never in Core Semantic UI**
The icon includes a magenta/burgundy accent stripe (`#923357`, sampled from the source SVG) that is **not part of the locked Color System** and must never be used for status, risk, or semantic meaning (that is reserved for Green/Amber/Red/Blue per the Color System). Per the Branding Conflict Rule, this accent is permitted **only** as a decorative brand-identity touch in non-functional contexts:
- A single thin accent stripe (3–4px) on the splash screen and login screen, echoing the icon's stripe.
- Optionally, a subtle accent stripe on the Settings/Profile screen header as a brand flourish.
- **Never** on buttons, status chips, charts, KPI cards, or any element that could be confused with the Green/Amber/Red/Blue semantic system.

**2. Non-Uniform Corner Radius System (Shape Language)**
Do not apply the same 12px radius to every surface — this is the single biggest cause of generic-feeling UI. Instead:
- **Hero/Feature Cards** (Safety Score, top-of-dashboard elements): 28px radius, asymmetric — top corners 28px, bottom corners 12px.
- **Standard Cards** (CAPA, Risk, list cards): 12px, uniform, per existing rule — unchanged.
- **Status Chips/Pills:** fully rounded (999px) with a colored dot + icon, never plain colored rectangles.
- **Primary CTA Buttons:** 16px radius (deliberately distinct from card radius, so buttons read as "actionable" against "informational" cards).

**3. Signature Data Component — The Risk Compass**
Replace the generic donut chart on the dashboard with a **Risk Compass**: a radial gauge styled as a segmented ring (Low/Medium/High/Critical arcs in the locked color tokens), visually a direct extension of the logo's progress ring, with the current site risk score as a large center numeral in tabular figures and the Compliance Checkmark Badge (Item 1) rendered small at the ring's center-bottom as a brand anchor. This becomes the app's signature visual — reused across Dashboard, Reports, and Risk Assessment summary screens. No other HSE competitor tool in this space uses a compass-style dial derived from its own logo (most use generic plain donuts), which directly differentiates the product and reinforces brand recall.

**3a. Safety Score Card — Approved Layout (Finalized)**
The Safety Score hero card uses a fixed two-column layout — do not rearrange this in later phases:
- **Left column (~35% of card width):** "Safety Score" heading, "Overall risk rating" caption, a thin horizontal divider, then a trend block: "Great work!" in bold Primary Green with a small inline up-trend arrow glyph, followed by "Your score improved" and "+6 vs last 7 days" in Secondary Text Color — stacked, left-aligned, no badges or pills in this column.
- **Right column:** The Risk Compass gauge centered in the remaining width, with the score numeral and "of 100" caption inside the ring, and the Compliance Checkmark Badge anchored at the bottom gap of the ring.
- This same two-column pattern (context/trend text on the left, signature radial visual on the right) should be reused for equivalent summary cards in MVP 2/MVP 3 (e.g., Compliance Score, Training Completion) for visual consistency.

**4. Layered Hero Header with Brand Watermark (Dashboard/Home Only)**
The Dashboard's top section must use a two-layer composition, not a flat app bar:
- **Layer 1 (back):** Primary Green base with a very subtle diagonal gradient mesh (Green → deeper Green, max 10% luminance shift — not a rainbow gradient).
- **Brand watermark:** Positioned in the upper-right region of the header (behind/around the user avatar), a low-opacity (≈10% white) outline-only rendering of the logo's motif: an outer **ring** (echoing the progress ring), a **shield silhouette** inside it, and a **cross/plus** inside the shield — all stroke-only, no fill, no drop shadow. This must be reproduced as vector line art derived from the actual icon's proportions (ring → shield → cross), not a generic icon substitute, and must be large enough to read as a deliberate background texture rather than clutter. It may extend past the header's bottom edge; the overlapping Safety Score card naturally crops it.
- **Layer 2 (front, overlapping):** A white "Safety Score" card floating partially over the header boundary (overlap by ~24px), casting the standard soft shadow. This overlap technique creates depth without glassmorphism or blur effects.
- This exact watermark treatment (ring + shield + cross, ~10% opacity, upper-right placement) is locked and must be reused identically on any future full-bleed hero header introduced in MVP 2/MVP 3 (e.g., Compliance or Training dashboards) for visual consistency.

**4a. Curved Hero Header — Approved Layout (Finalized)**
The Dashboard hero header is finalized as a **full-width green panel with a flat, gently curved (convex) bottom edge** — not a straight-edged rectangle and not a full circle/dome. Build it exactly as follows; this supersedes the "~24px overlap" figure in Item 4:
- **Shape:** Full-bleed Primary Green panel (subtle diagonal Green → deeper Green gradient per Item 4) with a shallow convex bottom curve — the top corners remain fully green (no inward "shoulders"), and the bottom edge sweeps down gently toward the center. Reference radius at the 390px viewport: bottom corners `50% / 46px` (horizontal% / vertical px). Keep the curve shallow — do not make it a half-circle dome.
- **Extended depth:** The green panel extends further down than a standard app bar so the Safety Score card (Item 3a) overlaps it by **roughly half the card's height**, floating over the lower portion of the green. The card retains its 28px-top / 12px-bottom asymmetric radius and standard soft shadow.
- **Top row (left → right):** Logo chip — the exact source icon (squircle, per Item 1a) at ~38px — immediately followed by the two-line wordmark: "OHS SHIELD" (bold, white) over "TRACKER" (letter-spaced, lighter green tint). On the far right, the user avatar framed by the Progress Ring Shield avatar ring (Item 1: thin circular ring with a small gap, Primary Green on this surface).
- **Greeting block:** Below the top row, **left-aligned**: a bold white greeting line (e.g., "Good morning, {first name}") with a lighter green-tint subtitle beneath it (e.g., "Stay safe. Make it count."). Do not center this block.
- **Watermark:** The Item 4 ring + shield + cross watermark (~10–13% white, stroke-only) sits in the upper-right region behind the avatar, clipped by the header's curved bounds.
- This finalized curved-header shape (shallow convex bottom, extended depth, half-overlapping summary card, left-aligned greeting) is locked and must be reused for any full-bleed hero header in MVP 2/MVP 3.

**5. Custom Iconography Treatment**
Use Lucide/Material Rounded icons per the existing rule, but apply a **consistent duotone treatment**: icon stroke in the relevant status color at full opacity, with a matching 15% opacity filled background circle behind it inside cards and list rows. Never use flat single-tone icons directly on white card backgrounds — the duotone badge treatment is mandatory and consistent across all modules.

**6. Tabular Numerals for All Metrics**
Any KPI number, risk score, or count (Dashboard, Reports, Cards) must use **tabular (monospaced-width) numeral rendering** within Inter, at a visually heavier weight (Bold/Black) than surrounding labels, at minimum 1.5x the label's font size. This is what makes enterprise dashboards (Stripe, Linear, Datadog-style) feel authored rather than templated — numbers must dominate visually over their captions.

**7. Empty & Loading States — Custom Line-Art, Not Stock Icons**
Empty states (no hazards, no CAPAs, all clear, offline) must use **simple custom single-weight line illustrations** in Primary Green or Secondary Text color — never default Material icons enlarged, and never generic stock "empty box" clipart. Pair with specific, human microcopy (e.g., "No open hazards on this site — nice work." rather than "No data available").

**7a. Dashboard KPI Metric Row — Approved Layout (Finalized)**
Directly beneath the Safety Score card, the Dashboard shows a **single row of four compact KPI tiles** (Open Hazards, High Risk, Open CAPAs, Overdue) as the primary at-a-glance metrics. Each tile is a standard 12px white card containing, top to bottom: the duotone icon badge (Item 5), the count as an oversized Bold tabular numeral (Item 6), a Secondary Text label, and a short (~20px) colored underline accent in that metric's semantic color (Amber / Critical Red / Information Blue / Critical Red respectively). This four-up KPI row is the locked Dashboard summary pattern; additional KPIs from the DASHBOARD section appear below in stacked cards/charts.

**7b. Priority List Row — Approved Layout (Finalized)**
List rows (Today's Priorities, hazard/CAPA/incident lists) are finalized as: leading duotone icon badge (Item 5) → two-line text block (Primary Text title + Secondary Text meta line, e.g. "Site · Department") → a fully-rounded status pill (Item 2: colored dot + label on a 12–18% tint of its semantic color) → a trailing chevron. This row anatomy is reused across all list-based modules.

**8. Floating Pill Bottom Navigation**
Instead of a flat, edge-to-edge Material bottom navigation bar, use a **floating rounded pill nav** inset 12px from the screen edges and bottom, with soft elevation shadow, and the active tab indicated by a filled pill background in Primary Green with the label shown inline beside the icon (inactive tabs show icon + label in Secondary Text, no pill). This is a small deviation from stock Material bottom nav that meaningfully changes the perceived quality of the app.

**9. Motion Personality (Restrained, Not Excessive)**
Per the "Avoid excessive animations" rule, motion must be minimal but **present and consistent**: 150–200ms ease-out for screen transitions, a subtle scale-down (0.97x) + shadow-lift on card tap, and a single signature animation — the Risk Compass needle/arc animates into position on load (400ms) rather than appearing instantly. No other motion beyond this is permitted in MVP 1.

**Governance:** Items 1–9 above (including sub-items 3a, 4a, 7a, 7b) are locked design decisions, identical in status to the Color System and Typography sections. MVP 2 and MVP 3 must reuse the Progress Ring Shield motif, the Compliance Checkmark Badge, the corner radius system, the Risk Compass component, the curved hero header, the duotone icon treatment, the KPI/list row anatomy, and the floating pill nav exactly as defined here — do not introduce alternate shape languages, alternate motifs, or unapproved accent colors in later phases. The Exact Icon Reproduction Rule (Item 1a) applies without exception across MVP 1, MVP 2, and MVP 3.

**Reference Implementation:** Production-fidelity mockups of the **Splash Screen, Login Screen, and Home Dashboard**, built using the exact source icon asset (not an AI-redrawn approximation), accompany this specification as reference images for the design/development team. The Home Dashboard reference demonstrates the finalized decisions in Items 3a, 4a, 7a, and 7b (curved green hero header with left-aligned greeting, logo chip + wordmark, avatar with progress ring, half-overlapping Safety Score card with Risk Compass, four-up KPI row, priority list rows, and floating pill nav). Generated designs must match these references.

### Localization

Out of scope for MVP 1. Single language (English) only. However, the architecture (string resources, date/number formatting, layout widths) must **not block** future internationalization — do not hardcode user-facing strings inline in widgets.

---

## APPLICATION BRANDING

**Application Name:** OHS Shield Tracker
An SVG application icon is attached.

The application branding **must support and extend** the APPLICATION THEME above. The icon must **not override** theme colors, typography, component styling, navigation, accessibility standards, or design language.

Instead:
- Use the icon as the brand identity
- Use the icon on splash screens, login screens, app headers, launcher icons, and in reports/exports

If the SVG icon contains colors that differ from the APPLICATION THEME colors:
1. Preserve the icon as designed.
2. Keep the APPLICATION THEME colors as the application's primary design system.
3. Use icon colors only for branding elements, illustrations, and logo treatments.

**Generate:** Splash Screen · Launcher Icons · Login Branding · Empty States · Loading States — using the attached SVG icon.

### Login Screen Branding

Display the application logo prominently at the top of the login screen. Below the application name, display the tagline:

> "Transforming safety metrics into operational strength"

**Tagline Styling:** Center aligned · Inter Font · 14–16px · Medium Weight · Secondary Text Color (`#9E9E9E`) · Maximum 2 lines · Responsive on small devices.

**Visual Hierarchy (top to bottom):** Application Logo → Application Name → Tagline → Email Field → Password Field → Login Button

The tagline should reinforce the application's purpose without dominating the screen. Maintain a professional, enterprise-grade, safety-focused appearance.

### Branding Conflict Rule

If any conflict exists between the APPLICATION THEME and APPLICATION BRANDING, **the APPLICATION THEME always takes precedence.** The SVG icon must adapt to the design system — the design system must never adapt to the icon.

---

## DESIGN CONSISTENCY RULE (Applies to MVP1, MVP2, MVP3)

All screens, modules, components, workflows, and future MVPs must inherit the design system established in MVP 1. Do not redesign the application between MVPs — extend the existing design language. Colors, typography, spacing, icons, navigation, cards, forms, buttons, charts, dashboards, and accessibility standards must remain consistent across all three phases. The final product must feel like one cohesive, continuously evolving enterprise OHS platform that never changes its visual identity.

---

## MVP EVOLUTION RULES

| Phase | Scope |
|---|---|
| **MVP 1** | Hazards, Risk Assessments, Incidents, Investigations, CAPA, Inspections, Reporting |
| **MVP 2** | + Health Surveillance, Training, Compliance, Contractors, Permits, Documents (no design pattern changes) |
| **MVP 3** | + AI Copilot, Risk Forecasting, Intelligence Hub, Automation Engine, Digital Twin, Advanced Analytics (must use existing design system) |

---

## TECHNOLOGY STACK

**Frontend:**
- Flutter (stable channel, SDK **≥ 3.24, < 4.0** — pin exact version in `pubspec.yaml` at project init)
- Riverpod (`flutter_riverpod` + `riverpod_annotation`/`riverpod_generator` for code-generated providers)
- GoRouter (latest stable, declarative routing)
- Material 3

**Local Offline Database:**
- **Drift** (SQLite) for structured offline storage of hazards, incidents, inspections, and CAPA updates, mirroring the `sync_queue` table structure defined below.

**Backend:**
- Supabase (Auto-generated PostgREST API + Supabase Edge Functions for custom business logic — see API DESIGN section)

**Database:**
- PostgreSQL (via Supabase)

**Authentication:**
- Supabase Auth (email/password; RBAC layered on top via `user_roles`)

**Notifications:**
- Firebase Cloud Messaging (FCM) for push notifications
- Supabase `notifications` table for in-app notifications
- Email hooks reserved for future implementation

**Storage:**
- Supabase Storage (attachments; see ATTACHMENT MANAGEMENT for versioning approach)

**Architecture:**
- Clean Architecture

**Project Structure:**
```
lib/
├── core/
├── shared/
├── features/
├── services/
├── repositories/
└── app.dart
```

---

## NOTIFICATIONS

Generate notification workflows for: New Hazard · New Incident · CAPA Assigned · CAPA Overdue · Investigation Due · Inspection Due

**Channels:** Push (FCM) · In-App · Email (reserved)

Notifications must support Priority, Escalation, and Read Status. Each user device must register a token in the `device_tokens` table (see DATABASE DESIGN) to receive push notifications.

---

## USER ROLES & PERMISSIONS (RBAC)

1. Employee
2. Supervisor
3. Safety Officer
4. Manager
5. Administrator

Implement RBAC using Supabase Row Level Security (RLS), enforced at the database layer — not only in the Flutter UI.

**Baseline Permission Matrix** (extend as needed per module during build; UI must conditionally render actions per role):

| Action | Employee | Supervisor | Safety Officer | Manager | Administrator |
|---|:---:|:---:|:---:|:---:|:---:|
| Report Hazard / Incident | ✅ | ✅ | ✅ | ✅ | ✅ |
| Perform Risk Assessment | ❌ | ✅ | ✅ | ✅ | ✅ |
| Conduct Investigation | ❌ | ✅ | ✅ | ✅ | ✅ |
| Create / Assign CAPA | ❌ | ✅ | ✅ | ✅ | ✅ |
| Verify & Close CAPA | ❌ | ❌ | ✅ | ✅ | ✅ |
| Close Hazard / Incident | ❌ | ❌ | ✅ | ✅ | ✅ |
| Conduct Inspections | ❌ | ✅ | ✅ | ✅ | ✅ |
| View Own Records | ✅ | ✅ | ✅ | ✅ | ✅ |
| View Department Records | ❌ | ✅ | ✅ | ✅ | ✅ |
| View Site / Enterprise Dashboards | ❌ | ❌ | ✅ | ✅ | ✅ |
| Invite / Provision User | ❌ | ❌ | ❌ | ❌ | ✅ |
| Assign / Change Role & Scope | ❌ | ❌ | ❌ | ❌ | ✅ |
| Deactivate / Reactivate User | ❌ | ❌ | ❌ | ❌ | ✅ |
| Reset User Password (admin-initiated) | ❌ | ❌ | ❌ | ❌ | ✅ |
| View Audit Log | ❌ | ❌ | ✅ | ✅ | ✅ |

---

## USER MANAGEMENT & PROVISIONING

Authentication (login, session, self-service password reset) is covered under the AUTHENTICATION module. This section governs the **user lifecycle and access administration** that sits on top of it.

**Identity model — three layers, kept separate:**
- `auth.users` — Supabase-managed identity and credentials (email, encrypted password, tokens). Never store passwords in application tables.
- `user_profiles` — the application record, 1:1 with `auth.users` by `id`. Holds `company_id`, `site_id`, `department_id`, display name, contact details (POPIA-minimised), and `status`.
- `user_roles` — **scope-aware** role assignments: `(user_id, role_id, site_id NULL, department_id NULL)`. A NULL scope means company-wide; a populated `site_id`/`department_id` restricts the role to that scope. This is what lets a Safety Officer cover one site while a Manager spans several, and it is the source of the claims RLS reads (see MULTI-SITE ARCHITECTURE).

**Provisioning — invite-based, Administrator-provisioned. No open self-registration.** A user cannot self-signup, because signup cannot establish which company/site/department they belong to, and POPIA calls for controlled collection of personal data. Flow: an Administrator invites by email → Supabase `inviteUserByEmail` issues the invite → the invitee sets their own password → the profile is activated. All privileged operations (invite, role/scope change, deactivate, admin-initiated password reset) run through **Supabase Edge Functions using the service role** — never from the Flutter client.

**Lifecycle — soft state changes, never hard delete.** User status flows: `invited → active → suspended → deactivated`. Deactivation revokes the session and blocks login but **retains the record**, because a former user still owns historical hazards, incidents, and audit entries; hard-deleting would break referential integrity and the audit trail. This mirrors the platform's existing "never delete history" posture (attachment versions, immutable audit logs). Every invite, role/scope reassignment, activation, suspension, and deactivation is written to `audit_logs` with before/after state — these are security-relevant events.

**RBAC.** User administration actions (Invite/Provision, Assign/Change Role & Scope, Deactivate/Reactivate, admin-initiated Password Reset) are **Administrator-only** in MVP1 (see permission matrix). Site-scoped delegation to Managers may be introduced later but is out of MVP1 scope. Enforce at the RLS / Edge-Function layer, not only in the UI.

**Licensing (deferred to MVP2).** Seat limits, subscriptions, plan tiers, module entitlements, and billing are **out of scope for MVP1** and deferred to MVP2. To avoid rework, build the invite/provisioning path so a single seat-entitlement check can be inserted at the invite gate later (e.g. "block activation when active users ≥ seat_limit") without restructuring the user model. Do **not** build any billing, payment, subscription, or seat-enforcement logic in MVP1.

---

## MVP MODULES

1. Authentication
2. User & Access Administration *(admin-only: invite/provision users, assign roles & site/department scope, deactivate/reactivate — see USER MANAGEMENT & PROVISIONING)*
3. Dashboard
4. Hazard Management
5. Risk Assessments
6. Incident Management
7. Investigations
8. Corrective Actions (CAPA)
9. Inspections
10. Reports
11. Notifications
12. Audit Log Viewer *(view-only screen for Safety Officer/Manager/Administrator roles — required since all business actions must be auditable)*

**Do NOT build:** Health Surveillance, Training, Contractors, Permit To Work, Document Management — these belong to future phases. **Licensing, billing, and seat management are deferred to MVP2** (see USER MANAGEMENT & PROVISIONING).

---

## HAZARD MANAGEMENT

**Fields:** Hazard ID · Title · Description · Category · Site · Department · Reporter · Date Reported · Photos · Status · Risk Level

**Hazard Categories:** Physical · Chemical · Biological · Ergonomic · Psychosocial · Noise · Radiation · Environmental

**Workflow:** Draft → Submitted → Assessment → Investigation → CAPA → Verification → Closed

Generate complete UI screens.

**Definition of Done:** A user with appropriate role can create, categorize, attach photos to, transition through every workflow status, and close a hazard end-to-end, with all state transitions written to the audit log.

---

## RISK ASSESSMENT

**Fields:** Likelihood (1–5) · Severity (1–5) · Current Controls · Required Controls · Assessor · Review Date

**Formula:** Risk Score = Likelihood × Severity

**Risk Levels:**

| Score | Level |
|---|---|
| 1 – 5 | Low |
| 6 – 12 | Medium |
| 13 – 17 | High |
| 18 – 25 | Critical |

Build a risk calculator component that computes the score live as Likelihood/Severity are selected, and visually maps the result to the color system (Green/Amber/Red per level, with Critical using Critical Red at full intensity).

**Definition of Done:** Risk score auto-calculates with no gaps or overlaps across the full 1–25 range, and the assigned level drives card color, dashboard heatmap placement, and CAPA priority defaults.

---

## INCIDENT MANAGEMENT

**Types:** Near Miss · First Aid · Medical Treatment · Lost Time Injury · Property Damage · Environmental Incident

**Fields:** Date · Time · Location · Description · Witnesses · Photos · Severity

**Severity Scale** (ordered enum — the incident equivalent of the Risk Level bands; drives card colour, dashboard placement, and notification priority):

| Severity | Colour Token | Typical Triggering Types |
|---|---|---|
| Minor | Primary Green | Near Miss, First Aid |
| Moderate | Warning Amber | Medical Treatment, Property Damage |
| Serious | Critical Red | Lost Time Injury, Environmental Incident |
| Critical | Critical Red (full intensity) | Fatality / major loss events |

This severity enum is a locked domain value — record it in the Decisions Ledger and reference it consistently from the Dashboard, Reporting, and Notification modules. Do not invent a per-module severity scale.

**Data minimisation (POPIA):** Capture only operationally necessary personal information for witnesses and injured parties, and restrict visibility of that data to authorised roles via RLS (see COMPLIANCE & DATA PROTECTION).

**Workflow:** Reported → Investigated → CAPA → Verified → Closed

Block transition to **Closed** unless verification evidence exists and any linked CAPAs are themselves closed. Every transition is audit-logged. Incidents are a separate first-class entity from Hazards (see DOMAIN MODEL RULE) and support bidirectional linkage: a Hazard may lead to an Incident, and an Incident may generate Investigations, CAPAs, or follow-up Hazards.

---

## INVESTIGATION MODULE

**Fields:** Immediate Cause · Contributing Factors · Root Cause · Recommendations · Investigator

**Methods:** 5 Whys · Fishbone

Build forms and timelines.

---

## CAPA MODULE

**Fields:** Action ID · Description · Priority · Owner · Due Date · Status · Evidence

**Workflow:** Created → Assigned → In Progress → Verification → Closed

**Priority Levels:** Critical · High · Medium · Low

Build Kanban and List views.

---

## INSPECTIONS

**Inspection Types:** Housekeeping · Fire Safety · PPE · Vehicle · Equipment

Checklist-based forms. Failed inspection items must **automatically create hazards** and **automatically create CAPAs.**

---

## DASHBOARD

**Mobile Executive Dashboard:** Optimized for mobile viewing — use stacked KPI cards, collapsible chart sections, and drill-down screens instead of desktop tables.

**Display:** Open Hazards · High Risk Hazards · Open CAPAs · Overdue CAPAs · Incident Trend · Hazard Trend · Department Risk Ranking

**KPIs:** Near Misses · Incidents · CAPA Closure Rate · Inspection Completion Rate

Use charts and cards, consistent with the DASHBOARDS & ANALYTICS theme rules above.

---

## MOBILE EXPERIENCE

**Support:** Camera Uploads · GPS Capture · Pull To Refresh · Dark Mode · Responsive Design

---

## ATTACHMENT MANAGEMENT

**Maximum upload size:** 20 MB
**Supported formats:** JPG · PNG · PDF

Attachments must support **Preview, Download, Delete, and Version History**.

> **Note:** Supabase Storage does not provide native file versioning — it overwrites objects at a given path. Implement version history at the application layer via an `attachment_versions` table that records each upload's storage path, uploader, timestamp, and file size, linked to a parent `attachments` record. Never delete prior versions; mark superseded versions as inactive instead.

Attachments must be linked to: Hazards · Incidents · Investigations · CAPAs · Inspections.

Use Supabase Storage for the underlying file objects. Generate upload and preview functionality.

---

## OFFLINE SYNCHRONIZATION

The application must work in low connectivity environments.

**Support:** Offline Hazard Reporting · Offline Incident Reporting · Offline Inspections · Offline CAPA Updates

Use **Drift (SQLite)** as the local persistence layer, with a local `sync_queue` table mirroring the server-side `sync_queue` schema. Automatic sync when connectivity returns.

**Handle:** Conflict Resolution (last-write-wins with audit trail, or field-level merge for non-conflicting fields) · Retry Logic (exponential backoff) · Sync Status Indicators (pending / syncing / synced / failed, visible per record in the UI)

---

## MULTI-SITE ARCHITECTURE

The application must support the hierarchy: **Company → Site → Department → User**

Enforce isolation via a `company_id` (and `site_id` where relevant) column on every tenant-scoped table, combined with PostgreSQL RLS policies that filter rows based on the authenticated user's assigned company/site/department claims (read from `user_profiles`/`user_roles`). User-to-scope binding and the scope-aware structure of `user_roles` are defined in USER MANAGEMENT & PROVISIONING.

All dashboard metrics, hazards, incidents, inspections, and CAPAs must support Site filtering, Department filtering, and Enterprise aggregation from MVP1.

---

## DATABASE DESIGN

Create PostgreSQL schema.

**Tables:**
`users` · `roles` · `user_roles` · `user_profiles` · `sites` · `departments` · `hazards` · `risk_assessments` · `incidents` · `investigations` · `corrective_actions` · `inspections` · `inspection_items` · `notifications` · `device_tokens` · `attachments` · `attachment_versions` · `audit_logs` · `sync_queue`

**Generate:** ERD · Primary Keys · Foreign Keys · Indexes (include indexes on all `company_id`/`site_id`/`status` columns used in RLS policies and dashboard filters, since these will be queried heavily).

---

## API DESIGN

Supabase auto-generates a REST API over PostgreSQL via **PostgREST** — do not hand-roll a duplicate custom REST layer for standard CRUD operations. Instead:

1. **Document the PostgREST contracts** (auto-generated GET/POST/PATCH/DELETE per table, with RLS-enforced access) for each module's primary tables.
2. **Use Supabase Edge Functions** only for business logic that cannot be expressed as simple CRUD + RLS, for example:
   - Auto-creating a Hazard + CAPA when an inspection item fails
   - Computing and caching dashboard aggregates
   - Sending push notifications on CAPA assignment/overdue events
   - Enforcing multi-step workflow transitions (e.g., blocking "Closed" status unless verification evidence exists)

Generate API contracts for both the PostgREST-exposed tables and the custom Edge Functions.

---

## UI/UX DESIGN

**Create:** Navigation structure · Wireframes · User flows · Dark mode · Mobile-first layouts

Design style: modern enterprise mobile software, similar quality to ServiceNow Mobile, Microsoft Power Apps Mobile, EcoOnline, Intelex, and Cority.

---

## AUDIT LOGGING

Every business action must be auditable, e.g.: Hazard Created · Risk Updated · CAPA Assigned · CAPA Closed · Incident Modified · Inspection Submitted.

**Store:** User · Action · Timestamp · Before State · After State

Audit logs must be **immutable** (no UPDATE/DELETE permitted at the database level — enforce via RLS/permissions). Provide the Audit Log Viewer module (see MVP MODULES) so Safety Officers, Managers, and Administrators can review this data — logging without a way to view it is incomplete for compliance purposes.

---

## DATA QUALITY RULE

Do not generate sample company data. Do not generate fictional hazards, incidents, employees, or inspections unless required for illustrative examples. Design all components for production use.

---

## COMPLIANCE & DATA PROTECTION

In addition to ISO 45001 alignment, the platform must be designed with **POPIA** (Protection of Personal Information Act, South Africa) principles in mind, given the target market and inclusion of financial institutions:
- Minimize collection of personal information to what is operationally necessary (e.g., witness names, injured party details).
- Ensure RLS and role-based access restrict visibility of sensitive incident/health-adjacent data to authorized roles only.
- Audit logs and attachment storage must support data subject access and deletion requests where legally required, without breaking the immutability of core safety audit trails.

---

## SECURITY REQUIREMENTS

Use: RBAC · Row Level Security · Secure File Access · Audit Logging · Environment Variables. No hardcoded secrets. All Supabase tables must be secured using RLS.

---

## DOMAIN MODEL RULE

Incidents and Hazards are separate entities. A Hazard may lead to an Incident. An Incident may generate Investigations, CAPAs, or follow-up Hazards. The application must support linking Hazards and Incidents where appropriate.

---

## STATUS GOVERNANCE

| Entity | Status Flow |
|---|---|
| Hazard | Draft → Submitted → Assessment → Investigation → CAPA → Verification → Closed |
| CAPA | Created → Assigned → In Progress → Verification → Closed |
| Investigation | Open → In Progress → Pending Review → Completed |
| Inspection | Draft → In Progress → Submitted → Closed |

---

## PERFORMANCE TARGETS

| Metric | Target |
|---|---|
| Dashboard Load | < 3 seconds |
| Search Results | < 2 seconds |
| Navigation | < 300 milliseconds |
| Offline Sync | Background processing, non-blocking |

Large forms must remain responsive at all times.

---

## BUILD WORKFLOW, OUTPUT CONVENTIONS & GOVERNANCE

This platform is built through a **sequenced set of follow-up prompts** (see the companion follow-up prompt set), not in a single pass. The following conventions apply to every prompt in that sequence and to this Master Prompt itself.

### Human Approval Gate
Each follow-up prompt assumes the outputs of all prior prompts have been **reviewed and approved by a human**. Approval is an explicit human step, not an automatic one — errors compound across 18+ prompts if outputs are accepted unread. Do not treat a prior prompt's output as correct simply because it was generated.

### Decisions Ledger (context control)
To keep later prompts consistent without exceeding context limits, maintain a compact **Decisions Ledger** capturing the stable, must-not-contradict decisions (table/provider/folder naming, chosen conflict-resolution rule, severity and status enums, cross-module contracts such as the Attachment API surface and notification trigger names). Carry **this Master Prompt + the Ledger** into each subsequent prompt rather than pasting full prior outputs. Locked domain values (colours, typography, risk bands, status flows, RBAC matrix, incident severity) are *restated* in the Ledger for convenience but remain owned by this Master Prompt — if one must change, change it here and re-derive; never let the two diverge.

### Output & Code Emission
When emitting code, output **one file per code block, each prefixed with its target path** as a comment (e.g. `// path: lib/features/incident/data/incident_repository.dart`), mapping to the Flutter folder structure defined in TECHNOLOGY STACK. Do not merge multiple files into one block or omit paths.

### Self-Verification
Where a prompt defines a checkable constraint (risk bands, RBAC matrix, status transitions, severity enum), the output must include a short **self-check** proving the constraint is satisfied (e.g. a table mapping every reachable risk score to exactly one level, or every role/action pair to allow/deny) rather than asserting compliance in prose.

### Meaning of "Production-Ready"
"Production-ready" and "complete implementation" throughout this specification mean **review-ready first implementation**: well-structured, convention-following output intended as a strong starting point that still requires human compilation, integration testing, security review, and wiring of real assets/secrets before it can ship. Generated artifacts are drafts to be verified, not deployable binaries.

---

## DELIVERABLES

1. Complete architecture
2. Flutter folder structure
3. Database schema
4. ERD
5. API specifications (PostgREST contracts + Edge Functions)
6. Riverpod providers
7. Repository interfaces
8. Use cases
9. Screen wireframes
10. Navigation flow
11. MVP implementation roadmap
12. Sprint breakdown
13. UI components
14. Test strategy
15. Security model

Provide production-ready output, as defined in BUILD WORKFLOW, OUTPUT CONVENTIONS & GOVERNANCE (review-ready first implementation, not a deployable binary).

---

## SUCCESS CRITERIA

A successful MVP1 must allow a user to:
1. Report a hazard.
2. Assess the hazard risk.
3. Conduct an investigation.
4. Create CAPAs.
5. Verify corrective actions.
6. Close the hazard.
7. Report an incident.
8. Link incidents to investigations and CAPAs.
9. Complete inspections.
10. View the full lifecycle from a dashboard.