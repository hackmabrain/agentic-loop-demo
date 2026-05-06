// Cold-standby template for swedencentral failover.
//
// This is the same template as main.bicep but parameterized for the backup
// region. The 5-minute regional failover script (scripts/failover-to-backup.sh)
// deploys this against rg-agentic-loop-demo-backup if eastus2 is degraded
// the morning of the talk.
//
// Keep this file in lockstep with main.bicep — any change there should be
// mirrored here.

@description('Suffix appended to globally-unique names. Use a distinct token from main.bicep so DNS does not collide.')
param nameSuffix string

@description('Backup region. Defaults to swedencentral.')
@allowed([
  'swedencentral'
  'australiaeast'
])
param location string = 'swedencentral'

@description('App Service plan SKU.')
param appServiceSku string = 'P1v3'

@description('Whether the staging slot starts with INJECT_ERROR=1 set.')
param stagingInjectError bool = true

@description('Tags applied to every resource.')
param tags object = {
  workload: 'agentic-loop-demo'
  owner: 'pavan-tallapragada'
  event: 'github-dev-days-sf-2026-05'
  role: 'backup'
}

var planName        = 'plan-aldemo-bk-${nameSuffix}'
var siteName        = 'app-aldemo-bk-${nameSuffix}'
var lawName         = 'law-aldemo-bk-${nameSuffix}'
var appiName        = 'appi-aldemo-bk-${nameSuffix}'
var actionGroupName = 'ag-aldemo-bk-${nameSuffix}'
var alertName       = 'alert-5xx-aldemo-bk-${nameSuffix}'

resource law 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: lawName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
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

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  sku: { name: appServiceSku, tier: 'PremiumV3' }
  kind: 'linux'
  properties: { reserved: true }
}

resource site 'Microsoft.Web/sites@2023-12-01' = {
  name: siteName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
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
        { name: 'INJECT_ERROR', value: '0' }
      ]
    }
  }
}

resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: site
  name: 'staging'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      healthCheckPath: '/'
      appSettings: [
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~20' }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appi.properties.ConnectionString }
        { name: 'INJECT_ERROR', value: stagingInjectError ? '1' : '0' }
      ]
    }
  }
}

resource actionGroup 'microsoft.insights/actionGroups@2023-01-01' = {
  name: actionGroupName
  location: 'Global'
  tags: tags
  properties: {
    groupShortName: 'aldBkSre'
    enabled: true
    webhookReceivers: [
      {
        name: 'sre-agent-webhook'
        serviceUri: 'https://example.invalid/sre-agent/placeholder'
        useCommonAlertSchema: true
      }
    ]
  }
}

resource alert5xx 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: alertName
  location: 'global'
  tags: tags
  properties: {
    description: 'BACKUP: Catalog API HTTP 5xx errors above threshold.'
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
    actions: [ { actionGroupId: actionGroup.id } ]
  }
}

output appServiceName string = site.name
output appServiceUrl string = 'https://${site.properties.defaultHostName}'
output appInsightsConnectionString string = appi.properties.ConnectionString
output logAnalyticsWorkspaceId string = law.id
