# SDD ledger — plan: docs/superpowers/plans/2026-08-31-kernel-panic-master-plan/00-MASTER-PLAN.md

## Execution contract

- Worktree: `/tmp/kernel-panic-plan-execution`
- Branch: `codex/plan-execution`
- Base: `295cc0c` (`docs: close master plan review gaps`)
- Original checkout: `/home/mafu/Projetos/kernel-panic`; preserved and not used for implementation.
- Agent policy: only the GPT-5.6 Luna family may be delegated work. Use the smallest sufficient Luna variant, one narrowly scoped implementer at a time, and no duplicate analysis without a concrete reason.
- Working mode: autonomous, critical, evidence-first, Caveman persona. Every task needs a failing test or a documented reason why a test is not meaningful, an implementation, a fresh verification run, and a second self-review before being marked complete.
- Commit policy: one task per focused commit; explicit path staging only; no merge into `main`; push only after review gates.
- Documentation policy: update technical decision/evidence records during work and compare the final diff against release-facing notes before completion.

## W0 baseline and environment

The clean worktree initially had no generated Godot import state. The first headless run was not accepted as evidence because it produced missing global-class/import failures before the project could execute. The worktree was then imported with:

```text
godot --headless --audio-driver Dummy --path . --editor --quit
```

That import exited 0 but printed the environment warning `Unable to open Android 'build-tools' directory.` This is not yet classified as a product defect; Android export feasibility remains an explicit later gate.

Measured baseline after import:

```text
XDG_DATA_HOME=/tmp/kernel-panic-plan-baseline-20260901 godot --headless --audio-driver Dummy --path . -- --autotest
```

- Exit code: `0`
- `AT_PASS`: `1414`
- `AT_FAIL`: `0`
- Completion marker: `AUTOTEST_ALL_PASS` present
- Runtime `ERROR` lines: `5`
- Runtime `WARNING` lines: `2`
- Baseline teardown diagnostics:
  - 8 resources still in use;
  - 3 `GodotArea2D` RID allocations leaked;
  - 14 dummy textures leaked;
  - 147 shaped-text allocations leaked;
  - 2 advanced-font allocations leaked;
  - 10 CanvasItem RIDs and 171 ObjectDB instances reported by warnings.
- Interpretation: functional suite is green, but process teardown is not clean. No feature task may claim leak resolution without a task-specific reproduction and before/after evidence. These diagnostics are carried forward as open reliability work.
- Log: `/tmp/kernel-panic-plan-baseline-20260901.log`

## Preflight conflict scan

The plan was scanned for shared files, contracts, lifecycle ownership, and order dependencies before runtime implementation. A conflict means that two tasks cannot be safely edited or validated as isolated work unless the shared boundary is explicitly protected.

| Tasks/interface | Relationship | Finding | Ruling | Cost if wrong |
|---|---|---|---|---|
| A1, A2, A3, A4, A5 | Architecture chain | Ownership, data, state, signals, and compatibility decisions all depend on the initial inventory. | A1 establishes evidence and ownership vocabulary first; later architecture tasks must cite it. | Refactors split responsibility and create hidden coupling. |
| A1 | Self-consistency | Inventory must distinguish runtime, content, tools, generated files, and docs. | Use an explicit classification table and do not infer ownership from directory names alone. | Generated or user-local files get committed or deleted accidentally. |
| A2 | Self-consistency | Target boundaries must map to actual Godot scenes, autoloads, scripts, and tests. | Validate each proposed boundary against code references before moving files. | Broken `preload`, `class_name`, scene, or autoload paths. |
| A3 | Self-consistency | Data-driven content can become a second source of truth. | Introduce catalog/schema only where current behavior can be represented and test it against existing data. | Silent balance/story drift. |
| A4 | Self-consistency | State machines and signals cross gameplay, HUD, pause, save, and localization. | Define lifecycle/ownership contracts before extracting state. | Double emissions, stale listeners, or paused-tree races. |
| A5 | Self-consistency | Compatibility needs to cover saves, settings, controls, and old scenes. | Preserve legacy reads and provide migration/rollback gates before changing schemas. | Existing users lose progress or settings. |
| A3 ↔ U1, U2, U2b, U3, U4, U5, U6 | Shared UI data boundary | UI needs snapshots and actions, while gameplay owns mutable state. | UI reads immutable/view snapshots and emits commands; no UI mutation of gameplay state. | UI becomes a second game controller. |
| A4 ↔ L1, L3, M1, E1, E2, E3, U2, U5 | Lifecycle and signal boundary | Settings, locale, story, entities, and UI all subscribe to state changes. | Every connection must have an owner and teardown path; use bound methods, not fragile captures. | Leaked listeners, callbacks after free, non-deterministic teardown. |
| A4 ↔ E1/E2/E3 and U3/U5 | Pause/input boundary | Game simulation pauses while UI/input can remain interactive. | Define event routing and `set_input_as_handled` ownership before new overlays. | ESC/ENTER swallowed, duplicate commands, gameplay running behind menus. |
| E1 ↔ U3, U5, G5, M5, P2, P4 | Entity rendering/content | New code-drawn entities need stable render contracts and performance budgets. | Keep simulation independent from illustration; pool/cache only after measurements. | Art refactor changes hitboxes or causes frame spikes. |
| G1 ↔ G3, G4, G5, G6, G7, M1 | Gameplay progression chain | Enemy variety, bosses, difficulty, and story rewards share spawn and progression rules. | Add content through explicit registries and deterministic tests; do not bypass stage/story gates. | Boss/reward mismatch or impossible progression. |
| G2 ↔ U2b, X1, X2 | Input/action boundary | New enemy interactions may require pointer/touch and accessibility actions. | Define action semantics once and map devices/UI to them. | Mobile and keyboard behavior diverge. |
| G3/G4/G5 ↔ M3/M4, E4 | Boss/enemy/content visuals | Boss phases, enemy telegraphs, and visual readability are coupled. | Gameplay truth drives telegraphs; visuals cannot be the only warning channel. | Unreadable attacks and inaccessible difficulty spikes. |
| M1 ↔ L1, L3, U2 | History/story presentation | macOS history needs narrative data, transitions, localization, and adaptive panels. | Ship story as data plus a presentation layer; do not bury text in drawing code. | Repeated text, localization dead ends, untestable narrative flow. |
| L1, L2, L3, L4 ↔ U2, U5, U6, A11, A14, X5 | Localization UI contract | PT-BR affects sizing, plural/select rules, input labels, and release metadata. | Inventory strings before migration; overflow tests run in both locales and compact layouts. | Clipped text, semantic mistranslation, broken controls. |
| A11–A15 ↔ U5, X3, X5, L4 | Accessibility/settings boundary | Settings controls, reduced motion, contrast, input remap, and localization share persistence. | Use one settings schema with defaults, migration, and independent section tests. | Preferences apply only visually or reset unexpectedly. |
| X1–X5 ↔ U1–U6, P2, P4 | Responsive/mobile boundary | Insets, safe areas, hit targets, virtual controls, and UI composition are cross-cutting. | Measure logical and physical viewport cases; do not claim mobile support from desktop stretch alone. | Touch occlusion, tiny controls, cutouts, or impossible landscape layouts. |
| P1–P5 ↔ E, G, U, X | Performance boundary | Rendering, spawning, text shaping, input, and mobile scale interact. | Establish p50/p95/p99 and worst-frame budgets before optimization; optimize measured hot paths only. | Premature caching or pooling causes stale state and hides regressions. |
| RPO1–RPO4 ↔ T1–T4, G5, M5 | Reliability/release boundary | Save recovery, deterministic runs, error reporting, and release notes need stable diagnostics. | Keep failures visible; separate environment teardown noise from functional failures without masking either. | False green releases or unrecoverable saves. |
| T1–T4 ↔ every code task | Test boundary | Existing harness uses real scenes and input dispatch, but not every future feature has coverage. | Each behavior-changing task adds or updates a focused probe before production code. | “Compiles” becomes the only evidence. |
| W12 ↔ U, E, G, M, L, A, X | Product validation | User value and legibility cannot be inferred from implementation success. | Use targeted playtest criteria and kill/iterate thresholds; visual approval is not automatic. | Large scope produces a technically clean but worse game. |
| 13-Risk/Governance ↔ all task groups | Decision boundary | Many plan choices are conditional on evidence, platform feasibility, or user taste. | Record assumptions, alternatives, reversibility, and stop conditions in the ledger. | Plausible guesses harden into architecture. |

## Preflight rulings

1. **Ruling: W0/A1 evidence before feature expansion** — the clean worktree required resource import and the measured suite exposes teardown leaks; this is the only defensible starting point — **cost if wrong:** feature work begins on an unverified baseline and later failures cannot be attributed.
2. **Ruling: keep legacy runtime playable while vNext is built behind explicit seams** — the user wants a from-scratch UI, but the plan also requires continuous playability, rollback, and release evidence — **cost if wrong:** a mass rewrite creates a long untestable gap or forces premature deletion.
3. **Ruling: code-drawn is the default for enemies/programs; sprites require an explicit gate** — this matches the user’s stated direction and avoids silently growing an asset pipeline — **cost if wrong:** visual work can create memory/load/performance debt before the art direction is proven.
4. **Ruling: no native screen-reader, controller, Android export, or macOS-platform promise until feasibility is demonstrated** — the plan marks those surfaces conditional and the import already showed an Android environment warning — **cost if wrong:** release claims become misleading or impossible to support.
5. **Ruling: preserve observable gameplay and save compatibility unless a documented migration says otherwise** — current probes protect input, story, rewards, and settings; UI remake is not permission to change gameplay contracts — **cost if wrong:** existing runs or user settings break under a visual refactor.
6. **Ruling: use one implementer subagent at a time and only Luna** — the user explicitly prioritizes usage limits, and this plan has sequential shared interfaces rather than many safely independent edits — **cost if wrong:** token waste, conflicting worktrees, and harder attribution.

## Task inventory

| Group | Tasks | Status | Evidence needed |
|---|---|---|---|
| W0 | Baseline/import/ledger | Completed (with open teardown risk) | Green suite marker plus classified diagnostics; import prerequisite recorded. |
| A | A1, A2, A3, A4, A5 | A1–A5 completed (reviewed) | Inventory, ownership map, A2 kit/delegate/landmine revalidation, snapshot contracts, static catalog, and save compatibility probes. A1 docs: `62b0b87` plus `76f6a0f`; A2 docs: `bd51f4c` plus `ead9d28`; A3 feature/docs: `9092163`/`c1a9b3d`/`9c5c112` plus review `0fb5d50`/`7c55b82`; A4: `b106be8`/`105d3bb`/`3ead8f0` plus `b3418aa`/`0d4cd51`; A5: `6122183`/`714ee58`/`1840e2b` plus nested-payload correction. |
| U | U1, U2, U2b, U3, U4, U5, U6 | U1–U6 completed (opt-in, reviewed) | U1–U6 now cover boot, selection, patch choice, combat HUD, pause/terminal/game-over, accessibility settings and shared recoverable state primitives; final migration, locale, visual approval, physical mobile, Android/export and teardown gates remain open. |
| E | E1, E2, E3, E4, E5 | E1, E2 batch 1, E3 and E4 completed; E2 remainder/E5 pending | E4 adds the isolated ZOMBIE_PROCESS teach wave, temporary projectile obstacle, reward/pathing hooks, code-drawn identity and real-path probe; visual approval, physical mobile, dense-wave performance and remaining cast work remain. |
| G | G1 completed; G2–G7 pending | G1 explicit run context/mode contract accepted after persistence review | Deterministic gameplay probes and balance/readability validation; G3 must build on the G1 context without treating reserved Practice as shipped. |
| M | M1–M5 | Pending | Story data/flow, history content, rewards, localization and save tests. |
| L | L1–L4 | Pending | String inventory, PT-BR behavior, plural/select/Unicode/overflow tests. |
| Accessibility | A11–A15 | Pending | Settings persistence, remapping, contrast/motion/input/touch checks. |
| X | X1–X5 | Pending | PC/mobile viewport, insets, touch, lifecycle, input and performance evidence. |
| P | P1–P5 | Pending | Profiles, budgets, p50/p95/p99, worst-frame and teardown measurements. |
| RPO | RPO1–RPO4 | Pending | Save recovery, diagnostics, reproducible builds, provenance and rollback. |
| T | T1–T4 | Pending | Test taxonomy, flake policy, capture/manual playtest/release gates. |
| UX | W12/product UX | Pending | Playtest questions, observations, prioritized proposals, kill criteria. |
| Governance | 13/Risk/Decision | Pending | Decision log, review gates, risk register, final self-review. |

## Evidence ledger

| Date | Scope | Evidence | Result | Open risk |
|---|---|---|---|---|
| 2026-09-01 | W0 baseline after Godot import | `--autotest` with Dummy audio, exit 0, 1414 passes, 0 fails, completion marker present | Functional baseline green | 5 teardown errors and 2 warnings; classify and reduce under P tasks. |
| 2026-09-01 | Worktree isolation | `git worktree list`, branch `codex/plan-execution`, original checkout unchanged by execution | Isolation confirmed | Generated `.uid`/capture import artifacts exist only in execution worktree and must not be staged accidentally. |
| 2026-09-01 | A1 repository baseline | `62b0b87` reviewed against `project.godot`, `export_presets.cfg`, `src/autoload/game.gd`, `src/autoload/sfx.gd`; docs corrected by `76f6a0f` | Accepted: no runtime change; repository map, save keys, transfer version, exports and diagnostics recorded | Android build-tools warning; teardown leaks; exact engine/export feasibility still needs dedicated verification. |
| 2026-09-01 | A2 owner-owned kit revalidation | Structural grep/audit plus `XDG_DATA_HOME=/tmp/kernel-panic-a2-xdg godot --headless --audio-driver Dummy --path . -- --autotest` | Accepted: delegates and source-scan landmines present; exit 0, 1414 passes, 0 failures, `AUTOTEST_ALL_PASS`; documentation-only | Controller-generated ignored brief was not visible to delegated inspection; versioned plans were used. Teardown diagnostics remain open. |
| 2026-09-01 | A3 snapshot contracts | Focused red/green probes, forced watchdog failure, and controller-fresh full suite; `0fb5d50`/`7c55b82` add live patch-offer projection after adversarial review | Accepted: four real owners expose primitive-safe, deep-copied schemas; focused final 32/0; full suite 1414/0 with marker | No vNext renderer consumer yet; optional-field consumer behavior and actual drawing remain future evidence; teardown diagnostics remain open. |
| 2026-09-01 | U1 vNext boot/menu slice | `vnext_boot_probe` exit 0 with `PROBE_DONE fails=0`; `vnext_menu_probe` exit 0; full suite 1414/0 with `AUTOTEST_ALL_PASS`; two independent Luna reviews, first reject then final accept | Accepted after corrections: real Buttons, stretch-normalized viewport input, one-activation checks, root BACK behavior, opt-in menu wiring, resize reconfigure, measured overflow | Opt-in only; no final visual approval; persistent accessibility, locale, route stack, and teardown cleanup remain future work. |
| 2026-09-01 | U2 vNext program/story selection | `vnext_boot_probe` exit 0; `vnext_selection_probe` exit 0; `vnext_menu_probe` exit 0; `layout_probe` 130/130; full suite 1414/0 with `AUTOTEST_ALL_PASS`; three Luna review passes (two rejects corrected, final accept) | Accepted as an opt-in slice: real program/story routes, narrow list/detail states, act tabs, project fonts, complete overflow coverage and no observed BACK fall-through | No final visual approval; PT-BR, persisted accessibility, physical-device pointer/touch, route-stack cancellation, Android export and teardown diagnostics remain open. |

## Change log of approach

## G1 — explicit run context and mode contract

- Status: implemented and reviewed on 2026-09-01 in `a5972a9`.
- Added `src/gameplay/run_context.gd` as a non-autoload `RefCounted` value
  boundary. It exposes normalized mode/stage/mutator identity, record-writing
  capability and deterministic-seed capability, with primitive-only snapshots
  and copy-returning accessors.
- Added compatibility delegates in `Game` without replacing the public mode
  field, existing `run_snapshot()`, save keys or transfer format.
- Enforced the reserved Practice rule at the real persistence boundaries:
  `end_run()` emits the transient completion signal but does not write run,
  lifetime or leaderboard records, and `unlock_achievement()` does not save
  achievements while Practice is active. No Practice launcher, wave selector or
  mutator system was implemented; those remain G3.
- Red bootstrap: `/tmp/kernel-panic-g1-red.log` showed the expected missing
  boundary and did not reach completion. Final focused green:
  `/tmp/kernel-panic-g1-practice-review-2.log`, exit 0, 29 passes, 0 failures,
  `PROBE_DONE fails=0`. Existing save compatibility probe:
  `/tmp/kernel-panic-g1-save.log`, exit 0, 39 passes, zero failures.
- Import: exit 0 with the known Android build-tools environment warning.
  Full DevHarness: exit 0, 1414/0, `AUTOTEST_ALL_PASS`. Fresh aggregate
  validator: `/tmp/kernel-panic-g1-validator-summary.log`, `VALIDATION OK`,
  G1 29/0 and no gated runtime errors.
- The first contract version only exposed the Practice flag. Controller review
  found that `Game.end_run()` would still write Practice into the Classic
  fallback and that achievements had a separate save path. The implementation
  was revised before commit; this decision and its alternatives are detailed
  in `report-G1-run-context.md` and `docs/HANDOFF-G1-RUN-CONTEXT.md`.
- Report: `.superpowers/sdd/00-MASTER-PLAN/report-G1-run-context.md`.
  Handoff: `docs/HANDOFF-G1-RUN-CONTEXT.md`.

## E4 — ZOMBIE_PROCESS

- Status: implemented and adversarially corrected on 2026-09-01 as an isolated new-enemy slice; RACE_CONDITION and later items remain pending.
- Red: focused real-path probe exit 1 with 5 failures before production code.
- Original green: focused headless and Xvfb probes exit 0 with 18 passes, 0 failures and the exact completion marker.
- Review red: the newly added reusable-steering assertion failed because only direct base separation was filtered.
- Review green: focused headless probe exit 0 with 20 passes, 0 failures; fresh aggregate validator exit 0 with E4 20/0 and no gated runtime errors.
- Full suite and fresh aggregate: 1414 passes, 0 failures, `AUTOTEST_ALL_PASS`; teardown resource/RID diagnostics remain non-gating.
- Report: `report-E4-zombie-process.md`; handoff: `docs/HANDOFF-E4-ZOMBIE-PROCESS.md`.

## E1 — entity descriptor and renderer foundation

- Status: implementado e adversarialmente corrigido em 2026-09-01, sem rota de
  produto e sem alteração de gameplay.
- Red: o probe focado falhou com os contratos ausentes (`PROBE_DONE fails=1`);
  green: import exit 0 e probe exit 0 com `PROBE_DONE fails=0`.
- Added `VNextEntityDescriptor`, `VNextEntityRenderer` e
  `VNextEntityPresentationAdapter`; `VNextEntityIllustration` agora usa os
  bounds e o renderer compartilhados. `kernel` e `DRONE` são cobertos por
  fixtures side-effect-free e por instâncias reais fora da árvore; não há
  wiring de rota nesta fatia.
- O primeiro review independente rejeitou E1: extent não cobria marcadores,
  facing não girava o glyph, adapters reais não eram exercitados, a chave não
  era canônica, o acento de era era descartado e o Control não encaminhava
  qualidade/facing. A prova foi ampliada antes da correção; `be92d2b` corrige
  esses pontos e também normaliza booleanos malformados.
- A segunda revisão rejeitou a semântica de fit/bounds/raio; a probe reproduziu
  21 falhas contra o commit anterior e `7a62a90` unificou esses cálculos.
- A revisão final encontrou dupla aplicação do fit no caminho público do
  Control; a probe reproduziu 4 falhas e `1e5812c` passou a usar a alocação
  original e o raio inverso de bounds.
- Evidência final: probe 136 `PROBE_PASS`/0 `PROBE_FAIL` em headless e Xvfb,
  import exit 0, autotest com Dummy audio 1414 `AT_PASS`, 0 `AT_FAIL`,
  `AUTOTEST_ALL_PASS`, `git diff --check` exit 0. A revisão Luna final aceitou
  o conjunto após a correção pública. Não houve captura inspecionada,
  portanto não há aprovação visual.
- Commits: `2212c12`, `99e5695`, `901da80`, `be92d2b`, `7a62a90`, `1e5812c`;
  report:
  `.superpowers/sdd/00-MASTER-PLAN/report-E1.md`; handoff:
  `docs/HANDOFF-E1-ENTITY-FOUNDATION.md`.

## E2 batch 1 — legacy enemy identity

- Status: implemented and adversarially corrected on 2026-09-01 for DRONE,
  LANCER and SPEWER; remaining E2 cast batches are pending.
- Red: focused probe before production exited 1 with `PROBE_DONE fails=15`.
- Green: focused probe passed headless and Xvfb with 76 passes/0 failures in
  each run, including queued execution of each real enemy `_draw()` in a live
  tree, Lancer AIM/LUNGE and Spewer wind-up state projection, gameplay-field
  preservation, the conservative diagonal marker envelope and GlyphLib scope
  hash.
- Import exited 0; full Dummy-audio suite exited 0 with 1414 passes, 0
  failures and `AUTOTEST_ALL_PASS`. The final accumulated validator ran after
  the corrections under a 300-second outer bound and finished
  `VALIDATION OK`; E2 was 76/0 and runtime error gates were 0.
- An intermediate direct `_draw()` attempt was rejected by Godot's draw-phase
  guard and replaced by the in-tree queued draw probe.
- Commits: `2827e2b` probe, `120c2a8` production, `d734e0e` validator,
  `a62bce9` per-frame allocation correction, `d02a607` contract and Spewer
  correction, `c5c8012` real tree draw probe, followed by the documentation
  correction commit.
- Report: `.superpowers/sdd/00-MASTER-PLAN/report-E2-batch-1.md`; handoff:
  `docs/HANDOFF-E2-LEGACY-ENEMIES-BATCH-1.md`.
- Not proven: human visual approval, fixed-seed dense-wave performance,
  physical mobile/hardware Vega, localization and Android export; baseline
  teardown diagnostics remain open.

## U6 — shared error, empty, loading and transition states

- Status: implementado e aceito em 2026-09-01; sem route de produto e sem
  producer real integrado.
- Added `VNextUIState`, `VNextUIFocusModel` e `VNextStateSurface` em escopo
  puro/code-drawn, sem producer de produto e sem tocar Game/Arena/save/scene
  APIs.
- Red: probe criada primeiro e executada com exit 1, `PROBE_DONE fails=3` por
  ausência dos três contratos.
- Green focado após revisão: `PROBE_DONE fails=0`, 145 passes em headless e
  Xvfb, incluindo real Button/Viewport keyboard+mouse, foco por ID,
  pointer/touch, layouts 1366×768/720×720/432×720/390×844, overflow,
  fixtures-only e rejeição de chaves visíveis com ponto/hífen/underscore.
- Import exit 0; suíte completa exit 0 com 1414 `AT_PASS`, 0 `AT_FAIL`,
  `AUTOTEST_ALL_PASS`; validator acumulado `VALIDATION OK`; teardown
  diagnostics permanecem não-gating.
- Revisão adversarial rejeitou a primeira aceitação: `_looks_like_key()` ainda
  deixava passar `state.error.title`, `menu.retry-label` e `catalog.missing`,
  e o validator tinha timeout sem escalada de morte. Ambos foram corrigidos;
  a probe sintética do timeout terminou em exit 137 após 2 segundos. O
  validator agora usa `--kill-after=5s`, mas isso é contenção de invocações,
  não uma garantia de supervisão de descendentes arbitrários.
- Dois probes U6 originalmente iniciados sem limite ficaram vivos por mais de
  7 minutos; foram encerrados explicitamente pelo controller. Isso foi uma
  falha de higiene da execução, não uma alegação de estabilidade do produto,
  e motivou a correção do validator e a exigência de timeout nos comandos.
- Commits: `a7619bd`, `c709734`, `33a3568`, `ed3c660`, `fc1705c`, `7c0e7f3`.
- Report: `.superpowers/sdd/00-MASTER-PLAN/report-U6.md`; handoff:
  `docs/HANDOFF-U6-STATE-SURFACE.md`.

- Initial direct test attempt was rejected as evidence because a newly created worktree lacked imported Godot resources. Import was performed first; this is recorded as an environment prerequisite, not a code fix.
- A3 added the first runtime contract methods in `Game`, `Arena`, `Menu`, and `Sfx`, plus a focused probe. The controller later corrected a false empty patch-offer projection.
- A1 agent report incorrectly described the `lifetime` save section as a separate file. Controller verification of `Game._record_run()` showed it loads and saves `Sfx.SAVE_PATH`; both baseline documents were corrected in `76f6a0f` before acceptance.
- A2 report initially described the generated task brief as absent. The controller confirmed the ignored brief existed before delegation but was not visible to the delegated inspection; the report was corrected in `ead9d28` and the versioned plans remained the source of truth.
- Next task: U2b patch offer/build decision surface. A2–A5, U1 and U2 are documented in their reports; each report includes controller corrections and residual limits.

## A4 static content catalog

- Status: completed on 2026-09-01.
- Probe red: `XDG_DATA_HOME=/tmp/kernel-panic-a4-red-xdg godot --headless --audio-driver Dummy --path . res://tools/content_catalog_probe.tscn` — exit 1 with six explicit failures because the catalog resource did not exist yet.
- Probe green: `XDG_DATA_HOME=/tmp/kernel-panic-a4-green-xdg godot --headless --audio-driver Dummy --path . res://tools/content_catalog_probe.tscn` — exit 0 with `PROBE_DONE fails=0`; verifies IDs/order, aliases, bestiary fields, deep-copy accessors, StoryData authority, and source-scan non-duplication.
- Full suite: `XDG_DATA_HOME=/tmp/kernel-panic-a4-full-xdg godot --headless --audio-driver Dummy --path . -- --autotest` — exit 0, `1414` `AT_PASS`, zero `AT_FAIL`, `AUTOTEST_ALL_PASS`.
- Changed files: `src/data/content_catalog.gd`, `src/autoload/game.gd`, `src/ui/bestiary_panel.gd`, `src/ui/achievements_panel.gd`, `tools/content_catalog_probe.gd`, `tools/content_catalog_probe.tscn`, and `report-A4.md`.
- Source authority: `ContentCatalog` owns programs, bestiary metadata/map, achievements/hints, patches/codes/relations/exclusions. `StoryData` remains the sole stage/act catalog. Compatibility constants are direct aliases; accessor methods deep-copy nested data.
- Alternatives: no `Resource` asset boundary, no UI consumer rewrite, no StoryData move, and no enemy constructor changes; all were unnecessary for behavior-preserving extraction.
- Compatibility/risk: public names and data order remain stable; save keys and gameplay are unchanged. Direct aliases are legacy read-only surfaces, while mutable consumers should use catalog accessors. Baseline teardown diagnostics remain open and are not attributed to A4.
- Commits: `b106be8` (focused test), `105d3bb` (refactor), and this docs commit.
- Independent review initially rejected the evidence: the probe did not prove
  full legacy-value parity, omitted `AchievementsPanel.ACHIEVEMENT_HINTS`,
  and covered only two of the defensive accessors. The controller strengthened
  `tools/content_catalog_probe.gd` with independent legacy fixtures, the
  missing alias assertion, and mutation checks for every accessor, including
  nested patch relations. A temporary catalog mutation produced exit 1 with
  two probe failures, then was reverted. Controller-fresh green evidence after
  the correction: focused probe exit 0 with `PROBE_DONE fails=0`; full suite
  exit 0 with 1414 passes, zero failures, and `AUTOTEST_ALL_PASS`.
- A4 is accepted after correction. Residual limitation: duplicate-source
  guards are lexical scans, not an AST proof; this is explicitly recorded in
  `report-A4.md`. No production data or gameplay behavior changed during the
  correction.

## A3 snapshot contracts

- Status: completed and adversarially corrected on 2026-09-01.
- Red probe: `XDG_DATA_HOME=/tmp/kernel-panic-a3-red-xdg godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn` — exit 1, 12 failures caused by the four absent methods and dependent assertions.
- Green probe (initial): `XDG_DATA_HOME=/tmp/kernel-panic-a3-green-xdg-3 godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn` — exit 0, 30 `PROBE_PASS`, 0 `PROBE_FAIL`, `PROBE_DONE fails=0`.
- Hanging-process diagnostic: after the interrupted run, no exact Godot processes remained. A clean reproduction exited in 1.1s. The probe now has an explicit 8s failure watchdog; forced red run with `KP_A3_FORCE_WATCHDOG=1` exited 2 with `PROBE_FAIL watchdog timeout`, and left no Godot processes.
- Full suite: `XDG_DATA_HOME=/tmp/kernel-panic-a3-full-xdg godot --headless --audio-driver Dummy --path . -- --autotest` — exit 0, `AT_PASS=1414`, `AT_FAIL=0`, `AUTOTEST_ALL_PASS`.
- Teardown diagnostics: 8 resources, 3 GodotArea2D RIDs, 14 dummy textures, 147 shaped-text allocations, 2 advanced-font allocations, 10 CanvasItem RIDs, and 171 ObjectDB instances; treated as baseline/open risk, not an A3 fix.
- Adversarial red: `XDG_DATA_HOME=/tmp/kernel-panic-controller-a3-patch-red2-20260901 godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn` — exit 1, 30 passes, 2 fails, `PROBE_DONE fails=2`, zero script errors.
- Adversarial green: `XDG_DATA_HOME=/tmp/kernel-panic-controller-a3-patch-green-20260901 godot --headless --audio-driver Dummy --path . res://tools/snapshot_contract_probe.tscn` — exit 0, 32 passes, 0 fails, `PROBE_DONE fails=0`, zero script errors.
- Changed files: `src/autoload/game.gd`, `src/autoload/sfx.gd`, `src/ui/menu.gd`, `src/arena/arena.gd`, `tools/snapshot_contract_probe.gd`, `tools/snapshot_contract_probe.tscn`, plus this report and ledger entry.
- Commits: `9092163` test probe; `c1a9b3d` production snapshot contracts; `9c5c112` explicit probe watchdog.
- Proven facts: all four real owners expose primitive-safe snapshots with schema metadata, required-field checks, deep-copy isolation, stable RNG/save/node counts, and no live-consumer migration. Drawing itself is not proven because no vNext renderer consumes the contracts.
- Alternatives: no shared Resource boundary, no UI consumer replacement, and no state ownership moved to kits; all rejected to preserve A3 scope and behavior.
- Assumptions/risks: entity-specific optional fields may grow later; optional-field tolerance needs explicit vNext consumer coverage; teardown noise remains open from W0.

## A5 migration, rollback and deprecation checkpoint

- Status: completed on 2026-09-01.
- Red probe: XDG_DATA_HOME=<isolated-dir> godot --headless --path . res://tools/save_compatibility_probe.tscn — exit 1 with SAVE_PROBE_DONE fails=2; malformed run/story objects reached typed Dictionary assignments in Game.import_save_string().
- Green probe: XDG_DATA_HOME=<isolated-dir> godot --headless --audio-driver Dummy --path . res://tools/save_compatibility_probe.tscn — exit 0 with SAVE_PROBE_DONE fails=0.
- Probe coverage: fresh profile; progressed story profile; missing and legacy optional keys; real-path export/import round-trip; malformed/truncated inputs; byte-for-byte preservation of the source save after each rejected import; 10-second watchdog; non-zero failure exit.
- Files: tools/save_compatibility_probe.gd, tools/save_compatibility_probe.tscn, and src/autoload/game.gd; report in report-A5.md.
- Bug fixed minimally: validate run, weekly, and story payload types before typed use or ConfigFile writes. No gameplay/UI behavior, save key, transfer version, or res:// path changed.
- Before/after: before, malformed structured input produced script errors; after, it returns false and leaves source bytes unchanged. Accepted import keeps current v1 normalization, so sparse story maps may canonicalize on re-export.
- Contract: Sfx.SAVE_PATH remains user://kernel_panic.cfg; Game.SAVE_TRANSFER_FORMAT remains kernel-panic-save; Game.SAVE_TRANSFER_VERSION remains 1. Existing public export/import helpers remain the runtime compatibility boundary.
- Deprecation/removal gate: do not remove or rename the helpers until a replacement has repository-wide zero-consumer evidence, real Menu/Arena scene-load coverage, save round-trip and invalid-import byte-preservation, input probe, full autotest, and rollback-route proof. Current status is runtime-reachable, not test-only or dead.
- Decision: no new schema or migrator. Current v1 already has defaults, legacy run.best fallback, known-ID filtering, and numeric normalization; another schema would add an unneeded authority and rollback surface.
- Full-suite gate: record a fresh godot --audio-driver Dummy --headless --path . -- --autotest run before accepting this checkpoint. Baseline reference remains 1414 AT_PASS, zero AT_FAIL, AUTOTEST_ALL_PASS, with known teardown diagnostics.
- Full suite: XDG_DATA_HOME=/tmp/kernel-panic-a5-full-xdg-2 godot --audio-driver Dummy --headless --path . -- --autotest — exit 0, AT_PASS=1414, AT_FAIL=0, AUTOTEST_ALL_PASS. Teardown diagnostics match baseline and remain open.
- Independent review rejected this first A5 result: nested `story.best`, `story.cleared`, `bestiary`, `programs`, and `achievements` containers could still be wrong types and be silently normalized; round-trip assertions were too narrow; write-failure injection was not available; and the A5 section had been appended after the checklist. The controller added the missing nested-type cases first: the probe went red with 10 failures, then changed `Game.import_save_string()` to validate every container before creating or saving the `ConfigFile` (`4e4beb2`).
- Controller-fresh nested green: `XDG_DATA_HOME=/tmp/kernel-panic-controller-a5-nested-green-20260901 timeout 20s godot --headless --audio-driver Dummy --path . tools/save_compatibility_probe.tscn` — exit 0, `SAVE_PROBE_DONE fails=0`. Full suite after the correction: exit 0, 1414 passes, zero failures, `AUTOTEST_ALL_PASS`, and the same baseline teardown diagnostics.
- Round-trip now includes weekly and bestiary sections and compares semantic story maps after sparse-map canonicalization. Write-error injection remains an explicit limitation: the current Godot `ConfigFile` path has no safe test seam for forcing a failed save without changing the production persistence boundary. No claim of write-failure coverage is made.
- A5 is accepted for current v1 compatibility after the nested-payload correction; the accepted scope is rejection-before-write and preservation of existing save bytes on invalid payloads. The write-failure seam remains a future reliability task, not silently considered solved.


## U1 vNext boot vertical slice

- Status: completed and adversarially corrected on 2026-09-01.
- Initial red probe: the first focused contract run failed because the new surface was absent; after the initial implementation, the first independent review rejected false-green action dispatch, missing real controls, hardcoded overflow, fixed narrow geometry, and absent menu integration.
- Controller correction red: strengthened real-input assertions initially exited 1 because pointer coordinates were in stretch/window space and the surface/menu fallback could duplicate or miss Button activation. This was fixed before acceptance.
- Final boot probe: `env XDG_DATA_HOME=/tmp/kernel-panic-u1-real-input4-20260901 godot --headless --audio-driver Dummy --path . res://tools/vnext_boot_probe.tscn` exited 0 with `PROBE_DONE fails=0`; covers `1366×768`, `720×720`, `432×720`, safe-area containment, measured text, context flags, focus, real Button focus, and exactly-one activation through viewport ENTER/mouse/touch.
- Final menu probe: `KP_VNEXT_BOOT=1 env XDG_DATA_HOME=/tmp/kernel-panic-u1-menu5-20260901 godot --headless --audio-driver Dummy --path . res://tools/vnext_menu_probe.tscn` exited 0 with `PROBE_DONE fails=0`; covers opt-in routing, simulated `432×720` reconfiguration, safe width, focus preservation, and one real boot action.
- Full suite: `env XDG_DATA_HOME=/tmp/kernel-panic-u1-full-20260901 godot --headless --audio-driver Dummy --path . -- --autotest` exited 0 with `1414` passes, zero failures and `AUTOTEST_ALL_PASS`.
- Files: new `ui_context.gd`, `ui_layout.gd`, `ui_navigation.gd`, `surfaces/boot_surface.gd`, both probes; `src/ui/menu.gd` has only an explicit `KP_VNEXT_BOOT=1` route and its integration hooks. Production commits: `830a5bb`; probe hardening commit: `4974c95`.
- Decisions: one `Rect2` action registry feeds drawing/input/focus; transparent native Buttons own concrete activation; the opt-in root BACK exits explicitly because no prior vNext route exists; legacy menu remains default; pointer input is normalized through the stretch transform; legacy `_process` is skipped in opt-in mode.
- Independent review: first reviewer rejected; controller fixed every blocker/high finding. Second Luna reviewer accepted. Detailed evidence, rejected approaches, compatibility impact and limitations are in `report-U1.md`.
- Risks: the opt-in slice is not the final visual UI; BACK is temporary root-exit semantics; accessibility context is API groundwork rather than persisted preferences; translated/high text-scale variants and native screen readers remain future work; baseline teardown diagnostics remain open.

## U2 vNext program and story selection

- Status: accepted on 2026-09-01 after three independent Luna review passes;
  two rejected concrete gaps and the controller corrected them before the
  final acceptance pass.
- Production commits: `d1b1db8` (program/story routes and boot extension).
- Test commits: `018b1b7` (initial red selection probe), `35a8671` (hardened
  selection/Menu evidence), `e7628bb` (boot typography and overflow evidence).
- Production files: `src/ui/menu.gd`,
  `src/ui/vnext/surfaces/boot_surface.gd`,
  `src/ui/vnext/surfaces/program_surface.gd`,
  `src/ui/vnext/surfaces/story_surface.gd`, and
  `src/ui/vnext/ui_layout.gd`. Test files: `tools/vnext_boot_probe.gd`,
  `tools/vnext_selection_probe.gd`, and `tools/vnext_menu_probe.gd`.
- Scope: opt-in boot→program/story routes; program list/detail contract;
  story act tabs/stage list/briefing contract; locked and ready states;
  keyboard, native Button, pointer and touch action mapping; narrow
  list/detail states; project fonts; full overflow report; Menu resize and
  no-fall-through route checks.
- Narrow composition decision: the phone layout uses mutually exclusive list
  and detail states with an explicit list-return action. It does not make the
  desktop two-column/map composition smaller and hope it remains readable.
- Ownership decision: Game/StoryData remain the content/progression source of
  truth; the surfaces project state and emit launch commands; Menu remains the
  route/gameplay boundary.
- Input decision: native Buttons own concrete GUI activation; matching
  `gui_input` event IDs are consumed by the surface fallback to prevent
  duplicate activation. The same logical action registry is used for custom
  pointer/touch hit testing and semantic inspection.
- Typography decision: Orbitron is used for titles/identity; ShareTechMono is
  used for body/control text. The earlier boot `ThemeDB.fallback_font` usage
  and missing PROGRAMS/STORY overflow entries were rejected and corrected.
- Red evidence: the first real Menu BACK assertion failed with
  `program real back is owned by Button`; the focus assertion then failed to
  focus/update a story act tab; the responsive hardening probe failed on the
  missing narrow list/detail state; the second review found the boot font and
  overflow gap. These failures were fixed in production and not hidden by
  weakening the checks.
- Final focused evidence:
  `vnext_boot_probe` exit 0 / `PROBE_DONE fails=0`;
  `vnext_selection_probe` exit 0 / `PROBE_DONE fails=0`;
  `vnext_menu_probe` exit 0 / `PROBE_DONE fails=0`;
  existing `layout_probe` exit 0 / `PROBE_RESULT passes=130 fails=0`.
  All were run with `godot --headless --audio-driver Dummy` and isolated
  `XDG_DATA_HOME` values.
- Full-suite evidence after U2: exit 0, `1414` `AT_PASS`, `0` `AT_FAIL`,
  `AUTOTEST_ALL_PASS`. Import verification also exited 0.
- Review outcome: final Luna reviewer accepted after verifying boot fonts and
  complete overflow entries, responsive list/detail, input/focus/duplicate
  dispatch, Menu route/resize behavior and the existing layout probe.
- Known risks: opt-in only and not final visual approval; English-only
  overflow evidence at text scale 1.15; no persisted accessibility settings;
  no physical-device pointer/touch playtest; no complete route-stack
  cancellation; Android export remains unproven; W0 teardown diagnostics
  remain open. These are not silently marked solved by U2.
- Next task: U2b patch offer/build decision surface. It must preserve the
  snapshot/action/overflow discipline and add confirm/skip/close/conflict,
  resize and paused-overlay recovery evidence.

## U2b vNext patch/build decision surface

- Status: accepted on 2026-09-01 after controller correction and an
  independent Luna review.
- Initial red commit: `7154876` added the focused patch probe. Initial feature
  commit: `b2f6f6b` added the first opt-in surface. The first green-looking
  result was rejected because the surface was not integrated with Arena,
  desktop showed one offer, empty confirmation was possible, narrow footer
  controls overlapped, state/data semantics were incomplete, and resize/input
  evidence was artificial.
- Controller red hardening then added the real decision-data, state,
  non-overlap, empty/locked, retry, resize and GUI-routing assertions. A real
  Arena probe was added before the adapter integration and failed with three
  missing-route checks.
- Production scope: `src/ui/vnext/surfaces/patch_surface.gd`,
  `src/arena/arena.gd`, `src/arena/panel_kit.gd`. Probe/tooling scope:
  `tools/vnext_patch_probe.gd`, `tools/vnext_patch_arena_probe.gd`,
  `tools/vnext_patch_arena_probe.tscn`, and
  `tools/validate_input_dispatch.sh`.
- Surface contract: deep-copied normalized snapshot, project fonts/tokens,
  desktop parallel cards, narrow one-card navigation, native Buttons, shared
  action geometry, keyboard/mouse/touch, exactly-once final commands, safe
  area, resize reflow and measurable overflow. It emits commands only.
- Adapter contract: Arena owns pause and `Game.apply_patch()`. The opt-in
  `KP_VNEXT_PATCH=1` route handles real ESC close, Skip and Confirm while the
  simulation is paused; Confirm validates index and offer identity, and
  close/skip defer queued-offer work to avoid reentrancy. The legacy route is
  unchanged when the flag is absent.
- State decision: `TRADEOFF` remains a selectable warning because the current
  heavy+splitshot relation is not a gameplay lock. Locked and unavailable
  states are explicit and non-confirmable. This does not invent a new balance
  rule.
- Content decision: Arena preserves explicit effect/cost/build/state fields;
  current catalog descriptions are the canonical effect text and patch offers
  have no resource cost. Before/after build codes are computed from a copied
  level map without emitting gameplay signals.
- Controller-fresh surface evidence:
  `env XDG_DATA_HOME=/tmp/kernel-panic-u2b-green-surface4-20260901 godot
  --headless --audio-driver Dummy --path .
  res://tools/vnext_patch_probe.tscn` — exit 0, `PROBE_DONE fails=0`.
- Controller-fresh real Arena evidence:
  `KP_VNEXT_PATCH=1 XDG_DATA_HOME=/tmp/kernel-panic-u2b-green-arena11-20260901
  godot --headless --audio-driver Dummy --path .
  res://tools/vnext_patch_arena_probe.tscn` — exit 0,
  `PROBE_DONE fails=0`; covers open/pause/ESC close/reopen/skip/reopen/confirm
  and exactly one patch application.
- Full-suite evidence after U2b: exit 0, `1414 AT_PASS`, `0 AT_FAIL`,
  `AUTOTEST_ALL_PASS`; import/editor scan exit 0; `git diff --check` clean.
- Review outcome: the first Luna review rejected the initial result; the
  controller corrected the findings. The second Luna review accepted the
  corrected implementation and verified the focused probes, real Arena input,
  data/state projection, responsive geometry, retry path and legacy default.
- Residuals: no final visual approval; oversized arbitrary/localized copy is
  detected but not scrollable; PT-BR, persisted accessibility, physical-device
  mobile, Android export and W0 teardown diagnostics remain open. The Arena
  probe intentionally reports additional exit-time resource/RID/ObjectDB
  diagnostics because it creates a live Arena directly.
- Detailed report: `.superpowers/sdd/00-MASTER-PLAN/report-U2b.md`.
- Versioned handoff: `docs/HANDOFF-U2B-PATCH-DECISION.md`.
- Next task: U3 combat HUD. Keep U2b opt-in available as a regression surface.

## U3 vNext combat HUD

- Status: implemented and verified on 2026-09-01; opt-in only.
- Red probe: `tools/vnext_combat_hud_probe.gd` initially failed because the
  combat surface script was absent. Green result: exit 0,
  `PROBE_DONE fails=0`, including real Arena mounting.
- Production scope: `src/ui/vnext/surfaces/combat_hud_surface.gd`,
  `src/ui/hud.gd` adapter and `src/arena/arena.gd` integration methods.
  Tooling scope: focused probe and validation-script entry.
- Surface contract: code-drawn responsive zones, cached layout/semantic state,
  defensive public snapshots, overflow report, touch-safe dash action and
  explicit non-color state markers. `PROCESS_MODE_ALWAYS` is limited to UI
  input/lifecycle; no gameplay polling loop was added.
- Compatibility: legacy HUD rendering, fields, API and gameplay ownership stay
  unchanged unless `KP_VNEXT_HUD=1` is explicitly set. No balance file was
  touched.
- Evidence: 1–12 HP, empty/full meter, ready/cooldown dash, fixed wave/boss
  state, long event text, 432×720/1280×720/1920×720, center reservation,
  boss/player separation, resize and Arena integration all passed.
- Review ruling: first green result was rejected after an independent review
  found fullscreen pointer interception, an empty split-boss bar, desktop and
  narrow overlap, stale patch labels, weak overflow measurement, cycle
  duplication and a missing damage source. Correction checks then passed:
  `MOUSE_FILTER_IGNORE`, live fragment bars, dedicated boss row, measured
  per-field overflow, temporary banner projection, real Player damage vector
  and input/lifecycle compatibility. Teardown resource/RID/ObjectDB
  diagnostics remain the W0 baseline residual. Visual quality still needs
  human art review and physical touch validation.
- Correction evidence: focused U3 probe exit 0, 48 checks,
  `PROBE_DONE fails=0`; full legacy suite remains 1414 `AT_PASS`, 0
  `AT_FAIL`, `AUTOTEST_ALL_PASS`. Generated files stayed untracked.
- Validation safety: `tools/validate_input_dispatch.sh` now bounds every
  Godot/probe/Xvfb invocation with `KP_VALIDATION_TIMEOUT_SECONDS` (default
  120 s); timeout exit codes remain gating and missing markers remain failures.
- Detailed report: `.superpowers/sdd/00-MASTER-PLAN/report-U3.md`.
- Versioned handoff: `docs/HANDOFF-U3-COMBAT-HUD.md`.
- Next task: U4 pause, terminal and game over; do not expand U3 into U4+.

## U4 vNext pause, terminal and game-over surfaces

- Status: accepted on 2026-09-01 after an initial red probe, one independent
  Luna review, controller corrections and a second review pass.
- Initial red commit: `4e96c58` added the U4 state-surface probe and showed the
  first concrete failure: Q confirmation did not arm through the real route.
  Investigation proved the probe had sent `rm -rf /` first, which killed the
  Player and made `_state != "play"`; the probe was reordered rather than the
  production guard being weakened.
- Production commit: `d00a7e6` adds the opt-in adapter, three surfaces, the
  hardened probe and accumulated validator entry. No default legacy route was
  changed when `KP_VNEXT_U4` is absent.
- Production files: `src/ui/vnext/surfaces/pause_surface.gd`,
  `terminal_surface.gd`, `game_over_surface.gd`, plus U4 integration in
  `src/arena/arena.gd`. Probe: `tools/vnext_state_surfaces_probe.gd` and its
  scene. Validator: `tools/validate_input_dispatch.sh`.
- Ownership decision: Arena owns `_state`, pause, Q confirmation, terminal
  commands and transitions. Surfaces own drawing, native Controls, focus and
  action emission. One `CanvasLayer` parent is used for every replacement;
  gameplay nodes never receive `PROCESS_MODE_ALWAYS` from U4.
- Responsive decision: pause keeps four touch-sized actions; terminal stacks
  event stream/index/status in narrow mode and adapts its title; game-over
  stacks primary/menu buttons in narrow mode. A desktop two-column layout is
  not merely shrunk into 432 px.
- Review findings converted to red checks: invisible Controls after refresh,
  overflow report that could stay green with actual overflow, Q dispatch
  fallback that masked routing, narrow terminal title clipping, narrow
  game-over button overlap, stale terminal semantic history, misleading
  victory labels, inconsistent surface parent and deferred focus after free.
  All were corrected before acceptance.
- Probe scope: real Arena mounting, real `Viewport.push_input`, ESC opening
  and closing pause, pause freeze, visible/focusable Controls, terminal
  `LineEdit`, ENTER, TAB completion, UP/DOWN history, focused ESC, Q arm and
  expiration, Arena-owned `rm -rf /`, death/victory semantics and labels,
  plus safe layout and actual field overflow at 432×720, 720×720 and
  1280×720.
- Focused evidence: headless U4 exit 0, `71` passes, `0` fails and
  `PROBE_DONE fails=0`; Xvfb U4 same result. No `SCRIPT ERROR` or focus
  condition error remained after the focus correction.
- Accumulated evidence: validator exit 0 / `VALIDATION OK`; suite `1414`
  `AT_PASS`, `0 AT_FAIL`, `AUTOTEST_ALL_PASS`; input headless `32/0`, Xvfb
  `34/0`; R04/R05/R06/R07/R08/B1/B2/B5/R18 and all previous vNext probes
  green. Teardown resources/RIDs/ObjectDB/text shaping remain reported and
  non-gating as in W0.
- Review of reboot blocker: the reviewer suspected `_state="dead"` could
  persist after retry. Direct inspection of `Game.start_run()` showed it
  restores `Game.state`, unpauses and schedules a new `Arena` scene; the dead
  `_state` belongs to the replaced node. Existing R03 tests cover the full
  scene transition, while U4 verifies the immediate global state. No
  speculative common-runtime change was made.
- Known risks: no human visual approval, PT-BR, persisted accessibility,
  native screen reader, physical mobile, Android export or final performance
  gate. The U4 slice remains opt-in and the `rm -rf /` death transition is
  not a license to alter gameplay semantics.
- Detailed report: `.superpowers/sdd/00-MASTER-PLAN/report-U4.md`.
- Versioned handoff: `docs/HANDOFF-U4-STATE-SURFACES.md`.
- Next task: U5 accessibility/settings surface. Preserve U4 as an opt-in
  regression route and keep localized/large-text checks ahead of promotion.

## Review checklist for every task

- Read the micro-plan and current code, then inspect shared interfaces.
- Add/adjust a focused failing probe before production code where behavior changes.
- Implement the smallest compatible change; do not opportunistically rewrite unrelated code.
- Run focused verification and relevant regression suite with Dummy audio.
- Re-read the diff as an adversarial reviewer: lifecycle, paused input, save compatibility, responsive geometry, localization, performance, error paths.
- Record proven facts, assumptions, residual risks, and validation method here and in the relevant handoff/release document.
- Commit only explicit task paths; keep unrelated user artifacts out of the commit.

## U5 vNext Settings / Accessibility

- Status: implemented on `codex/plan-execution`, opt-in via
  `KP_VNEXT_SETTINGS=1`; legacy Settings/menu remain default.
- Red evidence: focused probe before production, exit 1 with 12 expected
  failures.
- Production: Sfx schema-2 profile boundary with defaults, normalization,
  apply/reset/reload and same-file ConfigFile persistence; accessibility-first
  code-drawn surface with real controls and Menu route integration.
- Final pre-review probe evidence: headless and Xvfb exit 0 with 59 passes,
  `PROBE_DONE fails=0`; layouts cover 1366×768, 720×720, 432×720 and 390×844.
- Regression evidence: import exit 0, full suite 1414 `AT_PASS` / 0 `AT_FAIL`
  with `AUTOTEST_ALL_PASS`, accumulated validator `VALIDATION OK`.
- Review ruling: fixed persistence-failure restoration semantics and moved
  status/note out of action regions; no unsupported inert controls added.
- Not proven: real permission/disk-full filesystem failure, physical touch/Android, native screen
  reader, text scaling, high contrast, reduced flash, gamepad, PT-BR, visual
  approval, device performance and existing teardown diagnostics.
- Report: `.superpowers/sdd/00-MASTER-PLAN/report-U5.md`.
- Handoff: `docs/HANDOFF-U5-SETTINGS-ACCESSIBILITY.md`.
- Commits: `f435c03` production; `0d980dc` probe/accumulator; docs commit
  follows this update.

### U5 post-review correction

- Independent Luna review rejected the first U5 checkpoint: the Sfx loader
  assigned malformed ConfigFile values directly into typed fields; the UI
  status claimed an applied value after rollback; preservation fixtures were
  too weak; and save failure had not been executed.
- Controller correction: loader now normalizes the four profile fields on disk
  load; failed apply/reset restores previous memory and the surface says so;
  the fixture contains pre-existing progress, feel and audio keys; a private
  `_settings_path_override` seam forces a deterministic invalid `ConfigFile`
  save path only in the probe. No user-facing save path changed.
- Corrected focused probe: headless and Xvfb `66 PROBE_PASS`, zero failures,
  marker present, zero script/runtime errors. The probe now covers malformed
  disk-load normalization, stronger preservation and failed-save rollback/status.
- Corrected U5 acceptance: focused headless/Xvfb probes both `66/0`; final
  full suite `1414/0` with marker; accumulated validator `VALIDATION OK`; no
  gating script/runtime errors; `git diff --check` clean. The independent
  reviewer accepted the route/input/layout scope and identified the recovery
  gaps; the controller then fixed and reverified those gaps locally. Real
  storage faults, Android/touch hardware, native assistive tech, localization,
  visual approval and teardown diagnostics remain explicitly outside the
  evidence.
- Commits now pushed: `f435c03`, `0d980dc`, `4500538`, `1de633f`.

### E3 — program identity runtime slice

- Status: implemented on `codex/plan-execution`; vNext remains opt-in.
- Fixed confirmed adapter bug: because `PROGRAM_DEFS` has no `kind`, the old
  real-player path defaulted DAEMON and ROOTLET to KERNEL. Added stable
  `program_id -> kind` mapping and a read-only `Player.presentation_snapshot()`.
- Routed real overclock, dash and shield facts into the program selector,
  combat HUD and pause semantics; removed fragile silhouette-string mapping.
- Focused red probe: exit 1 with 16 failures before production. The first green
  result was deliberately rejected by adversarial review for non-canonical
  ROOTLET color, snapshot bypasses in Combat HUD drawing, insufficient
  consumer draw coverage and an unused HUD preload.
- Final probe after those corrections: headless/Xvfb exit 0, 35 passes, 0
  fails, exact completion marker. It compares canonical catalog colors,
  captures Combat HUD draw text, checks pause context projection, and measures
  narrow overflow.
- Additional checks: import exit 0; full suite exit 0 with 1414 AT_PASS, 0
  AT_FAIL and AUTOTEST_ALL_PASS; accumulated validator final VALIDATION OK,
  including E3 35/0 and no runtime ERROR gates.
- The first accumulated run was rejected for a malformed completion marker;
  `b6e6eaa` corrected the probe and the validator was rerun.
- Not proven: human visual approval, dense-wave profiling, Android/device/
  physical touch, Vega, PT-BR, native screen reader and teardown diagnostics.
- Report: `.superpowers/sdd/00-MASTER-PLAN/report-E3-program-identity.md`.
- Handoff: `docs/HANDOFF-E3-PROGRAM-IDENTITY.md`.
- Commits: `f5a3669`, `88313c2`, `b6e6eaa`, plus the adversarial correction
  and documentation commits that follow.
