# OHS Shield Tracker — MVP 1 UX Specification (Prompt 3)

> Implements the Master Prompt **APPLICATION THEME**, **SIGNATURE DESIGN SYSTEM (Items 1–9)**, and **APPLICATION BRANDING** exactly. Mobile-first, 390×844. No Flutter code. Locked values are referenced, never redefined.
>
> **Status:** Draft for human approval. Reference mockups: Splash / Login / Dashboard (already previewed) demonstrate Items 3a, 4a, 7a, 7b.

---

## 1. Design Tokens

### 1.1 Colour (locked — Master Prompt Color System)
| Token | Light | Dark (surface remap) | Use |
|---|---|---|---|
| Primary Green | `#2E7D32` | `#2E7D32` (accents), `#4CAF50` for text-on-dark where contrast needs | Compliance, success, primary CTA |
| Warning Amber | `#F9A825` | `#F9A825` | Medium risk, attention |
| Critical Red | `#C62828` | `#EF5350` for text-on-dark | Critical/High risk, overdue, incidents |
| Information Blue | `#1565C0` | `#42A5F5` for text-on-dark | Links, reports, AI (MVP3) |
| Background | `#F5F5F5` | `#121212` | Screen background |
| Card Background | `#FFFFFF` | `#1E1E1E` | Card surfaces |
| Primary Text | `#212121` | `#ECECEC` | Primary text |
| Secondary Text | `#9E9E9E` | `#9E9E9E` | Helper/meta |
| Brand Accent | `#923357` | `#923357` | **Decorative only** (splash/login/settings stripe) — never semantic |

Dark mode keeps identical hue semantics; only surfaces/text invert (Master Prompt Dark Mode rule). Semantic colours retain meaning; where a semantic hue fails WCAG AA on dark surfaces, a lightened tint is used **for text/icon only**, never to recolour status meaning.

### 1.2 Typography (locked)
Inter (fallback Roboto). H1 32/Bold · H2 24/SemiBold · H3 18/SemiBold · Body 14–16/Regular · Caption 12. **Tabular numerals** (Item 6) for every KPI/score/count: Bold–Black weight, ≥1.5× its label size.

### 1.3 Spacing (locked)
4 · 8 · 12 · 16 · 24 · 32 · 40 · 64. Grid: 16px margins, 16px gutters.

### 1.4 Corner-radius system (Item 2 — non-uniform, mandatory)
| Surface | Radius |
|---|---|
| Hero/Feature card (Safety Score) | 28px top / 12px bottom (asymmetric) |
| Standard card (CAPA, Risk, list) | 12px uniform |
| Status chip / pill | 999px (full) with dot + icon |
| Primary CTA button | 16px |
| Input field | 12px |

### 1.5 Elevation & motion (Item 9)
Soft shadow only (no glassmorphism). Transitions 150–200ms ease-out; card tap scale 0.97 + shadow lift; Risk Compass arc animates in over 400ms on load. No other motion.

### 1.6 Iconography (Item 5 — duotone, mandatory)
Lucide/Material Rounded. Every icon in cards/rows sits in a **15%-opacity filled circle** of its status colour with the glyph in that colour at full opacity. Never a flat single-tone icon on white. Touch targets ≥44×44 (WCAG).

---

## 2. Component Library (signature components)

| Component | Spec |
|---|---|
| **Logo chip** | Exact `assets/branding/app_icon.svg` in a ~38px squircle (Item 1a). Never redrawn. |
| **Compliance Checkmark Badge** | Cropped grey-circle+green-check from the source asset; overlaid on avatars/rows/cards for verified/closed/compliant/passed. |
| **Avatar ring** | Thin circular ring (~8px scale) with a small gap echoing the logo, Primary Green (or white on green surfaces). |
| **Risk Compass** (Item 3) | Segmented radial gauge (Low/Med/High/Critical arcs in locked tokens), centre score in tabular figures + "of 100", checkmark badge at ring bottom-gap. Reused on Dashboard, Reports, Risk summary. |
| **Curved hero header** (Item 4/4a) | Full-bleed green panel, shallow convex bottom (bottom corners 50%/46px @390), extended depth, ring+shield+cross watermark ≈10–13% white upper-right, left-aligned greeting. |
| **KPI tile** (Item 7a) | 12px white card: duotone icon badge → oversized tabular numeral → secondary label → ~20px semantic underline. |
| **Priority list row** (Item 7b) | Duotone icon badge → 2-line text (title + "Site · Department") → rounded status pill (dot+label on 12–18% tint) → chevron. Row height ≥56px. |
| **Status pill** | 999px, coloured dot + label on 12–18% tint of its semantic colour. |
| **Buttons** | Primary=filled green (16px); Secondary=outlined blue; Danger=filled red; Text/Link=blue link. |
| **Floating pill nav** (Item 8) | Inset 12px, soft elevation; active tab = filled green pill with inline label; inactive = icon+label in Secondary Text. Tabs: Dashboard · Hazards · Actions · More. |
| **Sync status badge** | Small pill/dot per record: pending (amber, clock), syncing (blue, spinner), synced (green check badge), failed (red, retry). |
| **Empty-state illustration** (Item 7) | Custom single-weight line art in Primary Green / Secondary Text + human microcopy. Never enlarged Material icons or stock clipart. |

---

## 3. Screen Inventory

Grouped by module → route → primary roles (visibility still enforced by RLS).

### Auth
| Screen | Route | Roles |
|---|---|---|
| Splash | `/` | all |
| Login | `/login` | all |
| Forgot Password | `/login/forgot` | all |

### Shell (floating pill nav)
| Tab | Route | Notes |
|---|---|---|
| Dashboard | `/dashboard` | role-scoped (Prompt 13) |
| Hazards | `/hazards` | list + FAB report |
| Actions (CAPA) | `/capa` | Kanban / List toggle |
| More | `/more` | module launcher |

### Hazards
`/hazards` (list) · `/hazards/new` (report form) · `/hazards/:id` (detail + lifecycle) · `/hazards/:id/assess` (risk) · `/hazards/:id/investigate` · `/hazards/:id/capa/new`.

### Incidents (under More)
`/incidents` · `/incidents/new` · `/incidents/:id` · `/incidents/:id/link` (link hazard) · `/incidents/:id/investigate`.

### CAPA
`/capa` (Kanban/List) · `/capa/:id` (detail + verification) · `/capa/new`.

### Investigations
`/investigations` · `/investigations/:id` (5 Whys / Fishbone + timeline).

### Inspections (under More)
`/inspections` · `/inspections/new` (type pick) · `/inspections/:id/run` (checklist) · `/inspections/:id` (summary).

### Reports / Dashboard drill-downs (under More)
`/reports` · `/reports/:type` · dashboard drill-downs `/dashboard/hazards`, `/dashboard/capa`, etc.

### Cross-cutting
`/notifications` (Center) · `/audit` (Audit Viewer — SO/Mgr/Admin) · `/audit/:id` · `/more/profile` (Profile/Settings) · `/settings`.

**Total ≈ 32 screens** across 11 modules.

---

## 4. Navigation Flows

```
Splash ──session?──▶ (no) Login ──▶ Forgot Password
                     (yes) Shell
Shell ├─ Dashboard ─▶ drill-downs ─▶ record detail
      ├─ Hazards ───▶ Hazard detail ─▶ Assess / Investigate / New CAPA
      ├─ Actions ───▶ CAPA detail ─▶ Verify & Close
      └─ More ──────▶ Incidents / Inspections / Investigations / Reports /
                       Notifications / Audit Viewer / Profile / Settings
```

- **Bottom nav is permanent** (Item 8). New MVP2/3 modules mount under **More** — the shell never changes.
- **Deep links:** notification tap → target record (`/hazards/:id`, `/capa/:id`, `/incidents/:id`, `/inspections/:id`).
- **Role guards:** Audit Viewer & User Management routes redirect unauthorised roles to a "Not available for your role" screen.
- **Back behaviour:** detail → list preserves scroll + filters. Android hardware back respected.

---

## 5. Key User Journeys

**J1 — Report a hazard (Employee, possibly offline).** Dashboard/Hazards → FAB "Report Hazard" → form (title, category, description, photo via camera, GPS auto-capture) → Submit → row appears with sync badge `pending`; toast "Hazard queued — will sync when online." Satisfies offline reporting.

**J2 — Assess → Investigate → CAPA → Verify → Close (Safety Officer).** Hazard detail → Assess (Risk Compass live) → status Assessment → Investigate (5 Whys) → create CAPA(s) → owner works CAPA → SO opens CAPA → Verification (upload evidence) → Close CAPA → Hazard detail shows all CAPAs closed → Close Hazard (blocked until evidence + CAPAs closed). Full lifecycle (Success Criteria 1–6).

**J3 — Report incident & link (Supervisor).** More → Incidents → New → type + severity + occurred date/time + location/GPS + witnesses (POPIA-minimal) + evidence → Submit → link to originating hazard → generate investigation/CAPA (Success Criteria 7–8).

**J4 — Inspection with failed item (Supervisor).** More → Inspections → New (type) → run checklist → mark item Fail → system auto-creates a Hazard + a CAPA (confirmation sheet shows both) → Submit inspection → score computed.

**J5 — Executive review (Manager).** Dashboard (enterprise scope) → Risk Compass + KPI row → drill into Overdue CAPAs → Reports → export PDF/CSV.

---

## 6. Wireframes (mobile 390×844)

### 6.1 Login
```
┌───────────────────────────┐  ▔ 4px #923357 accent stripe (top)
│         [app_icon]        │
│    OHS Shield Tracker     │  H2
│  Transforming safety      │  caption, secondary, centred, ≤2 lines
│  metrics into ...         │
│                           │
│  Email                    │
│  ┌─────────────────────┐  │  input 12px radius
│  │ ✉  name@company.com │  │
│  └─────────────────────┘  │
│  Password                 │
│  ┌─────────────────────┐  │
│  │ 🔒 ••••••••     👁   │  │
│  └─────────────────────┘  │
│              Forgot? (link)│
│  ┌─────────────────────┐  │
│  │        Log in       │  │  primary, filled green, 16px
│  └─────────────────────┘  │
└───────────────────────────┘
```

### 6.2 Dashboard (see rendered preview for fidelity)
Curved green hero (logo chip + wordmark + avatar ring + watermark + greeting) → Safety Score card overlapping (Risk Compass) → 4-up KPI row (Open Hazards/High Risk/Open CAPAs/Overdue) → "Today's priorities" list rows → floating pill nav.

### 6.3 Hazard list
```
┌───────────────────────────┐
│ Hazards            🔍  ⚟   │  H2 + search + filter
│ [All][Open][High][Mine]   │  filter chips (pills)
│ ┌───────────────────────┐ │
│ │(⚠) Exposed guard      │ │  duotone badge
│ │    Plant A · Maint.   │ │  meta
│ │            ●Critical ›│ │  status pill + chevron  ✔ synced
│ └───────────────────────┘ │
│ ┌───────────────────────┐ │
│ │(⚠) Wet floor          │ │
│ │    Warehouse · Log.   │ │
│ │            ●Medium  ›│ │  ⏱ pending (sync badge)
│ └───────────────────────┘ │
│                     ( + )  │  FAB: Report Hazard
│  [Dashboard][Hazards*]...  │  pill nav
└───────────────────────────┘
```

### 6.4 Risk assessment (calculator)
```
┌───────────────────────────┐
│ ‹ Risk Assessment         │
│ Likelihood                │
│ [1][2][3][4][5]           │  segmented selector
│ Severity                  │
│ [1][2][3][4][5]           │
│      ┌───────────┐        │
│      │   ⟳  15   │        │  live score, tabular, colour = band
│      │   HIGH    │        │  band label + colour token
│      └───────────┘        │
│ Current controls  [text]  │
│ Required controls [text]  │
│ Review date       [📅]     │
│ ┌─────────────────────┐   │
│ │   Save assessment   │   │  primary
│ └─────────────────────┘   │
└───────────────────────────┘
```

### 6.5 CAPA — Kanban (Actions tab)
```
┌───────────────────────────┐
│ Actions      [Kanban|List]│
│ Created  Assigned  In Prog…│ ← horizontally scrollable columns
│ ┌───────┐ ┌───────┐        │
│ │CAPA-12│ │CAPA-08│        │  standard card 12px
│ │Owner  │ │Owner  │        │
│ │Due 5d │ │●High  │        │
│ └───────┘ └───────┘        │
└───────────────────────────┘
```

### 6.6 Inspection run (checklist)
```
┌───────────────────────────┐
│ ‹ Fire Safety   3/10  ▓▓░ │  progress ring/bar
│ 1. Extinguishers charged? │
│   ( Pass )( Fail )( N/A ) │  segmented
│ 2. Exits unobstructed?    │
│   ( Pass )(FAIL* )( N/A ) │  fail → banner below
│   ⚠ Creates a hazard+CAPA │  info banner
│   notes [__________]       │
│ ┌─────────────────────┐   │
│ │  Submit inspection  │   │
│ └─────────────────────┘   │
└───────────────────────────┘
```

---

## 7. Screen Specifications (representative)

### 7.1 Hazard detail / lifecycle
- **Header:** reference + title, category chip, status stepper (Draft→…→Closed) with current step highlighted Primary Green; completed steps show Compliance Checkmark Badge.
- **Body cards:** Description; Risk (Risk Compass mini + band); Linked Incident (if any); Investigations; CAPAs (progress ring of closed/total); Attachments (thumbnails + version count); Audit trail link.
- **Actions (role-gated, conditionally rendered):** Assess (Sup+), Investigate (Sup+), Add CAPA (Sup+), Close (SO+ — disabled with reason tooltip until evidence + all CAPAs closed).
- **Sync badge** top-right of header.

### 7.2 Dashboard (role-scoped, Prompt 13 details data)
Layout is fixed per Items 3a/4a/7a/7b. Scope label under greeting ("Site: Plant A" / "Enterprise") reflects role. Charts: Incident Trend (line), Hazard Trend (line), Department Risk Ranking (bar), plus donut→**Risk Compass** for site risk. Collapsible chart sections; drill-down on tap.

### 7.3 Audit Viewer (SO/Mgr/Admin)
Filter bar (user, action, date range, entity type) → immutable log list (actor, action, entity, timestamp) → detail with **Before/After diff** (two-column JSON diff, changed keys highlighted). No mutation controls anywhere.

---

## 8. Form Specifications

**Global rules:** required fields marked with `*`; inline validation on blur + on submit; helper text under field; error state = red 1px border + red caption + error icon; disabled submit until required valid; date pickers native; large forms stay responsive and autosave drafts locally (offline).

| Form | Required | Validation highlights |
|---|---|---|
| Login | email, password | email format; password non-empty; auth error banner top |
| Hazard report | title, category | title ≤120 chars; photo optional; GPS auto; category from 8 enum |
| Risk assessment | likelihood, severity | 1–5 each; score/band auto (read-only); review_date ≥ today |
| Incident report | type, severity, occurred_at, description | occurred_at ≤ now; witnesses optional, minimal fields (POPIA notice) |
| CAPA | description, priority, owner, due_date | due_date ≥ today; owner from company users; priority default from source risk band |
| Investigation | method, root_cause, recommendations | root cause + recommendations mandatory to reach Completed |
| Inspection item | result | fail requires notes; fail triggers auto hazard+CAPA confirmation |

**Priority default rule:** CAPA priority pre-fills from source risk band (Critical→Critical, High→High, Medium→Medium, Low→Low) per Master Prompt Risk DoD.

---

## 9. System States

### 9.1 Empty states (Item 7 — custom line art + human copy)
| Context | Illustration | Microcopy |
|---|---|---|
| No hazards | line shield + check | "No open hazards on this site — nice work." |
| No CAPAs | line clipboard | "Nothing to action right now." |
| No incidents | line calm/leaf | "No incidents reported. Keep it that way." |
| No notifications | line bell | "You're all caught up." |
| Offline, no cache | line cloud-off | "You're offline. We'll load this when you reconnect." |

### 9.2 Loading states
Skeleton shimmer matching card/list shapes (no spinners on lists). Dashboard: Risk Compass renders its track then animates the arc in (400ms). Splash: logo + progress-ring loader. Target: dashboard <3s, search <2s.

### 9.3 Error states
- **Field:** inline (see §8).
- **Screen (load fail):** centered line-art + "Couldn't load this. Retry" (blue link) — no raw exceptions.
- **Action fail (online):** snackbar "That didn't go through. Retry" with action.
- **Permission (role):** "Not available for your role" screen, not a dead-end error.

### 9.4 Offline & sync states (per record)
| State | Badge | Meaning |
|---|---|---|
| pending | amber clock pill | queued locally, not yet sent |
| syncing | blue spinner pill | currently uploading |
| synced | green Compliance Checkmark Badge | reconciled with server |
| failed | red retry pill | max retries exceeded — tap to retry |

Global offline banner (thin, top, Secondary Text bg): "Offline — changes are saved and will sync automatically." Dismissible; reappears while offline. Dashboards show "Showing last synced data · {relative time}".

### 9.5 Notification states
- **In-app list:** unread = Primary Text title + left Primary Green 3px accent + bold; read = Secondary Text, no accent. Priority chip (Critical/High) where relevant.
- **Push (FCM):** title + body + deep link; tapping routes to the record and marks read.
- **Badge:** unread count on More/Notifications icon (tabular numeral).
- **Escalation:** overdue/critical notifications sort to top and use Critical Red priority chip.

---

## 10. Accessibility (WCAG 2.1 AA — locked)
Touch targets ≥44×44; semantic labels on all icons/controls (screen-reader); colour never the sole status signal (always paired with icon + label in pills); focus order logical; text scales with OS setting without clipping; contrast AA in both themes (semantic text hues lightened on dark surfaces as noted §1.1); high-contrast support.

---

## 11. Self-check (theme fidelity)
| Locked requirement | Honoured |
|---|---|
| Non-uniform radius (Item 2) | ✅ §1.4 |
| Risk Compass replaces donut (Item 3/3a) | ✅ §2, §7.2 |
| Curved hero header (Item 4/4a) | ✅ §2, §6.2 |
| Duotone icons (Item 5) | ✅ §1.6 |
| Tabular numerals (Item 6) | ✅ §1.2 |
| Custom empty states (Item 7) | ✅ §9.1 |
| KPI row + list-row anatomy (7a/7b) | ✅ §2, §6.3 |
| Floating pill nav (Item 8) | ✅ §2, §4 |
| Restrained motion (Item 9) | ✅ §1.5 |
| Icon used verbatim, by path (Item 1a) | ✅ §2 |
| Brand accent decorative only (1b) | ✅ §1.1 |
| Bottom nav Dashboard/Hazards/Actions/More | ✅ §3 |
| No desktop layouts | ✅ mobile-first throughout |

**End of Prompt 3 deliverable.**
