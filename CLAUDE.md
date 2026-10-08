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

- Only what varies between callers is a template parameter: `environment`, `environmentName`, `repository`. One
  subscription, one service connection, one stack, so those are fixed in the template rather than passed through two
  files. `environment` has an allow-list and selects `deploy/variables/<env>.bicepparam`.
- `.bicepparam` is the only place a Bicep parameter is assigned. No secret passes through Bicep: the application
  pipeline writes secrets to Key Vault behind a toggle.
- Built-in tasks only (`BicepDeploy@0`, `MicrosoftSecurityDevOps@1`). No inline scripts for lint, validate, what-if or deploy.
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
