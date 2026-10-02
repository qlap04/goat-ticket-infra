# Contract: Pipeline Deploy Stage Template

## `deploy/pipeline/templates/deploy-environment.yml`

**Parameters**

| Parameter | Type | Allowed values | Description |
|---|---|---|---|
| `environment` | string | `dev`, `prod` | Drives every environment-specific selection below; the only input that varies between the template's two instantiations |

**Compile-time-resolved selections** (via `${{ parameters.environment }}`, resolved before stage expansion — not runtime pipeline variables):

- Azure DevOps Environment resource targeted by the deployment job: `goat-${{ parameters.environment }}` (carries the Approval check for `goat-prod`; `goat-dev` has none, matching today's behavior where dev deploys without a gate).
- Variable group providing secrets: `goat-ticket-secrets-${{ parameters.environment }}` (research decision 5), exposing variable names `ticketQrSigningKeyValue` and `keyVaultCertSecretUri` identically regardless of environment.
- Variable file path passed to the deploy script: `deploy/variables/${{ parameters.environment }}.bicepparam`.

**Steps** (invoking standalone scripts, per research decision 9):

1. Checkout.
2. `AzureCLI@2` step running `deploy/script/deploy-environment.sh ${{ parameters.environment }} deploy/variables/${{ parameters.environment }}.bicepparam`, with `TICKET_QR_SIGNING_KEY_VALUE` and `KEY_VAULT_CERT_SECRET_URI` exported from the selected variable group before invocation.

**Display name convention**: `Deploy infrastructure to the ${{ iif(eq(parameters.environment,'prod'),'production','development') }} environment` (plain English per FR-012 — no environment codename or icon).

## Main pipeline (`deploy/pipeline/azure-pipelines-infra.yml`)

**Stages, in order**:

1. `QualityChecks` (displayName: plain-English per research decision 10) — Lint, Validate, Security Scan, What-If as four sequential steps in one job, each invoking its own script from `deploy/script/`; Validate/What-If target `deploy/variables/dev.bicepparam` (research decision 3).
2. Template instantiation: `deploy-environment.yml` with `environment: dev`, `dependsOn: QualityChecks`.
3. Template instantiation: `deploy-environment.yml` with `environment: prod`, `dependsOn:` the dev instantiation's stage name. No separate approval stage — the pause happens inside this stage's deployment job because it targets the `goat-prod` Environment (research decision 4).

**Removed from today's pipeline**: the `ConfirmProd` stage and its `ManualValidation@0` task (FR-008); all inline multi-line `inlineScript:` blocks (FR-019); the per-environment-suffixed secret variable names (research decision 5).
