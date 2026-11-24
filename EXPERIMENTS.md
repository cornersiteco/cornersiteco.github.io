# Corner Site Co. — site experiments

One small change per week. Metric: "New free-draft request — Corner Site Co." emails (FormSubmit) received per week (Mon–Sun, Ottawa time).

## Weekly form-request counts

| Week starting | Requests | Notes |
|---|---|---|
| 2026-11-23 (partial, site launched 2026-11-24 00:32 ET) | 0 real (1 owner test on 2026-11-24) | Launch week. Owner test submission sent and FormSubmit activated 2026-11-24; form now delivers to the inbox. Do not count the test as a lead. |

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

### 2026-11-24 — Form friction fix (live session, desktop app)
- Change: added `_captcha=false` (removes FormSubmit's reCAPTCHA interstitial; spam is still caught by the existing `_honey` field) and `_autoresponse` (instant "we got your request, draft within 3 business days" email to the submitter). No visible page change, no price/offer change.
- Hypothesis: the captcha page is an extra step after clicking submit, where some visitors drop off. Removing it should raise completed requests per visitor. The autoresponse builds trust and sets expectations.
- Result: _pending — measure on next run. If spam submissions appear, re-enable captcha.

### 2026-11-24 — Three more prospect drafts (not part of main-site experiments)
- Added /drafts/rainbow-auto/, /drafts/touchette-autocare/, /drafts/klassik-barbershop/ (noindex, disallowed in robots.txt, not linked from main site).
