# goat-ticket-infra

Bicep infrastructure and the infrastructure pipeline for the GOAT Ticket project.
Read `docs/PROJECT_CONTEXT.md` first: it says what is done, what is only designed, and the mentor's hard rules.

## Layout

```
deploy/bicep/                                    Bicep (main.bicep at subscription scope, modules under modules/)
deploy/variables/<env>.bicepparam                the only place a Bicep parameter is assigned
deploy/pipeline/azure-pipelines-infra.yml        independent pipeline, manual run
deploy/pipeline/templates/deploy-infra-jobs.yml  the ONLY infrastructure pipeline template
```

## Rules

- Only what varies between callers is a template parameter: `environment`, `repository`, `abcobject`. The Environment
  bound to the deploy job is `goat-<environment>`. Per-environment stack settings (connection, subscription, location,
  Bicep version, stack name) sit in one values-only if/else file, `templates/environment-variables.yml`; the mock runs every environment
  on the dev branch and only prod has its own. `environment` is a free string with no allow-list: any name works as long as `deploy/variables/<env>.bicepparam`
  exists, and it must contain only letters, digits and underscores because it is part of the job name.
- The infra pipeline is manual. `azure-pipelines-infra.yml` defines one stage per environment (dev, sit, uat, preprod,
  prod), written out one by one, in that order. The `environments` parameter (a list of names, default `dev`, `sit`, `uat`,
  `preprod`) picks which of them run; a name that is not one of the five has no stage. Each environment needs
  `deploy/variables/<env>.bicepparam`; the mock keeps them identical to dev.
- `deployNetwork` (a checkbox, default off) limits a run to rg-app: when off, every rg-network module is skipped and the
  app layer reads the subnets and the AGW identity of what already exists; when on, both resource groups are deployed.
  It travels as `DEPLOY_SCOPE` (`all` or `app`) into the `.bicepparam` files. The app pipeline has the same checkbox and
  passes it on. `environments` is a plain string of names separated by commas, for example `dev,sit`.
- `.bicepparam` is the only place a Bicep parameter is assigned. No secret passes through Bicep: the application
  pipeline writes secrets to Key Vault behind a toggle.
- Built-in tasks only (`BicepDeploy@0`, `MicrosoftSecurityDevOps@1`). No inline scripts for lint, validate or deploy.
  The one exception is the what-if preview: `BicepDeploy@0` has no `whatIf` operation, so `AzureCLI@2` runs
  `az stack-whatif sub create` against the stack.
- Infrastructure is delivered as an Azure deployment stack (`type: deploymentStack`, subscription scope) with the Bicep CLI
  pinned (`bicepVersion`). Keep `denySettingsMode: none` while resources are repaired or deleted by hand.
- Deploy jobs are `deployment` jobs bound to an Environment; the template never deploys a pull request build.
- Display names: plain professional English, no icons. Comments in English.
- Bicep: RBAC uses a parent module that composes child modules with `for` loops over principal arrays. Share constants
  with `@export()`; the five globally unique names come from `modules/shared/naming.bicep`.
- Bicep keeps only the settings that make a resource work. Application settings belong to the delivery pipeline, from
  the `goat-app-<env>` variable group. An infrastructure deploy replaces them, so run the application pipeline after.
- Never commit keys, `.pem`, `.pfx` or secrets. Generate certificates in a temporary directory outside the repo.
- Do not purge or touch Key Vaults whose names start with `kv-inventory`; they belong to another project.
- Azure Firewall costs about 20 USD per day: do not deploy or leave resources running unless asked.

A template change needs a new tag (`infra-templates-vX.Y.Z`) and a matching bump of `ref` in the app pipeline.

## Working style

Reply in Vietnamese, concise, technical terms in English. Show files one by one in full. Do not deploy or change code
unless asked. Cite official documentation when asked and say plainly when a page does not state something.
