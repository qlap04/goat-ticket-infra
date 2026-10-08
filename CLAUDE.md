# goat-ticket-infra

Bicep infrastructure and the infrastructure pipeline for the GOAT Ticket project.
Read `docs/PROJECT_CONTEXT.md` first: it says what is done, what is only designed, and the mentor's hard rules.

## Layout

```
deploy/bicep/                        Bicep (main.bicep at subscription scope, modules under modules/)
deploy/variables/<env>.bicepparam    Bicep parameter files (mock: every environment uses dev)
deploy/templates/deploy-infra-jobs.yml   the ONLY infrastructure pipeline template
deploy/environments/<env>.yml        values for one environment, passed to the template as parameters
deploy/pipeline/azure-pipelines-infra.yml  independent pipeline (manual run, pick the environment)
```

## Rules

- The template holds no environment values and no parameter defaults. Every value is a required parameter and comes
  from `deploy/environments/<env>.yml`. `environment` has an allow-list.
- Built-in tasks only (`BicepDeploy@0`, `MicrosoftSecurityDevOps@1`). No inline scripts for lint, validate, what-if or deploy.
- Infrastructure is delivered as an Azure deployment stack (`type: deploymentStack`, subscription scope) with the Bicep CLI
  pinned (`bicepVersion`). Keep `denySettingsMode: none` while resources are repaired or deleted by hand.
- Deploy jobs are `deployment` jobs bound to an Environment; the template never deploys a pull request build.
- Display names: plain professional English, no icons. Comments in English.
- Bicep: RBAC uses a parent module that composes child modules with `for` loops over principal arrays. Share constants
  with `@export()`. Every App Service setting must live in the Bicep `appSettings` array (deploys overwrite the rest).
- Never commit keys, `.pem`, `.pfx` or secrets. Generate certificates in a temporary directory outside the repo.
- Do not purge or touch Key Vaults whose names start with `kv-inventory`; they belong to another project.
- Azure Firewall costs about 20 USD per day: do not deploy or leave resources running unless asked.

## Before you commit pipeline YAML

Run the offline checker with both repositories side by side:

```
python3 tools/verify_pipelines.py ../goat-ticket-app .
```

A template change needs a new tag (`infra-templates-vX.Y.Z`) and a matching bump of `ref` in the app pipeline.

## Working style

Reply in Vietnamese, concise, technical terms in English. Show files one by one in full. Do not deploy or change code
unless asked. Cite official documentation when asked and say plainly when a page does not state something.
