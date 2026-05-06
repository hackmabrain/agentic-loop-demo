// Agentic Developer Loop demo — single-file Bicep template.
//
// Resources provisioned:
//   * Log Analytics workspace (workspace-based App Insights backend)
//   * Application Insights (100% sampling)
//   * App Service Plan (Linux, P1v3)
//   * App Service (Node 20 LTS) with system-assigned managed identity
//   * Two extra deployment slots: 'staging' and 'historical'
//     (the 'production' slot is the default site)
//   * Diagnostic settings routing all logs/metrics to Log Analytics
//   * Metric Alert: HTTP 5xx > 5 in 5 min, severity 2
//   * Action Group with a placeholder webhook (Pavan replaces this with
//     the SRE Agent webhook URL during SETUP step C11)
//
// Idempotent: re-running `az deployment group create` against the same
// resource group converges to the same state without duplicates.

@description('Suffix appended to globally-unique names. Use a short, stable token (e.g. initials + 4 digits).')
param nameSuffix string

@description('Azure region. SRE Agent supports eastus2, swedencentral, australiaeast.')
@allowed([
  'eastus2'
  'swedencentral'
  'australiaeast'
])
param location string = 'eastus2'

@description('App Service plan SKU. Demo uses P1v3 for fast cold starts.')
param appServiceSku string = 'P1v3'

@description('Whether the staging slot starts with INJECT_ERROR=1 set. The demo Wednesday staging step relies on this default.')
param stagingInjectError bool = true

@description('Tags applied to every resource.')
param tags object = {
  workload: 'agentic-loop-demo'
  owner: 'pavan-tallapragada'
  event: 'github-dev-days-sf-2026-05'
}

// ---------------------------------------------------------------------------
// Names
// ---------------------------------------------------------------------------
var planName        = 'plan-aldemo-${nameSuffix}'
var siteName        = 'app-aldemo-${nameSuffix}'
var lawName         = 'law-aldemo-${nameSuffix}'
var appiName        = 'appi-aldemo-${nameSuffix}'
var actionGroupName = 'ag-aldemo-${nameSuffix}'
var alertName       = 'alert-5xx-aldemo-${nameSuffix}'

// ---------------------------------------------------------------------------
// Log Analytics + Application Insights
// ---------------------------------------------------------------------------
resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: appiName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
    SamplingPercentage: 100
    IngestionMode: 'LogAnalytics'
  }
}

// ---------------------------------------------------------------------------
// App Service Plan + App Service
// ---------------------------------------------------------------------------
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: {
    name: appServiceSku
    tier: 'PremiumV3'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: siteName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      healthCheckPath: '/'
      appSettings: [
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~20' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appi.properties.ConnectionString }
        { name: 'ApplicationInsightsAgent_EXTENSION_VERSION', value: '~3' }
        { name: 'XDT_MicrosoftApplicationInsights_Mode', value: 'recommended' }
        { name: 'INJECT_ERROR', value: '0' }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Slots: staging (always INJECT_ERROR=1 by default for the demo trigger) and historical
// ---------------------------------------------------------------------------
resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: site
  name: 'staging'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      healthCheckPath: '/'
      appSettings: [
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~20' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appi.properties.ConnectionString }
        { name: 'ApplicationInsightsAgent_EXTENSION_VERSION', value: '~3' }
        { name: 'INJECT_ERROR', value: stagingInjectError ? '1' : '0' }
      ]
    }
  }
}

resource historicalSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: site
  name: 'historical'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      healthCheckPath: '/'
      appSettings: [
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~20' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appi.properties.ConnectionString }
        { name: 'ApplicationInsightsAgent_EXTENSION_VERSION', value: '~3' }
        { name: 'INJECT_ERROR', value: '0' }
      ]
    }
  }
}

// ---------------------------------------------------------------------------
// Diagnostic settings — site & slots → Log Analytics
// ---------------------------------------------------------------------------
resource siteDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: site
  name: 'send-to-law'
  properties: {
    workspaceId: law.id
    logs: [
      { category: 'AppServiceHTTPLogs',           enabled: true }
      { category: 'AppServiceConsoleLogs',        enabled: true }
      { category: 'AppServiceAppLogs',            enabled: true }
      { category: 'AppServicePlatformLogs',       enabled: true }
      { category: 'AppServiceAuditLogs',          enabled: true }
      { category: 'AppServiceIPSecAuditLogs',     enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics', enabled: true }
    ]
  }
}

// ---------------------------------------------------------------------------
// Action group: SRE Agent webhook target. Webhook URL is a placeholder that
// Pavan updates in SETUP step C11. The placeholder is acceptable in Bicep —
// no traffic is sent until the alert fires.
// ---------------------------------------------------------------------------
resource actionGroup 'microsoft.insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  // Action groups must be deployed to 'Global' regardless of the resource
  // group's region.
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'aldemoSre'
    enabled: true
    webhookReceivers: [
      {
        name: 'sre-agent-webhook'
        // PLACEHOLDER — Pavan updates this in SETUP C11 after SRE Agent
        // is provisioned. The placeholder URL never receives real traffic
        // until the metric alert fires AND the URL is replaced.
        serviceUri: 'https://example.invalid/sre-agent/placeholder'
        useCommonAlertSchema: true
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Metric Alert: HTTP 5xx > 5 over 5 min, severity 2
// ---------------------------------------------------------------------------
resource alert5xx 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  tags: tags
  properties: {
    description: 'Catalog API HTTP 5xx errors above threshold — handed to SRE Agent for investigation.'
    severity: 2
    enabled: true
    scopes: [ site.id ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    targetResourceType: 'Microsoft.Web/sites'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Http5xx'
          metricNamespace: 'Microsoft.Web/sites'
          metricName: 'Http5xx'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    autoMitigate: true
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}

// ---------------------------------------------------------------------------
// Outputs
// ---------------------------------------------------------------------------
output appServiceName string = site.name
output appServiceUrl string = 'https://${site.properties.defaultHostName}'
output appServiceStagingUrl string = 'https://${stagingSlot.properties.defaultHostName}'
output appServiceHistoricalUrl string = 'https://${historicalSlot.properties.defaultHostName}'
output appInsightsConnectionString string = appi.properties.ConnectionString
output appInsightsName string = appi.name
output logAnalyticsWorkspaceId string = law.id
output logAnalyticsName string = law.name
output actionGroupId string = actionGroup.id
output actionGroupName string = actionGroup.name
output alertId string = alert5xx.id
output sitePrincipalId string = site.identity.principalId
