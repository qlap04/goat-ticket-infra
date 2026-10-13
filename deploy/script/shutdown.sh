#!/usr/bin/env bash
# Deletes the two expensive network resources of one environment: Azure Firewall and Application Gateway.
# Manual helper for saving credit, not part of a pipeline.
#
# Usage:
#   ./shutdown.sh [environment]          show the plan, delete nothing   (default environment: dev)
#   ./shutdown.sh [environment] --yes    delete for real
#
# Only the two names below are ever touched. Everything that must survive is left alone on purpose:
#   id-agw-<env>   managed identity: a new one gets a new principal id and loses the Key Vault certificate role
#   pip-agw-<env>  public IP: a new one changes the address the DNS record points at
#   wafp-<env>, afwp-<env>, route tables, VNet, Key Vault, storage, databases
#
# To bring them back, run the infra pipeline with "Deploy network" switched on.

set -euo pipefail

environment="dev"
confirmed="no"
for arg in "$@"; do
  case "$arg" in
    --yes) confirmed="yes" ;;
    -*)    echo "Unknown option: $arg" >&2; exit 2 ;;
    *)     environment="$arg" ;;
  esac
done

# Names follow modules/gateway-firewall/firewall.bicep and appGateway.bicep.
resource_group="rg-goat-network-${environment}"
firewall="afw-goat-${environment}"
app_gateway="agw-goat-${environment}"

command -v az >/dev/null || { echo "Azure CLI (az) is not installed" >&2; exit 1; }
az account show >/dev/null 2>&1 || { echo "Not signed in: run 'az login' first" >&2; exit 1; }

echo "Subscription : $(az account show --query '[name, id]' -o tsv | paste -sd ' ' -)"
echo "Environment  : ${environment}"
echo "Resource grp : ${resource_group}"
echo

exists() {  # exists <resource type> <name>
  az resource show -g "$resource_group" -n "$2" --resource-type "$1" >/dev/null 2>&1
}

wait_gone() {  # wait_gone <resource type> <name>, gives up after 30 minutes
  local waited=0
  while exists "$1" "$2"; do
    if [ "$waited" -ge 1800 ]; then echo "  still deleting after 30 minutes: $2" >&2; return 1; fi
    sleep 20; waited=$((waited + 20)); echo "  waiting for $2 ... ${waited}s"
  done
  echo "  gone: $2"
}

delete_one() {  # delete_one <label> <resource type> <name>
  local label=$1 type=$2 name=$3
  if ! az group show -n "$resource_group" >/dev/null 2>&1; then
    echo "[skip] resource group $resource_group does not exist"; return 0
  fi
  if ! exists "$type" "$name"; then
    echo "[skip] $label $name does not exist"; return 0
  fi
  if [ "$confirmed" != "yes" ]; then
    echo "[plan] would delete $label $name"; return 0
  fi
  echo "[delete] $label $name (an Application Gateway can take 15 minutes)"
  # The delete call blocks until Azure has finished, so it runs in the background and the
  # foreground prints a line every 20 seconds instead of staying silent.
  az resource delete -g "$resource_group" -n "$name" --resource-type "$type" &
  local pid=$! elapsed=0
  while kill -0 "$pid" 2>/dev/null; do
    sleep 20; elapsed=$((elapsed + 20)); echo "  still deleting $name ... ${elapsed}s"
  done
  wait "$pid"
  wait_gone "$type" "$name"
}

delete_one "Azure Firewall"       "Microsoft.Network/azureFirewalls"      "$firewall"
delete_one "Application Gateway"  "Microsoft.Network/applicationGateways" "$app_gateway"

echo
if [ "$confirmed" = "yes" ]; then
  echo "Done. The route 0.0.0.0/0 still points at the firewall's old address, so outbound internet from the app subnets is blocked until the network is deployed again."
else
  echo "Nothing was deleted. Run again with --yes to delete."
fi
