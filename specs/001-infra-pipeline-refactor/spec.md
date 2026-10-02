# Feature Specification: Infrastructure Repository & Pipeline Refactor

**Feature Branch**: `[001-infra-pipeline-refactor]`

**Created**: 2026-10-02

**Status**: Draft

**Input**: User description: "Refactor goat-ticket-infra repository structure and pipeline design: restructure folders into deploy/bicep, deploy/pipeline, deploy/script, deploy/variables; parameterize dev/prod instead of hardcoding; add staging deployment slots to App Service and Function App; remove the custom ManualValidation@0 gate in favor of Azure DevOps built-in Environment Approvals; merge Lint, Validate, Security Scan, and What-If into one stage; use plain-English, icon-free stage/step names; refactor the RBAC module into a parent module with per-resource-type child modules driven by principal arrays and for-loops; extract shared networkAcls configuration; extract inline bash from pipeline YAML into standalone script files."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Find infrastructure code by concern, not by guesswork (Priority: P1)

An infrastructure engineer joining the project or making a change needs to locate the right Bicep module, the pipeline definition, a deployment script, or an environment's configuration values without having to search multiple loosely related top-level folders.

**Why this priority**: This is the foundation every other change in this refactor depends on — pipeline parameterization, script extraction, and module changes all need a stable, predictable home to live in. Without it, every other story has nowhere consistent to land.

**Independent Test**: Can be fully tested by browsing the repository and confirming that Bicep modules, pipeline definitions, deployment scripts, and environment variable files each live under a single, dedicated top-level location, and that a full deployment still completes successfully using only the new locations.

**Acceptance Scenarios**:

1. **Given** the repository after the refactor, **When** an engineer looks for Bicep templates, pipeline YAML, deployment scripts, or environment-specific values, **Then** each category is found under one dedicated top-level folder and nowhere else.
2. **Given** the reorganized repository, **When** a deployment pipeline runs end-to-end, **Then** it completes successfully referencing only the new folder locations, with no remaining references to the old flat folders.

---

### User Story 2 - Promote the same release through dev and prod without duplicated pipeline logic (Priority: P1)

A release manager or pipeline operator wants to deploy the same infrastructure definition to either the dev or prod environment by choosing which environment to target, trusting that the correct configuration values are applied automatically — rather than relying on stage names or copy-pasted logic that silently assumes one environment.

**Why this priority**: Hardcoded environment handling is the main source of drift and duplicated logic in the current pipeline, and it blocks safely adding further environments later. It is equally foundational to the folder reorganization.

**Independent Test**: Can be fully tested by running the pipeline once specifying "dev" and once specifying "prod" and confirming each run picks up the matching variable file and deploys with the correct, environment-specific configuration, using shared pipeline logic rather than separate copies.

**Acceptance Scenarios**:

1. **Given** the pipeline is started with the environment set to "dev", **When** it reaches a deployment step, **Then** it applies values from the dev variable file only.
2. **Given** the pipeline is started with the environment set to "prod", **When** it reaches a deployment step, **Then** it applies values from the prod variable file only, using the same underlying stage logic as the dev run.

---

### User Story 3 - Approve production releases through standard Azure DevOps controls (Priority: P2)

A release approver — who may not have a technical background — needs to review and approve a production deployment using Azure DevOps' own approval experience, so the approval is recorded with standard audit history and permissions instead of depending on a custom script step.

**Why this priority**: Approval integrity and auditability for production changes is a governance requirement, but it builds on top of the parameterized dev/prod flow (Story 2) rather than being a prerequisite for it.

**Independent Test**: Can be fully tested by triggering a production deployment and confirming the pipeline pauses at the point where Azure DevOps' built-in environment approval is configured, that no custom validation script executes, and that the deployment only continues after an approval is recorded.

**Acceptance Scenarios**:

1. **Given** a production deployment has reached the approval checkpoint, **When** no one has approved it yet, **Then** the pipeline is paused and no deployment steps execute.
2. **Given** an authorized approver approves the pending deployment in Azure DevOps, **When** the approval is recorded, **Then** the pipeline proceeds automatically to the deployment steps without any custom approval script running.
3. **Given** an authorized approver rejects the pending deployment, **When** the rejection is recorded, **Then** the pipeline stops and the deployment steps do not execute.

---

### User Story 4 - Review one clear quality-check stage instead of four (Priority: P2)

An infrastructure engineer or approver reviewing a pipeline run wants to see one consolidated stage covering linting, validation against Azure, security scanning, and a preview of changes, instead of tracking four separate stages, so the run overview is faster to scan and diagnose.

**Why this priority**: This mainly improves clarity and run-time efficiency; it depends on the folder and parameterization work but does not block approval or RBAC changes.

**Independent Test**: Can be fully tested by running the pipeline and confirming a single stage contains all four checks, each still producing its own distinguishable pass/fail result, and that a failure in any one check is clearly attributable to that specific check.

**Acceptance Scenarios**:

1. **Given** a pipeline run, **When** it reaches the quality-check stage, **Then** linting, validation, security scanning, and the change preview all execute within that one stage.
2. **Given** the security scan step fails while the other three checks pass, **When** the stage completes, **Then** the run clearly reports which specific check failed.

---

### User Story 5 - Understand pipeline progress without technical background (Priority: P2)

A non-technical approver or stakeholder watching a pipeline run wants every stage and step name to be written in plain English, with no icons or jargon, so they can understand what is happening and what they are being asked to approve.

**Why this priority**: This is a readability and trust improvement for approvers; it is independent of the underlying technical changes and can be verified purely by reading names in the pipeline UI.

**Independent Test**: Can be fully tested by reviewing every stage and step name shown in a pipeline run against a plain-language, icon-free standard, with no prior technical knowledge required to understand what each one does.

**Acceptance Scenarios**:

1. **Given** a pipeline run in progress, **When** a non-technical reviewer reads any stage or step name, **Then** the name is understandable without needing to know Azure, Bicep, or DevOps terminology, and contains no icons or symbols.

---

### User Story 6 - Grant access to a new principal by editing a list, not writing new code (Priority: P3)

An infrastructure engineer who needs to grant a new service identity access to Key Vault or Cosmos DB wants to add an entry to a list of principals rather than writing a new, uniquely-named access-grant resource for each one.

**Why this priority**: This reduces ongoing maintenance effort and risk of copy-paste errors, but it is an internal implementation improvement that does not change what access currently exists, so it carries lower urgency than the pipeline and approval changes.

**Independent Test**: Can be fully tested by adding a new entry to the list of principals that should have Key Vault or Cosmos access and confirming, after deployment, that the new principal has exactly the intended access, with no changes made anywhere else.

**Acceptance Scenarios**:

1. **Given** the current list of principals with Key Vault access, **When** a new principal is added to that list, **Then** a deployment grants that principal the intended access without any other access-granting code being modified.
2. **Given** the current list of principals with Cosmos access, **When** a new principal is added to that list, **Then** a deployment grants that principal the intended access without any other access-granting code being modified.
3. **Given** the existing set of access grants prior to this refactor, **When** the refactor is deployed with an equivalent list of principals, **Then** every principal retains exactly the access it had before.

---

### User Story 7 - Change network access rules once and have it apply everywhere (Priority: P3)

An infrastructure engineer who needs to update allowed network access (for example, allowed IP ranges or whether public access is permitted) wants to change that rule in a single shared place and have it consistently apply to Storage, Key Vault, and Cosmos DB, instead of editing the same configuration three separate times.

**Why this priority**: This reduces the risk of the three resources drifting out of sync with each other, but it is a lower-risk internal consistency improvement compared to the pipeline and approval stories.

**Independent Test**: Can be fully tested by changing the shared network access definition once and confirming, after deployment, that Storage, Key Vault, and Cosmos DB all reflect the updated rule identically.

**Acceptance Scenarios**:

1. **Given** a single shared network access rule definition, **When** its value is changed, **Then** Storage, Key Vault, and Cosmos DB all apply the updated rule after the next deployment.
2. **Given** the shared definition is unchanged, **When** a deployment runs, **Then** Storage, Key Vault, and Cosmos DB continue to enforce the same network access rules as before.

---

### User Story 8 - Prepare App Service and Function App for future zero-downtime releases (Priority: P3)

An infrastructure engineer wants App Service and the Function App to each have a staging slot provisioned, so that a future blue-green deployment capability (swapping staging into production with no downtime) can be built on top of this change without re-architecting the compute resources.

**Why this priority**: This is explicitly preparatory for future work rather than a capability used immediately, so it can land after the higher-priority pipeline and process changes.

**Independent Test**: Can be fully tested by deploying the infrastructure and confirming both App Service and the Function App each expose an additional, addressable staging slot, separate from the production slot, without requiring any swap or cutover logic to exist yet.

**Acceptance Scenarios**:

1. **Given** a completed deployment, **When** App Service's slots are inspected, **Then** a staging slot exists in addition to the production slot.
2. **Given** a completed deployment, **When** the Function App's slots are inspected, **Then** a staging slot exists in addition to the production slot.

---

### User Story 9 - Review and change deployment logic without editing pipeline YAML (Priority: P3)

An infrastructure engineer who needs to review, test, or modify the commands that run during a deployment wants that logic in standalone script files, so it can be read, linted, and changed independently of the pipeline definition.

**Why this priority**: This is a maintainability improvement with no change to runtime behavior, so it is the lowest-urgency story, suitable to land last.

**Independent Test**: Can be fully tested by locating every piece of deployment command logic as a standalone script file referenced by path from the pipeline definition, with the pipeline definition itself containing no embedded multi-line command logic for deployment steps.

**Acceptance Scenarios**:

1. **Given** the refactored pipeline definition, **When** it is reviewed, **Then** every deployment step invokes a standalone script file by path rather than containing embedded multi-line command logic.
2. **Given** a standalone deployment script, **When** it is opened on its own, **Then** it can be read and understood without needing the surrounding pipeline definition for context.

---

### Edge Cases

- What happens if a pipeline stage template instantiation is ever authored (by mistake) with an environment value that is neither "dev" nor "prod"? Environment selection is fixed at pipeline-authoring time — it is not a value an operator supplies per run — so this is an authoring-time safeguard, not a runtime input check: Bicep's `@allowed` constraint on the environment parameter rejects the value, failing that environment's deployment preview (what-if) step clearly before its create step can run, rather than silently deploying with an unintended configuration.
- What happens when a production deployment's approval is still pending when the pipeline run is cancelled or times out? The deployment steps must not execute.
- How does the consolidated quality-check stage report results when more than one of its checks fails at the same time? Each failing check must be individually identifiable in the run output.
- What happens the first time a staging slot is deployed to an App Service or Function App that has never had a staging slot before? The slot must be created without disrupting the currently running production slot.
- What happens when a principal is removed from the Key Vault or Cosmos principal list? The corresponding access grant must be removed on the next deployment.
- What happens when the shared network access definition would, if applied literally to all three resource types, conflict with a setting only one of them supports? The shared definition must only express settings common to Storage, Key Vault, and Cosmos; resource-specific exceptions remain local to that resource's module.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST organize all infrastructure-as-code artifacts under four dedicated top-level locations: one for resource templates, one for pipeline definitions, one for deployment scripts, and one for environment-specific configuration values.
- **FR-002**: The repository MUST NOT retain the previous flat, mixed-purpose top-level folders once the new structure is in place.
- **FR-003**: The pipeline MUST determine which environment (dev or prod) to target from a single explicit parameter supplied at run time, rather than from separate hardcoded stages or copy-pasted logic per environment.
- **FR-004**: The pipeline MUST load environment-specific configuration from a dedicated variable file per environment, selected automatically based on the environment parameter.
- **FR-005**: If a pipeline stage template instantiation is ever authored with an environment value outside the supported set, Bicep's `@allowed` constraint on the environment parameter MUST cause that environment's deployment preview (what-if) step to fail clearly, before its corresponding create step runs. This is an authoring-time safeguard — environment selection is fixed when the pipeline is written, not supplied by an operator at run time.
- **FR-006**: App Service MUST be provisioned with an additional staging slot alongside its existing production slot.
- **FR-007**: The Function App MUST be provisioned with an additional staging slot alongside its existing production slot.
- **FR-008**: The pipeline MUST NOT execute any custom manual-validation script as a condition for proceeding with a production deployment.
- **FR-009**: Production deployments MUST be gated on an approval recorded through Azure DevOps' built-in environment approval capability.
- **FR-010**: Linting, validation against Azure, security scanning, and the change preview MUST execute within a single consolidated pipeline stage rather than four separate stages.
- **FR-011**: Within the consolidated stage, each of the four checks MUST produce an individually identifiable pass/fail result, so a failure in one check does not obscure the results of the others.
- **FR-012**: Every pipeline stage and step name MUST be plain English understandable by a reader with no technical background, and MUST NOT contain icons, emoji, or symbols.
- **FR-013**: Role assignments for Key Vault MUST be created from an array of principal entries processed through a single reusable mechanism, rather than one uniquely-named resource per principal.
- **FR-014**: Role assignments for Cosmos DB MUST be created from an array of principal entries processed through a single reusable mechanism, rather than one uniquely-named resource per principal.
- **FR-015**: The Key Vault and Cosmos role-assignment mechanisms MUST each be organized as their own distinct unit, composed together by a higher-level RBAC definition, rather than mixed into one undifferentiated set of resources.
- **FR-016**: Adding or removing a principal from an access list MUST NOT require modifying any other principal's entry or any role-assignment definition.
- **FR-017**: Network access configuration shared across Storage, Key Vault, and Cosmos DB MUST be defined in exactly one reusable place and referenced by each resource's configuration, rather than repeated independently in each.
- **FR-018**: Any network access setting that is specific to only one of Storage, Key Vault, or Cosmos DB MUST remain defined locally for that resource, not forced into the shared definition.
- **FR-019**: Deployment command logic currently embedded as inline multi-line script blocks within the pipeline definition MUST be moved into standalone script files, invoked from the pipeline by file path.
- **FR-020**: Every principal, environment, and access grant that exists before this refactor MUST continue to resolve to the same effective access and configuration after the refactor, unless a change is explicitly intended.

### Key Entities

- **Environment Variable File**: A per-environment (dev, prod) collection of configuration values consumed by the pipeline and templates; identified by environment name and selected automatically from the pipeline's environment parameter.
- **Pipeline Stage**: A named phase of the deployment pipeline (for example, the consolidated quality-check stage, or a deployment stage); has a plain-English display name and produces a pass/fail outcome.
- **Deployment Script**: A standalone file containing command logic for a specific deployment action, referenced by path from a pipeline step rather than embedded inline.
- **Principal Access Entry**: A single item in an array describing one identity (for example, a managed identity) that should receive a specific role on Key Vault or Cosmos DB; includes enough information to identify the principal and the role to grant.
- **Shared Network Access Rule**: A single reusable definition of network access settings common to Storage, Key Vault, and Cosmos DB (for example, default access behavior and allowed ranges), referenced by each resource's configuration.
- **Deployment Slot**: An additional, independently addressable instance of App Service or the Function App (the staging slot), existing alongside the production slot in preparation for future swap-based releases.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: An engineer can identify the correct location for a resource template, pipeline definition, deployment script, or environment configuration value within seconds, with no ambiguity between folders.
- **SC-002**: Supporting an additional environment beyond dev and prod requires adding one new variable file, with no changes to the pipeline's stage definitions.
- **SC-003**: 100% of production deployments show an approval recorded through Azure DevOps' standard approval history, with zero executions of a custom approval script.
- **SC-004**: The pipeline run overview shows one quality-check stage in place of the four that existed before, a reduction of at least three stages, with no loss of individual check results.
- **SC-005**: A reviewer with no infrastructure or cloud background can correctly describe what each stage and step is doing, using only its displayed name, with no icons present anywhere in the pipeline run.
- **SC-006**: Granting Key Vault or Cosmos access to a new principal requires adding one entry to a list, with zero new uniquely-named resource definitions written.
- **SC-007**: Changing a shared network access rule (such as an allowed IP range) takes effect identically across Storage, Key Vault, and Cosmos DB after a single edit, with zero duplicate edits required.
- **SC-008**: 100% of existing principal access grants and resource configurations produce identical effective access and settings after the refactor, verified with no unintended access changes.
- **SC-009**: App Service and the Function App each have a staging slot available immediately after deployment, with zero additional manual provisioning steps.
- **SC-010**: Zero inline multi-line deployment command blocks remain inside the pipeline definition file.

## Assumptions

- Azure DevOps Pipelines (YAML) remains the continuous delivery platform; this refactor changes organization and process within that platform, not a migration to a different CI/CD system.
- Bicep remains the infrastructure-as-code language; this refactor reorganizes and restructures Bicep modules, not a migration to a different templating technology.
- Dev and prod remain the only two environments required to ship with this change; the new parameter- and variable-file-driven design is expected to make adding further environments straightforward later, but delivering additional environments now is out of scope.
- Provisioning the staging slots satisfies the "future blue-green deployment support" goal for this change; building the actual swap/cutover automation and traffic-routing logic is explicitly out of scope and left for a future change.
- The Azure DevOps project already has, or will separately have, an Environment resource configured with approval checks for production; configuring that approval policy itself is an Azure DevOps project setting outside this repository's code and is assumed to be in place or configured alongside this change.
- "Principals" receiving Key Vault or Cosmos access include the managed identities already in use today (App Service, Function App, App Gateway, SQL Server); the array-based design is expected to accommodate any of these without needing to distinguish special cases in code.
- This refactor preserves existing Azure resource names and live resource identity; it is a code organization, process, and access-management refactor, not a renaming or recreation of already-deployed resources.
