# Graph Report - plugin-rails  (2026-07-30)

## Corpus Check
- 9 files · ~2,474 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 73 nodes · 95 edges · 11 communities (8 shown, 3 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 3 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `9a1d45b3`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- KrynoxCaptchaTest
- MockPlane
- captcha.rb
- .require_krynox_captcha
- FormatCollector
- Captcha
- Railtie
- Krynox
- Krynox Captcha for Rails
- Changelog

## God Nodes (most connected - your core abstractions)
1. `KrynoxCaptchaTest` - 15 edges
2. `FakeController` - 12 edges
3. `MockPlane` - 7 edges
4. `FormatCollector` - 6 edges
5. `Krynox Captcha for Rails` - 6 edges
6. `ControllerHelpers` - 4 edges
7. `Config` - 3 edges
8. `verify()` - 3 edges
9. `Railtie` - 3 edges
10. `Changelog` - 3 edges

## Surprising Connections (you probably didn't know these)
- `FakeController` --mixes_in--> `ControllerHelpers`  [EXTRACTED]
  test/krynox_captcha_test.rb → lib/krynox/captcha/controller_helpers.rb

## Import Cycles
- None detected.

## Communities (11 total, 3 thin omitted)

### Community 0 - "KrynoxCaptchaTest"
Cohesion: 0.21
Nodes (4): Test, FakeController, FakeRequest, KrynoxCaptchaTest

### Community 2 - "captcha.rb"
Cohesion: 0.31
Nodes (6): Captcha, Config, fail_result(), Krynox, post(), verify()

### Community 3 - ".require_krynox_captcha"
Cohesion: 0.29
Nodes (3): Captcha, ControllerHelpers, Krynox

### Community 5 - "Captcha"
Cohesion: 0.40
Nodes (3): Captcha, Krynox, ViewHelpers

### Community 6 - "Railtie"
Cohesion: 0.67
Nodes (3): Captcha, Krynox, Railtie

### Community 9 - "Krynox Captcha for Rails"
Cohesion: 0.29
Nodes (6): Honeypot, Install, Krynox Captcha for Rails, License, Render the widget, Verify the submission

### Community 10 - "Changelog"
Cohesion: 0.40
Nodes (4): [0.1.0] - 2026-07-22, Added, Changelog, [Unreleased]

## Knowledge Gaps
- **8 isolated node(s):** `Captcha`, `[Unreleased]`, `Added`, `Install`, `Render the widget` (+3 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **3 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `FakeController` connect `KrynoxCaptchaTest` to `.require_krynox_captcha`, `FormatCollector`?**
  _High betweenness centrality (0.157) - this node is a cross-community bridge._
- **Why does `KrynoxCaptchaTest` connect `KrynoxCaptchaTest` to `MockPlane`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Why does `ControllerHelpers` connect `.require_krynox_captcha` to `KrynoxCaptchaTest`?**
  _High betweenness centrality (0.054) - this node is a cross-community bridge._
- **What connects `Captcha`, `[Unreleased]`, `Added` to the rest of the system?**
  _8 weakly-connected nodes found - possible documentation gaps or missing edges._