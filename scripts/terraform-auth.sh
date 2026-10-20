#!/usr/bin/env bash
# SOURCE this from AzureCLI@2 with addSpnToEnvironment: true.
# For Workload Identity Federation (OIDC) service connection.
: "${servicePrincipalId:?AzureCLI task did not supply servicePrincipalId}"
: "${tenantId:?AzureCLI task did not supply tenantId}"
: "${idToken:?AzureCLI task did not supply idToken (check WIF service connection)}"
export ARM_USE_AZUREAD=true
export ARM_USE_OIDC=true
export ARM_CLIENT_ID="$servicePrincipalId"
export ARM_TENANT_ID="$tenantId"
export ARM_OIDC_TOKEN="$idToken"
