# Init Folder Structure — GOAT Ticket Infra

Generate the following folder structure and empty placeholder files under `infra/` at the repo root.
Do not write any real Bicep logic yet — only create the files/folders with minimal placeholder
content (a one-line comment stating the file's purpose) so the structure exists and is ready to
fill in module by module.

## Structure to create

```
infra/
├── main.bicep
├── bicepconfig.json
│
├── environments/
│   ├── dev.bicepparam
│   └── prod.bicepparam
│
├── modules/
│   ├── network/
│   │   ├── vnet.bicep
│   │   ├── subnet.bicep
│   │   ├── nsg.bicep
│   │   └── routeTable.bicep
│   │
│   ├── gateway-firewall/
│   │   ├── appGateway.bicep
│   │   └── firewall.bicep
│   │
│   ├── compute/
│   │   ├── appService.bicep
│   │   └── function.bicep
│   │
│   ├── database/
│   │   ├── sql.bicep
│   │   └── cosmos.bicep
│   │
│   ├── storage/
│   │   └── storageAccount.bicep
│   │
│   ├── security/
│   │   ├── keyvault.bicep
│   │   └── rbac.bicep
│   │
│   └── privateEndpoints/
│       ├── privateEndpoints.bicep
│       └── privateDnsZones.bicep
│
├── pipelines/
│   ├── deploy-dev.yml
│   └── deploy-prod.yml
│
└── README.md
```

## Placeholder content rules

- Every `.bicep` file: start with a `// TODO:` comment stating which Azure resource(s) this
  module will define (e.g. `// TODO: VNet + 5 subnets — snet-appgw, snet-app, snet-func, snet-pe, AzureFirewallSubnet`).
- Every `.bicepparam` file: include `using '../main.bicep'` and a `// TODO: fill in per-environment values` comment.
- `main.bicep`: a `// TODO: orchestration — module calls in dependency order: network → gateway-firewall → compute → database → storage → security → privateEndpoints` comment.
- `bicepconfig.json`: minimal valid JSON `{}` — content to be filled in later.
- Pipeline `.yml` files: a `# TODO:` comment stating trigger path (`infra/*`) and deploy stages.
- `README.md`: a one-line placeholder title `# GOAT Ticket — Infrastructure` plus a `TODO: document deployment order` line.

## Do not

- Do not write actual `resource`, `module`, or `param` declarations yet.
- Do not create files outside this structure.
- Do not modify anything under `src/`, `tests/`, or the repo root.