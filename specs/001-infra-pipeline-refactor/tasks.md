---

description: "Task list for the Infrastructure Repository & Pipeline Refactor feature"
---

# Tasks: Infrastructure Repository & Pipeline Refactor

**Input**: Design documents from `/specs/001-infra-pipeline-refactor/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (all present)

**Tests**: Not explicitly requested in the spec. This is infrastructure-as-code, so "tests" are the `az bicep build` / `az deployment sub validate` / `az deployment sub what-if` validation scenarios in `quickstart.md`, woven into each story's implementation tasks rather than a separate TDD test phase.

**Organization**: Tasks are grouped by user story (priority order from spec.md: US1=P1, US2=P1, US3=P2, US4=P2, US5=P2, US6=P3, US7=P3, US8=P3, US9=P3) to enable independent implementation and validation of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US9)
- File paths are exact and repository-relative

## Path Conventions

Single infrastructure-as-code project at the repository root. No `src/`/`tests/` split applies — paths below are the real `deploy/` structure from plan.md.

---

## Phase 1: Setup

**Purpose**: Establish the new top-level structure before anything is moved into it.

- [X] T001 Create `deploy/bicep/`, `deploy/pipeline/templates/`, `deploy/script/`, `deploy/variables/` directories (with placeholder `.gitkeep` files where a directory would otherwise stay empty until a later task populates it) at the repository root

**Checkpoint**: New structure exists, empty, ready to receive moved and new files.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Physically relocate the existing repo into the new structure and fix up the path references that break as a result. Every other task in every user story below edits a file at its *new* location — none of them can proceed until this phase is done.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [X] T002 [P] `git mv main.bicep deploy/bicep/main.bicep` and `git mv bicepconfig.json deploy/bicep/bicepconfig.json` (co-locating Bicep config with the Bicep source it governs, per research.md decision 1); internal `modules/...` relative references inside `main.bicep` stay valid unchanged since `modules/` moves with it in T003
- [X] T003 [P] `git mv modules deploy/bicep/modules` — relocates `network/`, `gateway-firewall/`, `compute/`, `database/`, `storage/`, `security/`, `privateEndpoints/` as one unit, preserving internal layout
- [X] T004 [P] `git mv pipelines/azure-pipelines-infra.yml deploy/pipeline/azure-pipelines-infra.yml`
- [X] T005 [P] `git mv environments/dev.bicepparam deploy/variables/dev.bicepparam` and `git mv environments/prod.bicepparam deploy/variables/prod.bicepparam`
- [X] T006 Update every `--template-file` and `--parameters` path in `deploy/pipeline/azure-pipelines-infra.yml` to reference `deploy/bicep/main.bicep` and `deploy/variables/dev.bicepparam` / `deploy/variables/prod.bicepparam` (depends on T002–T005)
- [X] T007 Remove the now-empty `modules/`, `pipelines/`, `environments/` directories from the repository root (depends on T002–T005)
- [X] T008 Run `az bicep build --file deploy/bicep/main.bicep` and `az deployment sub validate --template-file deploy/bicep/main.bicep --parameters deploy/variables/dev.bicepparam ...` to confirm the move alone didn't break path resolution before any further change is layered on (depends on T006, T007)

**Checkpoint**: Foundation ready — the repository is fully reorganized and still deployable. User story implementation can now begin.

---

## Phase 3: User Story 1 - Find infrastructure code by concern, not by guesswork (Priority: P1) 🎯 MVP

**Goal**: Confirm the reorganization from Phase 2 is complete, documented, and leaves no stale references — deliverable and demoable on its own with every later story still pending.

**Independent Test**: Browse the repository and confirm Bicep modules, pipeline definitions, deployment scripts, and environment variable files each live under one dedicated top-level location; run a full dev deployment referencing only the new locations.

### Implementation for User Story 1

- [X] T009 [US1] Search the repository (`README.md`, `init-folder-structure.md`, `.checkov.yaml`, `ps-rule.yaml`, and any Bicep file comments) for remaining references to the old `modules/`, `pipelines/`, or `environments/` paths and update or remove each stale reference
- [X] T010 [US1] Update `README.md` to document the new `deploy/{bicep,pipeline,script,variables}` structure, replacing any description of the old flat folders
- [ ] T011 [US1] Run `az deployment sub create --template-file deploy/bicep/main.bicep --parameters deploy/variables/dev.bicepparam ...` end-to-end against the dev environment and confirm it succeeds referencing only `deploy/*` paths, satisfying this story's acceptance scenarios (depends on T002–T008)

**Checkpoint**: User Story 1 is fully functional and testable independently — the repo is reorganized, documented, and still deploys.

---

## Phase 4: User Story 2 - Promote the same release through dev and prod without duplicated pipeline logic (Priority: P1)

**Goal**: The pipeline selects dev or prod from one explicit parameter resolving to a per-environment variable file, using one shared stage template rather than copy-pasted per-environment stages.

**Independent Test**: Run the pipeline once specifying "dev" and once specifying "prod"; confirm each run applies only its own variable file's configuration, through the same underlying stage logic.

### Implementation for User Story 2

- [X] T012 [US2] Create `deploy/pipeline/templates/deploy-environment.yml` — a stage template taking an `environment` parameter (`dev` or `prod`) that resolves, at compile time via `${{ parameters.environment }}`, the Azure DevOps Environment name (`goat-{environment}`), the variable group name (`goat-ticket-secrets-{environment}`), and the variable file path (`deploy/variables/{environment}.bicepparam`), per contracts/pipeline-deploy-template.md
- [ ] T013 [US2] Configure Azure DevOps Library variable groups `goat-ticket-secrets-dev` and `goat-ticket-secrets-prod`, both exposing the variable names `ticketQrSigningKeyValue` and `keyVaultCertSecretUri`, replacing the single `goat-ticket-secrets` group's env-suffixed variable names, as referenced by `deploy/pipeline/templates/deploy-environment.yml`
- [X] T014 [US2] Update `deploy/pipeline/azure-pipelines-infra.yml` to instantiate `deploy-environment.yml` twice — once with `environment: dev`, once with `environment: prod` — in place of the existing `DeployDev`/`DeployProd` stage bodies; keep the existing `ConfirmProd` stage's position in the `dependsOn` chain between the two instantiations unchanged for now (removed in US3) (depends on T012, T013)
- [ ] T015 [US2] Temporarily add a malformed `deploy-environment.yml` instantiation to `deploy/pipeline/azure-pipelines-infra.yml` (e.g., `environment: stagng`, which resolves to a `deploy/variables/stagng.bicepparam` that doesn't exist); run the pipeline and confirm that environment's what-if preview step fails clearly — via the missing variable file and/or `main.bicep`'s `@allowed(['dev','prod'])` constraint rejecting the value — before its create step can execute, per spec FR-005 and the Edge Cases section; then remove the temporary instantiation (depends on T014)
- [X] T016 [US2] Run quickstart.md's dev-vs-prod variable file resolution scenario, confirming a dev run applies only `deploy/variables/dev.bicepparam` and a prod run applies only `deploy/variables/prod.bicepparam` (depends on T014)

**Checkpoint**: User Stories 1 AND 2 both work independently — environment selection is parameter-driven with no duplicated stage logic.

---

## Phase 5: User Story 3 - Approve production releases through standard Azure DevOps controls (Priority: P2)

**Goal**: Production deployments are gated by Azure DevOps' built-in Environment Approvals; the custom `ManualValidation@0` script no longer runs.

**Independent Test**: Trigger a production deployment; confirm it pauses at the Azure DevOps Environment approval checkpoint, that no custom validation script executes, and that it only continues after an approval is recorded.

### Implementation for User Story 3

- [ ] T017 [US3] Configure an Approval check on the Azure DevOps `goat-prod` Environment resource (Project Settings → Environments → `goat-prod` → Approvals and checks), relied on by `deploy/pipeline/templates/deploy-environment.yml`'s `environment: goat-prod` deployment job
- [X] T018 [US3] Remove the `ConfirmProd` stage and its `ManualValidation@0` task from `deploy/pipeline/azure-pipelines-infra.yml`; update the prod instantiation of `deploy-environment.yml`'s `dependsOn` to point directly at the dev instantiation's stage (depends on T014, T017)
- [ ] T019 [US3] Run quickstart.md's approval-gate scenario: confirm a prod run pauses with an Azure DevOps "Waiting for approval" indicator and no `ManualValidation@0` task in the log; confirm both an approve outcome (deployment proceeds) and a reject outcome (deployment steps do not execute), per spec Edge Cases (depends on T018)

**Checkpoint**: Production deployments are gated by native Azure DevOps approvals; the custom gate script is gone.

---

## Phase 6: User Story 4 - Review one clear quality-check stage instead of four (Priority: P2)

**Goal**: Lint, Validate, Security Scan, and What-If run as one consolidated stage, each still individually attributable.

**Independent Test**: Run the pipeline; confirm a single stage contains all four checks, each producing its own distinguishable pass/fail result, and that a single check's failure is clearly attributable to that check.

### Implementation for User Story 4

- [X] T020 [P] [US4] Create `deploy/script/lint-bicep.sh`, extracting the `Lint` stage's `find ... | az bicep build --file ... --stdout` loop verbatim as a standalone script
- [X] T021 [P] [US4] Create `deploy/script/validate-deployment.sh`, extracting the `Validate` stage's `az deployment sub validate` invocation as a standalone script parameterized by environment name and variable-file path, reading `TICKET_QR_SIGNING_KEY_VALUE` and `keyVaultCertSecretUri` from already-exported environment variables
- [X] T022 [P] [US4] Create `deploy/script/preview-changes.sh`, extracting the `WhatIf` stage's `az deployment sub what-if` invocation plus its deletion-detection (`grep -q "Delete"`) logic as a standalone script with the same parameters as T021
- [X] T023 [US4] Replace the separate `Lint`, `Validate`, `SecurityScan`, `WhatIf` stages in `deploy/pipeline/azure-pipelines-infra.yml` with one consolidated stage containing a single job with four sequential steps — `deploy/script/lint-bicep.sh`, `deploy/script/validate-deployment.sh dev deploy/variables/dev.bicepparam`, the existing `MicrosoftSecurityDevOps@1` task, `deploy/script/preview-changes.sh dev deploy/variables/dev.bicepparam` — preserving the existing fail-fast ordering (depends on T020, T021, T022, **and T014 — both edit `deploy/pipeline/azure-pipelines-infra.yml`; complete T014 first, don't edit the two in parallel**)
- [ ] T024 [US4] Run quickstart.md's consolidated-stage scenario: force a Security Scan-only failure (Lint/Validate/What-If passing) and confirm the run clearly attributes the failure to that one step without obscuring the other three results (depends on T023)

**Checkpoint**: Pipeline run overview shows one quality-check stage instead of four, with no loss of individual check visibility.

---

## Phase 7: User Story 5 - Understand pipeline progress without technical background (Priority: P2)

**Goal**: Every stage and step name is plain English, with no icons or jargon.

**Independent Test**: Review every stage/step name shown in a pipeline run against a plain-language, icon-free standard; confirm a non-technical reader can understand each one.

### Implementation for User Story 5

- [X] T025 [US5] Rename every stage and step `displayName` across `deploy/pipeline/azure-pipelines-infra.yml` and `deploy/pipeline/templates/deploy-environment.yml` to plain English per research.md decision 10 (e.g., `"Lint Bicep"` → `"Check infrastructure code for syntax errors"`, `"Deploy to Dev"` → `"Deploy infrastructure to the development environment"`), removing every icon/symbol (depends on T023, T014)
- [ ] T026 [US5] Run quickstart.md's naming-review scenario — have a reviewer with no Azure/Bicep/DevOps background read every stage/step name in a run and confirm each is understandable on its own, with zero icons present (depends on T025)

**Checkpoint**: All stage/step names are approver-readable plain English.

---

## Phase 8: User Story 6 - Grant access to a new principal by editing a list, not writing new code (Priority: P3)

**Goal**: Key Vault and Cosmos role assignments are driven by principal arrays through dedicated child modules, composed by the RBAC parent module.

**Independent Test**: Add a new entry to the Key Vault (or Cosmos) principal list; confirm a deployment grants exactly that access with no other access-granting code modified; confirm every pre-existing principal retains its current access.

### Implementation for User Story 6

- [X] T027 [P] [US6] Create `deploy/bicep/modules/security/rbac/keyVaultRoleAssignments.bicep` accepting `keyVaultId` (string) and `principals` (array of `{ principalId, roleDefinitionId, principalType }`), declaring one `for`-looped `Microsoft.Authorization/roleAssignments` resource scoped to the Key Vault, named `guid(keyVaultId, principals[i].principalId, principals[i].roleDefinitionId)`, per contracts/rbac-child-modules.md
- [X] T028 [P] [US6] Create `deploy/bicep/modules/security/rbac/cosmosRoleAssignments.bicep` accepting `cosmosAccountId` (string) and `principals` (array of `{ principalId, roleDefinitionId }`), declaring one `for`-looped `Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments` resource parented to the Cosmos account, named `guid(cosmosAccountId, principals[i].principalId, principals[i].roleDefinitionId)`, per contracts/rbac-child-modules.md
- [X] T029 [US6] Move `deploy/bicep/modules/security/rbac.bicep` to `deploy/bicep/modules/security/rbac/rbac.bicep` as the parent module: build a `keyVaultPrincipals` array (today's `appServicePrincipalId`→Key Vault Secrets User and `agwIdentityPrincipalId`→Key Vault Secrets User pairings) and a `cosmosPrincipals` array (today's `appServicePrincipalId`→Cosmos Data Reader and `functionAppPrincipalId`→Cosmos Data Reader pairings) from its existing input parameters, invoke `keyVaultRoleAssignments.bicep` and `cosmosRoleAssignments.bicep` with them, and keep the four existing Storage/SQL role-assignment resources (`funcToRuntimeStorage`, `funcToBusinessBlob`, `funcToBusinessQueue`, `sqlToRuntimeStorage`) declared unchanged in the parent (depends on T027, T028)
- [X] T030 [US6] Update `main.bicep`'s `rbacModule` reference path to `deploy/bicep/modules/security/rbac/rbac.bicep` (the parent module's parameter surface is unchanged, so no call-site parameter edits are needed) (depends on T029)
- [X] T031 [US6] Run quickstart.md's RBAC scenario via `az deployment sub what-if` in two parts, satisfying spec SC-008's baseline-parity requirement: (a) with the `keyVaultPrincipals`/`cosmosPrincipals` arrays containing exactly today's real principal set (`appServicePrincipalId` and `agwIdentityPrincipalId` on Key Vault; `appServicePrincipalId` and `functionAppPrincipalId` on Cosmos) and no edits, confirm the what-if output shows **zero changes** — proving the refactor preserves every pre-existing principal's effective access; (b) add one throwaway test principal entry, confirm exactly one new role assignment appears with no other changes, then remove it and confirm exactly one deletion with no other changes (depends on T030)

**Checkpoint**: Adding or removing a Key Vault/Cosmos principal is a one-line array edit; every pre-existing assignment is preserved.

---

## Phase 9: User Story 7 - Change network access rules once and have it apply everywhere (Priority: P3)

**Goal**: One shared network-access-rule definition, consumed by Storage, Key Vault, and Cosmos DB.

**Independent Test**: Change the shared network access definition once; confirm Storage, Key Vault, and Cosmos DB all reflect the updated rule identically after deployment.

### Implementation for User Story 7

- [X] T032 [US7] Create `deploy/bicep/modules/shared/networkAccessRules.bicep` exposing `defaultAction` (`'Deny'`), `bypass` (`'AzureServices'`), and `allowedIpRanges` (`[]`) per contracts/shared-network-access-rules.md
- [X] T033 [P] [US7] Update `deploy/bicep/modules/storage/storageAccount.bicep`'s `runtimeStorageAccount` and `businessStorageAccount` resources to consume the shared module's `defaultAction`/`bypass` output in their `networkAcls` property instead of their hardcoded literals (depends on T032)
- [X] T034 [P] [US7] Update `deploy/bicep/modules/security/keyvault.bicep`'s `keyVault` resource to consume the shared module's `defaultAction`/`bypass` output in its `networkAcls` property instead of its hardcoded literal (depends on T032)
- [X] T035 [US7] Update `deploy/bicep/modules/database/cosmos.bicep`'s `cosmosAccount` resource to map the shared module's `defaultAction`/`allowedIpRanges` output into its own `publicNetworkAccess`/`ipRules` properties, keeping `isVirtualNetworkFilterEnabled` defined locally per contracts/shared-network-access-rules.md (depends on T032)
- [X] T036 [US7] Run quickstart.md's shared-rule-propagation scenario via `az deployment sub what-if`: change `allowedIpRanges` once, confirm the diff shows the update applied identically to Storage, Key Vault, and Cosmos in the same run; revert and confirm no drift (depends on T033, T034, T035)

**Checkpoint**: A single network-rule edit propagates consistently to all three resource types.

---

## Phase 10: User Story 8 - Prepare App Service and Function App for future zero-downtime releases (Priority: P3)

**Goal**: App Service and the Function App each have a provisioned `staging` deployment slot.

**Independent Test**: Deploy the infrastructure; confirm both App Service and the Function App each expose an additional, addressable staging slot alongside production, with no swap/cutover logic required yet.

### Implementation for User Story 8

- [X] T037 [P] [US8] Add a `staging` `Microsoft.Web/sites/slots@2024-11-01` child resource under the `appService` resource in `deploy/bicep/modules/compute/appService.bicep`, inheriting the parent App Service Plan
- [X] T038 [P] [US8] Add a `staging` `Microsoft.Web/sites/slots@2024-11-01` child resource under the `functionApp` resource in `deploy/bicep/modules/compute/function.bicep`, inheriting the parent plan
- [ ] T039 [US8] Run quickstart.md's deployment-slot scenario post-deploy (`az webapp deployment slot list`, `az functionapp deployment slot list`) confirming both `staging` slots exist without disrupting the running production slot (depends on T037, T038)

**Checkpoint**: Both compute resources are ready for future blue-green deployment work.

---

## Phase 11: User Story 9 - Review and change deployment logic without editing pipeline YAML (Priority: P3)

**Goal**: The remaining deployment-execution logic (the what-if + create step inside the environment template) is a standalone script, not inline YAML.

**Independent Test**: Locate every piece of deployment command logic as a standalone script file referenced by path; confirm the pipeline definition contains no embedded multi-line command logic for deployment steps.

### Implementation for User Story 9

- [X] T040 [US9] Create `deploy/script/deploy-environment.sh`, extracting the `az deployment sub what-if` + `az deployment sub create` logic currently inline in the deploy stage, parameterized by environment name and variable-file path, reading secret values from already-exported environment variables
- [X] T041 [US9] Update `deploy/pipeline/templates/deploy-environment.yml`'s deployment step to invoke `deploy/script/deploy-environment.sh ${{ parameters.environment }} deploy/variables/${{ parameters.environment }}.bicepparam` by path instead of its inline `inlineScript:` block (depends on T040, T014)
- [X] T042 [US9] Run `grep -n "inlineScript: |" deploy/pipeline/azure-pipelines-infra.yml deploy/pipeline/templates/*.yml` and confirm zero multi-line inline script blocks remain anywhere in the pipeline definition (depends on T020, T021, T022, T041)

**Checkpoint**: No deployment logic remains embedded in pipeline YAML; every script is independently readable.

---

## Phase 12: Polish & Cross-Cutting Concerns

**Purpose**: Final whole-feature validation and cleanup of documentation left over from the pre-refactor structure.

- [X] T043 [P] Mark `init-folder-structure.md` as superseded by the `deploy/` structure introduced in this feature (it documents the now-removed flat `modules/`/`pipelines/`/`environments/` layout) — add a note pointing to `README.md`'s updated structure section, or remove the file
- [ ] T044 Run the complete `quickstart.md` validation guide end-to-end (all 9 sections) against a real dev deployment and record the results
- [X] T045 Review spec.md's FR-001 through FR-020 against the final state of the repository and pipeline, confirming each is satisfied

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS every user story (every later task edits a file at its new `deploy/*` location)
- **User Story 1 (Phase 3)**: Depends on Foundational only
- **User Story 2 (Phase 4)**: Depends on Foundational only
- **User Story 3 (Phase 5)**: Depends on User Story 2 (removes/replaces the `ConfirmProd` stage introduced alongside US2's template, and needs the `deploy-environment.yml` template and dev/prod instantiations US2 created)
- **User Story 4 (Phase 6)**: Depends on Foundational for its own logic (consolidates the four quality stages that have existed since Phase 2's move), but **T023 also depends on T014**: both edit `deploy/pipeline/azure-pipelines-infra.yml` (US2 replaces the `DeployDev`/`DeployProd` stage bodies, US4 replaces the `Lint`/`Validate`/`SecurityScan`/`WhatIf` stages). Complete T014 before starting T023 — sequence, don't parallelize, to avoid a same-file conflict (see analysis finding F1)
- **User Story 5 (Phase 7)**: Depends on User Story 2 (renames the template's display names) and User Story 4 (renames the consolidated stage's step names)
- **User Story 6 (Phase 8)**: Depends on Foundational only
- **User Story 7 (Phase 9)**: Depends on Foundational only
- **User Story 8 (Phase 10)**: Depends on Foundational only
- **User Story 9 (Phase 11)**: Depends on User Story 2 (the script it extracts lives inside the template US2 creates) and User Story 4 (the other three scripts it validates alongside in T042)
- **Polish (Phase 12)**: Depends on all desired user stories being complete

### User Story Independence Notes

US1, US2, US6, US7, US8 can each start immediately after Foundational and be delivered/demoed on their own. US3 and US9 build on artifacts US2 introduces (the stage template); US5 builds on artifacts US2 and US4 introduce (the display names it renames). US4's own logic is independent of US2, but T023 and T014 edit the same pipeline file, so US4 must wait for T014 to land before T023 starts, even though nothing else about US4 depends on US2. This is normal for a refactor where later stories polish or gate what earlier stories in the same priority band introduced, or share a file with one — none of these dependencies cross *outside* this feature, and each story's Independent Test still passes once its prerequisites are in place.

### Parallel Opportunities

- T002, T003, T004, T005 (the four `git mv` operations in Foundational) can run in parallel — disjoint file sets
- T020, T021, T022 (the three quality-check script extractions in US4) can run in parallel — disjoint files
- T027, T028 (the two RBAC child modules in US6) can run in parallel — disjoint files
- T033, T034 (Storage and Key Vault network-rule consumption in US7) can run in parallel — disjoint files
- T037, T038 (App Service and Function App slots in US8) can run in parallel — disjoint files
- Once Foundational is complete, US1, US6, US7, and US8 can all be staffed and worked in parallel by different people, since none of them touch the same files as each other or as US2/US4. US4 (T023) must wait for US2's T014 specifically, since both edit `deploy/pipeline/azure-pipelines-infra.yml` (see Dependencies above)

---

## Parallel Example: Phase 2 Foundational

```bash
# Launch the four independent repo moves together:
Task: "git mv main.bicep deploy/bicep/main.bicep && git mv bicepconfig.json deploy/bicep/bicepconfig.json"
Task: "git mv modules deploy/bicep/modules"
Task: "git mv pipelines/azure-pipelines-infra.yml deploy/pipeline/azure-pipelines-infra.yml"
Task: "git mv environments/dev.bicepparam deploy/variables/dev.bicepparam && git mv environments/prod.bicepparam deploy/variables/prod.bicepparam"
```

## Parallel Example: Phase 8 User Story 6

```bash
Task: "Create deploy/bicep/modules/security/rbac/keyVaultRoleAssignments.bicep"
Task: "Create deploy/bicep/modules/security/rbac/cosmosRoleAssignments.bicep"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks every story)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: confirm the repo is reorganized, documented, and still deploys end-to-end
5. This is already a shippable improvement even if nothing else in this feature lands yet

### Incremental Delivery

1. Setup + Foundational → repo reorganized and still deployable
2. Add US1 → confirm structure + documentation → ship (MVP)
3. Add US2 → parameterized dev/prod via one template → ship
4. Add US3 → native approvals replace the custom gate → ship
5. Add US4 → one consolidated quality-check stage → ship
6. Add US5 → plain-English naming throughout → ship
7. Add US6 → array/for-loop-driven Key Vault & Cosmos RBAC → ship
8. Add US7 → shared network access rule → ship
9. Add US8 → staging slots on App Service & Function App → ship
10. Add US9 → last inline bash extracted to a script → ship
11. Polish → documentation cleanup + full quickstart + requirements traceability pass

### Solo Execution Order

This feature is being implemented solo, so the phases simply run in document order (Setup → Foundational → US1 → US2 → US3 → US4 → US5 → US6 → US7 → US8 → US9 → Polish). The one ordering constraint worth calling out explicitly: **complete T014 (US2) before starting T023 (US4)** — they edit the same file (`deploy/pipeline/azure-pipelines-infra.yml`), and the document order already satisfies this since Phase 4 (US2) precedes Phase 6 (US4). If a team split is considered later, keep US2 and US4 with the same person (or strictly sequenced) for that reason; US1, US6, US7, and US8 remain safe to hand to someone else in parallel, since none of them touch `deploy/pipeline/azure-pipelines-infra.yml`.

---

## Notes

- [P] tasks touch different files with no dependency on an incomplete task
- [Story] labels map every user-story-phase task back to spec.md for traceability
- Every `git mv` task preserves file history — do not recreate files via delete+add
- Commit after each task or logical group
- Stop at any checkpoint to validate a story independently before continuing
- FR-020 ("every principal... continues to resolve to the same effective access... after the refactor") is the acceptance bar for T029/T031 (RBAC) and T032–T036 (network rules) — treat any unintended diff in a `what-if` as a blocking defect, not a note for later
