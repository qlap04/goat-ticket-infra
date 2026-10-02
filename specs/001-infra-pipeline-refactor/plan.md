# Implementation Plan: Infrastructure Repository & Pipeline Refactor

**Branch**: `001-infra-pipeline-refactor` | **Date**: 2026-10-02 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-infra-pipeline-refactor/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Reorganize the GOAT Ticket infra repo from flat `modules/`, `pipelines/`, `environments/` folders into a `deploy/{bicep,pipeline,script,variables}` layout, and rework the Azure DevOps pipeline so dev vs. prod is selected by an explicit parameter resolving to a per-environment variable file (not hardcoded per-environment stages). The pipeline's custom `ManualValidation@0` prod gate is removed in favor of Azure DevOps' built-in Environment Approvals on the `goat-prod` environment. Lint, Validate, Security Scan, and What-If collapse into one "Quality Checks" stage with plain-English, icon-free step names, each check individually attributable. The RBAC module splits into a parent module composing two array/for-loop-driven child modules (Key Vault role assignments, Cosmos role assignments); Storage/SQL assignments stay as explicit resources in the parent, matching the spec's scope. A shared network-access-rule definition is extracted for the policy intent common to Storage, Key Vault, and Cosmos, with resource-specific shape differences (Cosmos has no literal `networkAcls` property) mapped locally per resource. App Service and the Function App each gain a `staging` deployment slot, provisioned only — no swap/traffic-routing automation. All inline multi-line bash in the pipeline YAML moves into standalone scripts under `deploy/script/`.

## Technical Context

**Language/Version**: Bicep (via `az bicep`, linted through `bicepconfig.json`); Azure Pipelines YAML (classic schema); Bash (POSIX `sh`, per `.specify/init-options.json` script preference)

**Primary Dependencies**: Azure CLI (`az deployment sub validate|what-if|create`, `az bicep build`), Azure DevOps Pipelines tasks (`AzureCLI@2`, `MicrosoftSecurityDevOps@1` running Checkov + Template Analyzer), Azure DevOps Environments (approvals/checks)

**Storage**: N/A — this feature provisions storage/database resources (Storage Accounts, Cosmos DB, SQL), it does not consume a datastore itself

**Testing**: `az bicep build` (syntax/lint), `az deployment sub validate` (preflight), `az deployment sub what-if` (change preview), Checkov + Template Analyzer via `MicrosoftSecurityDevOps@1` (IaC security scan) — no application unit-test framework applies to this IaC-only feature

**Target Platform**: Azure subscription-scope deployment; two resource groups per environment (`rg-goat-network-{env}`, `rg-goat-app-{env}`); region `southeastasia`; Azure DevOps-hosted `ubuntu-latest` pipeline agents

**Project Type**: Infrastructure-as-code + CI/CD pipeline (not an application codebase — no frontend/backend split applies)

**Performance Goals**: N/A in the traditional sense; the consolidated Quality Checks stage must not materially increase total pipeline run time versus the four stages it replaces (checks still run sequentially since Validate/Security Scan/What-If depend on Lint passing first)

**Constraints**: Must preserve existing Azure resource identity and names (no unintended recreation); must preserve every current principal's effective access after the RBAC refactor (spec FR-020); zero inline multi-line bash blocks may remain in the pipeline YAML after the refactor; subscription-scope deployment model keeps using child modules for resource-group-scoped resources (Bicep BCP165 constraint, already handled via `subnetAssociation.bicep`-style modules); dev and prod are the only environments shipped now

**Scale/Scope**: Single Azure subscription; ~20 existing Bicep modules/files across `network`, `gateway-firewall`, `compute`, `database`, `storage`, `security`, `privateEndpoints`; one pipeline YAML file with 7 stages today, collapsing toward roughly 4-5 stages (Quality Checks, Deploy Dev, Deploy Prod, implicit approval checkpoint on the `goat-prod` Environment); 2 environments (dev, prod)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is still the unfilled placeholder template (all `[PRINCIPLE_N_NAME]`/`[PRINCIPLE_N_DESCRIPTION]` tokens are unresolved) — no project-specific principles or governance rules have been ratified yet. There are no enforceable gates to check this plan against. This is **not** treated as a violation requiring justification in Complexity Tracking; it is simply the absence of a constitution. No complexity-tracking entries are needed for this reason alone.

## Project Structure

### Documentation (this feature)

```text
specs/001-infra-pipeline-refactor/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
deploy/
├── bicep/
│   ├── main.bicep                       # moved from repo root; orchestration entry point
│   ├── bicepconfig.json                 # moved from repo root; co-located with Bicep source
│   └── modules/
│       ├── network/                     # vnet, nsg, routeTable(+Egress), subnetAssociation
│       ├── gateway-firewall/            # firewall(+Policy), appGateway(+Resource)
│       ├── compute/
│       │   ├── appService.bicep         # + staging slot resource
│       │   └── function.bicep           # + staging slot resource
│       ├── database/                    # sql(+Auditing), cosmos
│       ├── storage/                     # storageAccount
│       ├── security/
│       │   ├── keyvault.bicep
│       │   ├── appInsights.bicep
│       │   └── rbac/
│       │       ├── rbac.bicep                     # parent — composes child modules + storage/SQL assignments
│       │       ├── keyVaultRoleAssignments.bicep   # child — principals array, for-loop
│       │       └── cosmosRoleAssignments.bicep     # child — principals array, for-loop
│       ├── shared/
│       │   └── networkAccessRules.bicep # common network-policy-intent definition
│       └── privateEndpoints/            # privateDnsZones, privateEndpoints
│
├── pipeline/
│   ├── azure-pipelines-infra.yml        # stage/parameter orchestration only; no inline bash
│   └── templates/
│       └── deploy-environment.yml       # reusable stage template, parameterized by environment
│
├── script/
│   ├── lint-bicep.sh
│   ├── validate-deployment.sh
│   ├── preview-changes.sh               # what-if
│   └── deploy-environment.sh            # what-if + create, parameterized by environment
│
└── variables/
    ├── dev.bicepparam                   # moved from environments/
    └── prod.bicepparam                  # moved from environments/
```

Tool-root config files that depend on repository-root discovery (`.checkov.yaml`, `ps-rule.yaml`) remain at the repository root; `bicepconfig.json` moves alongside the Bicep sources it configures since `az bicep` resolves it relative to the target file.

**Structure Decision**: Single infrastructure-as-code project, reorganized by concern (`bicep` / `pipeline` / `script` / `variables`) under one new `deploy/` root, replacing the flat `modules/`, `pipelines/`, `environments/` folders per spec FR-001/FR-002. No frontend/backend or multi-app split applies — this repository contains only infra definitions and their delivery pipeline.

## Complexity Tracking

*No Constitution Check violations were identified (see above) — this section is intentionally left without entries.*
