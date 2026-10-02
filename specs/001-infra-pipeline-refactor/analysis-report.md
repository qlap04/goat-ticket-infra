# Specification Analysis Report — 001-infra-pipeline-refactor

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| C1 | Inconsistency | HIGH | spec.md FR-005 / Edge Cases; plan.md research.md decision 2; tasks.md T015 | FR-005 and the spec's edge case ("pipeline is started with an environment value that is neither dev nor prod") imply a runtime/queue-time input a caller can mistype. The chosen design (research.md decision 2) makes `environment` a **compile-time-only** template parameter, hardcoded by the two fixed instantiations (`dev`, `prod`) the main pipeline authors into the YAML — there is no live input surface for an operator to ever supply an unsupported value at trigger time. T015 ("run the pipeline... with the environment parameter set to an unsupported value") is therefore not executable as written; the only real path to an invalid value is a future YAML-authoring typo, caught later by Bicep's `@allowed(['dev','prod'])` at Validate time, not by any pipeline-level guard. | Rewrite T015 to test the actual mechanism: manually add a third, malformed template instantiation (e.g. `environment: stagng`) and confirm the Quality Checks stage's Validate step fails via Bicep's `@allowed` constraint *before* any Deploy stage runs — and reword FR-005/the edge case in spec.md to describe this as an authoring-time safeguard rather than a runtime input validation, so the acceptance criterion matches the design it's meant to gate. |
| C2 | Coverage Gap | MEDIUM | spec.md SC-002; tasks.md T012-T016 | SC-002 claims "supporting an additional environment beyond dev and prod requires adding one new variable file, with no changes to the pipeline's stage definitions." No task actually exercises this — all US2 tasks only add/validate the dev and prod paths. The claim is architecturally plausible (one more template instantiation + one more `.bicepparam` file) but is never proven. | Add a task (or a quickstart.md scenario + task) that temporarily instantiates `deploy-environment.yml` with a third environment value and a throwaway variable file, confirms it works with zero edits to stage *definitions*, then removes the throwaway instantiation — or explicitly scope SC-002 down to "the design is structured to make this possible" if proving it isn't worth the effort for this feature. |
| C3 | Coverage Gap | MEDIUM | spec.md SC-008; tasks.md T031 | SC-008 requires "100% of existing principal access grants... produce identical effective access... after the refactor." T031 only validates adding/removing one *throwaway* test principal via what-if; it never explicitly confirms that running what-if with today's real, unmodified principal set (`appServicePrincipalId`, `agwIdentityPrincipalId`, `functionAppPrincipalId`) produces **zero diff** against the pre-refactor deployment state. | Extend T031 (or add a dedicated task) to run `az deployment sub what-if` against the refactored RBAC module with the current production principal set and assert the output shows no changes — this is the actual evidence SC-008 needs for RBAC, distinct from the add/remove-a-test-principal check. |
| F1 | Inconsistency | MEDIUM | tasks.md Dependencies & Execution Order / Suggested Team Split; T014; T023 | The Dependencies section states "User Story 4 (Phase 6): Depends on Foundational only... independent of US2/US3's deploy-stage changes," and the Suggested Team Split puts US2 and US4 on different engineers working in parallel. But T014 (US2) and T023 (US4) both edit the same file, `deploy/pipeline/azure-pipelines-infra.yml` — US2 replaces the `DeployDev`/`DeployProd` stage bodies while US4 replaces the `Lint`/`Validate`/`SecurityScan`/`WhatIf` stages. Logically independent, but not conflict-free in practice. | Either note in tasks.md that T014 and T023 touch the same file and should be sequenced or merged carefully (e.g., same engineer, or merge one before starting the other), or split `azure-pipelines-infra.yml`'s stage list editing into a single task so only one person edits that file at a time. |
| B1 | Ambiguity | LOW | plan.md Technical Context → Performance Goals | "must not materially increase total pipeline run time" has no measurable threshold (no % or minute bound). | Either drop the claim (it's not spec-mandated) or state a concrete bound, e.g. "total Quality Checks stage duration stays within 10% of the sum of the four stages it replaces." |
| B2 | Ambiguity | LOW | spec.md SC-001 | "within seconds" is a soft, unmeasured precision claim carried over from the original spec. | No action required before implementation — flagging for awareness only; not blocking since no task depends on a stricter number. |

## Coverage Summary — Functional Requirements

| Requirement Key | Has Task? | Task IDs | Notes |
|---|---|---|---|
| FR-001 | Yes | T001–T005 | |
| FR-002 | Yes | T007 | |
| FR-003 | Yes | T012, T014 | see C1 for a design/wording mismatch, not a missing task |
| FR-004 | Yes | T012, T014, T016 | |
| FR-005 | Partial | T015 | see C1 — task as written doesn't match the compile-time design |
| FR-006 | Yes | T037 | |
| FR-007 | Yes | T038 | |
| FR-008 | Yes | T018 | |
| FR-009 | Yes | T017–T019 | |
| FR-010 | Yes | T023 | |
| FR-011 | Yes | T023, T024 | |
| FR-012 | Yes | T025, T026 | |
| FR-013 | Yes | T027, T029 | |
| FR-014 | Yes | T028, T029 | |
| FR-015 | Yes | T027–T029 | |
| FR-016 | Yes | T027–T029, T031 | |
| FR-017 | Yes | T032 | |
| FR-018 | Yes | T035 | |
| FR-019 | Yes | T020–T022, T040–T042 | |
| FR-020 | Yes | T031, T036, T011 | |

## Coverage Summary — Success Criteria

| Requirement Key | Has Task? | Task IDs | Notes |
|---|---|---|---|
| SC-001 | Yes | T009, T010 | B2: wording imprecise but not blocking |
| SC-002 | Partial | T012–T016 | see C2 — claim never actually exercised |
| SC-003 | Yes | T019 | |
| SC-004 | Yes | T023, T024 | |
| SC-005 | Yes | T026 | |
| SC-006 | Yes | T031 | |
| SC-007 | Yes | T036 | |
| SC-008 | Partial | T031, T036 | see C3 — RBAC baseline-parity not fully proven |
| SC-009 | Yes | T039 | |
| SC-010 | Yes | T042 | |

## Constitution Alignment Issues

None — `.specify/memory/constitution.md` is still the unfilled placeholder template (no ratified principles), so there is nothing to check against. This is reported as an absence, not a pass.

## Unmapped Tasks

None. T001–T008 (Setup/Foundational) and T043–T045 (Polish) are intentionally story-unlabeled per the task-generation rules but each traces to FR-001/FR-002 (structure) or serves as cross-cutting validation (T045 explicitly checks every FR).

## Metrics

- Total Requirements: 30 (20 FR + 10 SC)
- Total Tasks: 45
- Coverage %: 100% have ≥1 task; 93% (28/30) fully proven as worded, 7% (2/30 — SC-002, SC-008) partially proven; FR-005 is the one requirement whose single task doesn't match its design (counted above as "Partial")
- Ambiguity Count: 2 (both LOW)
- Duplication Count: 0
- Critical Issues Count: 0

## Next Actions

No CRITICAL issues. One HIGH (C1) is worth resolving before `/speckit-implement` reaches T015/US2, since otherwise that task will be executed in a way that doesn't actually prove what FR-005 asks for. The two MEDIUM coverage gaps (C2, C3) and the MEDIUM task-coordination note (F1) can be addressed either now or acknowledged and carried forward — none block starting implementation on Phases 1–3 (Setup, Foundational, US1).

Suggested concrete steps:
- Resolve C1 by editing spec.md's FR-005/Edge Case wording *or* tasks.md T015 (pick one — they currently disagree on what's being tested)
- Extend tasks.md T031 per C3 before implementing US6
- Decide whether to act on C2 before or after shipping US2, or explicitly descope SC-002's proof
- Note F1 in tasks.md (or just sequence T014/T023 with the same person) before parallelizing US2/US4
