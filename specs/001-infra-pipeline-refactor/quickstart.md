# Quickstart: Validating the Infrastructure Repository & Pipeline Refactor

Prerequisites: Azure CLI logged in with access to the GOAT Ticket subscription; repo checked out at this feature's branch; the Azure DevOps project's `goat-dev` and `goat-prod` Environment resources exist (create them in Project Settings → Environments if missing — `goat-prod` needs an Approval check added under its Approvals and checks).

## 1. Folder structure (Story 1)

```bash
test -d deploy/bicep && test -d deploy/pipeline && test -d deploy/script && test -d deploy/variables
test ! -d modules && test ! -d pipelines && test ! -d environments
```
Expected: all four `deploy/*` folders exist; the three legacy folders are gone.

## 2. Lint and validate (Quality Checks stage, standalone)

```bash
bash deploy/script/lint-bicep.sh
bash deploy/script/validate-deployment.sh dev deploy/variables/dev.bicepparam
```
Expected: lint passes with no syntax errors; validate succeeds against Azure with no resources created (preflight only). Re-run with an intentionally broken `.bicep` file to confirm lint fails *before* validate is invoked (per research decision 3's fail-fast ordering).

## 3. Change preview (What-If)

```bash
bash deploy/script/preview-changes.sh dev deploy/variables/dev.bicepparam
```
Expected: a change summary with no unexpected deletions, mirroring today's `WhatIf` stage output.

## 4. RBAC array/for-loop behavior (Story 6)

1. Add one extra entry to the `principals` array fed into `keyVaultRoleAssignments.bicep` (a throwaway test principal's GUID is fine for a what-if-only check).
2. Re-run `preview-changes.sh`.
3. Expected: the what-if output shows exactly one new `Microsoft.Authorization/roleAssignments` resource create, and no changes to any other existing role assignment.
4. Remove the entry; re-run; expected: the what-if output shows that one assignment being deleted, nothing else.

## 5. Shared network access rule propagation (Story 7)

1. Change `allowedIpRanges` in `deploy/bicep/modules/shared/networkAccessRules.bicep` from `[]` to a test CIDR.
2. Re-run `preview-changes.sh`.
3. Expected: the what-if diff shows the new allowed range applied to the Storage accounts, Key Vault, *and* Cosmos DB (via its `ipRules`) in the same run — confirming FR-017/SC-007 without three separate edits.
4. Revert the change.

## 6. Deployment slots (Story 8)

After a `dev` deployment completes:

```bash
az webapp deployment slot list --name app-goat-api-dev --resource-group rg-goat-app-dev -o table
az functionapp deployment slot list --name func-goat-worker-dev --resource-group rg-goat-app-dev -o table
```
Expected: a `staging` slot listed for both, alongside the production slot, with no impact to the production slot's running state (edge case check).

## 7. Consolidated stage and plain-English naming (Stories 4 and 5)

Trigger the pipeline (push a matching `infra-v*.*.*` tag, per the existing trigger). In the Azure DevOps run view:
- Expected: one stage covers linting, validation, security scanning, and what-if — not four.
- Expected: every stage/step name reads as a plain-English sentence with no icons, emoji, or tool jargon (hand the run view to someone unfamiliar with Azure/Bicep and confirm they can describe what each step is doing from its name alone).
- Force a Security Scan finding (or temporarily lower its severity threshold) while Lint/Validate pass, and confirm the run clearly attributes the failure to that one step, not the stage as an undifferentiated whole.

## 8. Approval gate (Story 3)

With the `dev` stage succeeded, let the pipeline reach the `prod` stage.
- Expected: the run pauses with an Azure DevOps "Waiting for approval" indicator on the `goat-prod` Environment — no `ManualValidation@0` task appears anywhere in the run.
- Approve: expected the prod deployment steps run immediately after.
- On a second run, reject the pending approval instead: expected the stage stops and no deployment steps execute.

## 9. No inline bash remains (Story 9)

```bash
grep -n "inlineScript: |" deploy/pipeline/azure-pipelines-infra.yml deploy/pipeline/templates/*.yml
```
Expected: no multi-line (`|`) inline script blocks remain for deployment logic — only single-line script-file invocations (e.g. `bash deploy/script/deploy-environment.sh ...`).
