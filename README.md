# GOAT Ticket — Infrastructure

Azure infrastructure-as-code and CI/CD pipeline for the GOAT Ticket platform, deployed at subscription scope across two resource groups per environment (`rg-goat-network-{env}`, `rg-goat-app-{env}`) in `southeastasia`.

## Repository structure

```
deploy/
├── bicep/
│   ├── main.bicep           # subscription-scope orchestration entry point
│   ├── bicepconfig.json     # Bicep linter config, co-located with the sources it governs
│   └── modules/              # network, gateway-firewall, compute, database, storage, security, privateEndpoints
│
├── pipeline/
│   ├── azure-pipelines-infra.yml   # stage/parameter orchestration only — no inline bash
│   └── templates/
│       └── deploy-environment.yml  # reusable stage template, parameterized by environment
│
├── script/                   # standalone scripts invoked by pipeline steps (lint, validate, what-if, deploy)
│
└── variables/
    ├── dev.bicepparam
    └── prod.bicepparam
```

Tool-root config files that depend on repository-root discovery (`.checkov.yaml`, `ps-rule.yaml`) stay at the repository root.

## Deploying

The pipeline (`deploy/pipeline/azure-pipelines-infra.yml`) runs on `infra-v*.*.*` tags. It runs a consolidated Quality Checks stage (lint, validate, security scan, what-if against `dev`), then deploys to `dev`, then to `prod` — each deploy stage is an instantiation of `deploy/pipeline/templates/deploy-environment.yml` parameterized by `environment`. Production deployment is gated by an Azure DevOps Environment Approval on `goat-prod`.

To validate or preview changes locally:

```bash
bash deploy/script/lint-bicep.sh
bash deploy/script/validate-deployment.sh dev deploy/variables/dev.bicepparam
bash deploy/script/preview-changes.sh dev deploy/variables/dev.bicepparam
```

See `specs/001-infra-pipeline-refactor/quickstart.md` for the full validation guide.
