# Corner Site Co. — site experiments

One small change per week. Metric: "New free-draft request — Corner Site Co." emails (FormSubmit) received per week (Mon–Sun, Ottawa time).

## Weekly form-request counts

| Week starting | Requests | Notes |
|---|---|---|
| 2026-11-23 (partial, site launched 2026-11-24 00:32 ET) | 0 (as of 2026-11-24) | Launch week. No FormSubmit activation email found yet, so no submission has been made. |

## Log

### 2026-11-24 — Baseline: site launch
- Change: initial launch of index.html and thanks.html (commit fac308a).
- Result: 0 requests at measurement time (site live under 1 day). Baseline established.

### 2026-11-24 — Local SEO structured data
- Change: added LocalBusiness (`ProfessionalService`) JSON-LD (name, Ottawa address locality, area served, email, URL) and a canonical link to index.html. No visible page change.
- Hypothesis: a brand-new site has almost no search visibility. Telling Google clearly that this is an Ottawa web-design business should help it appear for "Ottawa small business website" style searches, bringing the first visitors and form requests. Expect a slow effect (search indexing takes weeks); judge over 3–4 weeks, not 1.
- Result: _pending — measure on next run._

### 2026-11-24 — Launch-polish batch (owner asked for visible changes, live session)
- Change (batched on purpose): (1) trust line under hero buttons: "Based in Ottawa · Free draft, no obligation · You own your domain"; (2) new "What your site could look like" section with three sample layouts (café, salon, garage), clearly labelled as samples, not client sites, plus a "Samples" nav link; (3) sticky "Get your free draft" bar on phones (≤600px), hidden once the form is on screen; (4) Ottawa neighbourhood line in the contact section (Orléans, Kanata, Barrhaven, Nepean, Vanier, Centretown, Westboro, Hintonburg, the Glebe).
- Why batched: with ~0 visitors a week, one-at-a-time tests can't be measured anyway. Fix the obvious gaps now, go back to single-change tests once traffic reaches ~20+ visitors/week (outreach starts driving prospects to the site).
- Hypothesis: prospects who hear from us by phone/DM/walk-in will check the site; showing what they'd get, plus true trust signals and an always-visible CTA on phones, should raise the share who request a draft.
- Result: _pending — measure on next run._
