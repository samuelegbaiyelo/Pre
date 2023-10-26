//deploy Az environment for Client Portal
targetScope = 'resourceGroup'

@description('Client Id of the AAD app registration created to connect to SharePoint.')
param sharePointAppRegistrationClientId string

@description('Client Id of the AAD app registration created to connect to Dynamics.')
param dynamicsAppRegistrationClientId string

@description('URL of the dynamics envrionment used by Client portal.')
param dynamicsEnvironmentUrl string

@description('Sharepoint site URL.')
param sharePointSiteUrl string

@description('API Management service values. Allowed root-level properties are sku (string) zoneRedundant (bool) publisher (object) with sub properties email and name networkConfiguration (object) with sub properties vnetName subnetName and addressPrefix.')
param apiManagement object

@description('App Service plan Values. Allowed properties are sku (string) to deploy a new plan. If an existing plan needs to be used allowed root-level properties are name and resource group.')
param appServicePlan object

@description('App Service Plan subnet values. Allowed root-level properties are vnetName name (string) addressPrefix (string).')
param appServicePlanSubnet object

@description('Azure region where the resources are deployed.')
param location string = resourceGroup().location

@description('Name of the NSG that will be associated with APIM subnet. Security rules are defined via a variable.')
param apimNetworkSecurityGroupName string

@description('Azure Cosmos DB details. Allowed root-level properties are backupStorageRedundancy (string) capacityMode (string) and networkConfiguration (object with sub-properties vnetName and subnetName which accept string as their values).')
param cosmosDB object

@description('Name of the NSG that will be associated with the subnet used by app service plan.')
param appServicePlanNsgName string

@description('Name prefix of Azure services needed for Client Portal. ')
param resourceNamePrefix string

@description('Service Bus details. Allowed root-level properties are sku (string) publicAccess (bool) and networkConfiguration with sub-properties vnet subnet and resourceGroup.')
param serviceBus object

@description('App service details. Allowed root-level properties are corsPolicy (string) and networkConfiguration with sub-properties vnet subnet and resourceGroup.')
param appService object

@description('KeyAllowed root-level properites are purpge protection (bool) and  networkConfiguration with sub-properties vnet subnet and resourceGroup. Accepts {} as value if private endpoint and purge protection is not needed.')
param keyVault object

@description('Storage account details. Allowed root-level properties sku and networkConfiguration with sub properties vnetName and subnetName.')
param storageAccount object

@description('Array of names of file sync Virtual Machines.')
param fileSyncVirtualMachines array

@description('Sync VMs network configuration details. Allowed properties are vnetName and subnetName.')
param fileSyncVirtualMachinesNetworkConfig object

@description('Internal inbound load balancer frontend Ip Configuration. This is used by file sync/acl update api VMs to support HA API solution.')
param internalLoadBalancerFrontendConfig object

@description('Public/Exteral load balancer frontend Ip configuration. This is used by file sync/acl update api VMs to connect to Power Platform to support HA ACL update API solution.')
param publicLoadBalancerFrontendConfig object

var apimNsgRules = {
  AllowInternetInboundOverHttps: {
    priority: 100
    direction: 'Inbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: 'Internet'
    destinationAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationPortRange: '443'
  }
  AllowApiManagementInbound: {
    priority: 110
    direction: 'Inbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: 'ApiManagement.CanadaCentral'
    destinationAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationPortRange: '3443'
  }
  DenyInternetOubound: {
    priority: 4090
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Deny'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'Internet'
    destinationPortRange: '*'
  }
  AllowStorageOutbound: {
    priority: 4080
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'Storage.CanadaCentral'
    destinationPortRange: '443'
  }
  AllowAzureADOutbound: {
    priority: 4070
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'AzureActiveDirectory'
    destinationPortRange: '443'
  }
  AllowKeyVaultOutbound: {
    priority: 4060
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'AzureKeyVault.CanadaCentral'
    destinationPortRange: '443'
  }
  AllowSqlOutbound: {
    priority: 4050
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'Sql.CanadaCentral'
    destinationPortRange: '1433'
  }
  AllowEventHubOutbound: {
    priority: 4040
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'EventHub.CanadaCentral'
    destinationPortRange: '443,5671,5672'
  }
  AllowStorageOutboundOverSMB: {
    priority: 4030
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'Storage.CanadaCentral'
    destinationPortRange: '445'
  }
  AllowAzureCloudOutbound: {
    priority: 4020
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'AzureCloud.CanadaCentral'
    destinationPortRange: '443,12000'
  }
  AllowMonitorOutbound: {
    priority: 4010
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'AzureMonitor'
    destinationPortRange: '443,1886'
  }
  AllowInternetOutboundForSMTP: {
    priority: 4000
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'Internet'
    destinationPortRange: '25,587,25028'
  }
  AllowAzureConnectorsOutbound: {
    priority: 3990
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(apiManagement.networkConfiguration.addressPrefix)
    destinationAddressPrefix: 'AzureConnectors.CanadaCentral'
    destinationPortRange: '443'
  }
}

var appServicePlanNsgRules = {
  AllowAzureMonitorInbound: {
    priority: 100
    direction: 'Inbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: 'AzureMonitor'
    destinationAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationPortRange: '443'
  }
  AllowAppServiceInbound: {
    priority: 110
    direction: 'Inbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: 'AppService.CanadaCentral'
    destinationAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationPortRange: '443'
  }
  DenyInternetOutbound: {
    priority: 4090
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Deny'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'Internet'
    destinationPortRange: '*'
  }
  AllowAzureActiveDirectoryOutbound: {
    priority: 4080
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'AzureActiveDirectory'
    destinationPortRange: '*'
  }
  AllowEventHubOutbound: {
    priority: 4070
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'EventHub.CanadaCentral'
    destinationPortRange: '443,5671'
  }
  AllowServiceBusOutbound: {
    priority: 4060
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'ServiceBus.CanadaCentral'
    destinationPortRange: '443,5671'
  }
  AllowAzureKeyVaultOutbound: {
    priority: 4050
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'AzureKeyVault.CanadaCentral'
    destinationPortRange: '443'
  }
  AllowAzureCloudOutbound: {
    priority: 4040
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'AzureCloud'
    destinationPortRange: '443'
  }
  AllowAppServiceOutbound: {
    priority: 4030
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'AppService.CanadaCentral'
    destinationPortRange: '443'
  }
  AllowSharePointOnlineOutbound: {
    priority: 4020
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: '13.107.136.0/22,40.108.128.0/17,52.104.0.0/14,104.146.128.0/17,150.171.40.0/22'
    destinationPortRange: '443'
  }
  AllowAzureMonitorOutbound: {
    priority: 4010
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'AzureMonitor'
    destinationPortRange: '443'
  }
  AllowAzureStorageOutbound: {
    priority: 4000
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'Storage.CanadaCentral'
    destinationPortRange: '443'
  }
  AllowAzureConnectorsOutbound: {
    priority: 3990
    direction: 'Outbound'
    protocol: 'TCP'
    access: 'Allow'
    sourceAddressPrefix: string(appServicePlanSubnet.addressPrefix)
    destinationAddressPrefix: 'AzureConnectors.CanadaCentral'
    destinationPortRange: '443'
  }
}

var webappSettings = [
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: apiAppi.outputs.instrumentationKey
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: apiAppi.outputs.connectionString
  }
  {
    name: 'ASPNETCORE_ENVRIONMENT'
    value: 'Development'
  }
  {
    name: 'ASPNETCORE_TEMP'
    value: 'C:\\home\\Temp'
  }
  {
    name: 'AZ_CLIENT_ID'
    value: sharePointAppRegistrationClientId
  }
  {
    name: 'AZ_CLIENT_ID_DATAVERSE'
    value: dynamicsAppRegistrationClientId
  }
  {
    name: 'AZ_TENANT'
    value: 'GrantThorntonCA.onmicrosoft.com'
  }
  {
    name: 'BLOB_SUBSCRIPTION_NAME'
    value: 'uploads'
  }
  {
    name: 'BLOB_TOPIC_NAME'
    value: 'blobuploads'
  }
  {
    name: 'BlobContainerName'
    value: 'filebuffer'
  }
  {
    name: 'CERTIFICATE_NAME'
    value: 'SharePointCertificate'
  }
  {
    name: 'DATAVERSE_URL'
    value: dynamicsEnvironmentUrl //Varies per envrionment. Dynamics environment URL
  }
  {
    name: 'KEY_VAULT_NAME'
    value: vault.outputs.name
  }
  {
    name: 'SERVICE_BUS_CONNECTION'
    value: listKeys(busSas.id, busSas.apiVersion).primaryConnectionString
  }
  {
    name: 'SERVICEBUS_ERROR_TOPIC_NAME'
    value: 'errors'
  }
  {
    name: 'SERVICEBUS_SUCCESS_TOPIC-NAME'
    value: 'uploads'
  }
  {
    name: 'SP_CHUNK_SIZE'
    value: '20'
  }
  {
    name: 'SP_LIBRARY_NAME'
    value: 'ClientFiles'
  }
  {
    name: 'SP_SITE_URL'
    value: sharePointSiteUrl
  }
  {
    name: 'WEBJOBS_IDLE_TIMEOUT'
    value: '36000'
  }
  {
    name: 'WEBSITE_LOAD_USER_PROFILE'
    value: '1'
  }
  {
    name: 'WEBSITE_TIME_ZONE'
    value: 'Eastern Standard Time'
  }
  {
    name: 'WRITE_TO_BLOB'
    value: 'Yes'
  }
]

var funcappSettings = [
  {
    name: 'AzureWebJobsStorage'
    value: 'DefaultEndpointsProtocol=https;AccountName=${stAcc.name};AccountKey=${listKeys(stAcc.id, stAcc.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
  {
    name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
    value: 'DefaultEndpointsProtocol=https;AccountName=${stAcc.name};AccountKey=${listKeys(stAcc.id, stAcc.apiVersion).keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
  {
    name: 'WEBSITE_CONTENTSHARE'
    value: toLower('${resourceNamePrefix}-func')
  }
  {
    name: 'FUNCTIONS_EXTENSION_VERSION'
    value: '~4'
  }
  {
    name: 'FUNCTIONS_WORKER_RUNTIME'
    value: 'dotnet'
  }
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: flowAppi.outputs.instrumentationKey
  }
  {
    name: 'APPINSIGHTS_CONNECTIONSTRING'
    value: flowAppi.outputs.connectionString
  }
]

var apiOps = [
  {
    name: 'delete-api-filemanager'
    displayName: '/api/FileManager - DELETE'
    method: 'DELETE'
    urlTemplate: '/api/FileManager'
    templateParameters: []
    qeuryParameters: [
      {
        name: 'accountId'
        type: 'string'
        values: []
      }
      {
        name: 'engagementId'
        type: 'string'
        values: []
      }
      {
        name: 'path'
        type: 'string'
        values: []
      }
    ]
    responses: []
  }
  {
    name: 'delete-api-filemanager-id'
    displayName: '/api/FileManager/{id} - DELETE'
    method: 'DELETE'
    urlTemplate: '/api/FileManager/{id}'
    templateParameters: [
      {
        name: 'id'
        description: 'Format - int32.'
        type: 'integer'
        required: true
        values: []
      }
    ]
    responses: []
  }
  {
    name: 'get-api-filemanager'
    displayName: '/api/FileManager - GET'
    method: 'GET'
    urlTemplate: '/api/FileManager'
    templateParameters: []
    queryParameters: [
      {
        name: 'accountId'
        type: 'string'
        values: []
      }
      {
        name: 'engagementId'
        type: 'string'
        values: []
      }
      {
        name: 'path'
        type: 'string'
        values: []
      }
    ]
    responses: []
  }
  {
    name: 'get-api-filemanager-download'
    displayName: '/api/FileManager/Download - GET'
    method: 'GET'
    urlTemplate: '/api/FileManager/Download'
    templateParameters: []
    queryParameters: [
      {
        name: 'accoundId'
        type: 'string'
        values: []
      }
      {
        name: 'engagementId'
        type: 'string'
        values: []
      }
      {
        name: 'path'
        type: 'string'
        values: []
      }
    ]
    responses: []
  }
  {
    name: 'post-api-filemanager'
    displayName: '/api/FileManager -POST'
    method: 'POST'
    urlTemplate: '/api/FileManager'
    templateParameters: []
    request: {
      queryParameters: [
        {
          name: 'accountId'
          type: 'string'
          values: []
          schemaId: '63d079e23846840f84dd8173'
          typeName: 'ApiFileManagerPostRequest'
        }
        {
          name: 'enagementId'
          type: 'string'
          values: []
          schemaId: '63d079e23846840f84dd8173'
          typeName: 'ApiFileManagerPostRequest-1'
        }
        {
          name: 'path'
          type: 'string'
          values: []
          schemaId: '63d079e23846840f84dd8173'
          typeName: 'ApiFileManagerPostRequest-2'
        }
      ]
      headers: []
      representations: [
        {
          contentType: 'multipart/form-data'
          formParameters: [
            {
              name: 'file'
              type: 'string'
              values: []
            }
          ]
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
        headers: []
      }
    ]
  }
  {
    name: 'post-api-filemanager-createfolder'
    displayName: '/api/FileManager/CreateFolder - POST'
    urlTemplate: '/api/FileManager/CreateFolder'
    templateParamters: []
    request: {
      queryParameters: [
        {
          name: 'accountId'
          type: 'string'
          values: []
          schemaId: '63d079e23846840f84dd8173'
          typeName: 'ApiFileManagerCreateFolderPostRequest'
        }
        {
          name: 'engagementId'
          type: 'string'
          values: []
          schemaId: '63d079e23846840f84dd8173'
          typeName: 'ApiFileManagerCreateFolderPostRequest-1'
        }
        {
          name: 'path'
          type: 'string'
          values: []
          schemaId: '63d079e23846840f84dd8173'
          typeName: 'ApiFileManagerCreateFolderPostRequest-2'
        }
      ]
      headers: []
      representations: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
        headers: []
      }
    ]
  }
]

var vnetRG = {
  'gt-dev-vnet': 'gt-dev-rg'
  'gt-test-vnet': 'gt-test-rg'
  'gt-staging-vnet': 'gt-staging-rg'
  'gt-production-vnet': 'gt-prod-rg'
}

resource syncVM 'Microsoft.Compute/virtualMachines@2023-03-01' existing = [for each in fileSyncVirtualMachines: {
  name: each
  scope: az.resourceGroup()
}]

//get existing subnet resource for storage account private endpoint
resource stEpSnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' existing = {
  name: '${storageAccount.vnetName}/${storageAccount.subnetName}'
  scope: az.resourceGroup(vnetRG[storageAccount.vnetName])
}

//optionally get exsiting subnet resource
resource existingPlan 'Microsoft.Web/serverfarms@2022-09-01' existing = if (contains(appServicePlan, 'name') && contains(appServicePlan, 'resourceGroup') && !contains(appServicePlan, 'sku')) {
  name: appServicePlan.name
  scope: az.resourceGroup(appServicePlan.resourceGroup)
}

resource existingAspSnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' existing = if (!contains(appServicePlanSubnet, 'addressPrefix')) {
  name: '${appServicePlan.vnetName}/${appServicePlan.subnetName}'
  scope: az.resourceGroup(vnetRG[appServicePlan.vnetName])
}

resource blobPDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  scope: az.resourceGroup('gt-pr-azuremigrate-rg')
}

resource filePDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  scope: az.resourceGroup('gt-mgtprod-rg')
}

// create storage account for file buffer and funtion app that has app insights wrapper for portal file scan
resource stAcc 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: '${toLower(replace(resourceNamePrefix, '-', ''))}st'
  location: location
  sku: {
    name: storageAccount.sku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Enabled'
    supportsHttpsTrafficOnly: true
    routingPreference: {
      routingChoice: 'MicrosoftRouting'
    }
  }
  resource defBlob 'blobServices' = {
    name: 'default'
    properties: {
      automaticSnapshotPolicyEnabled: false
      changeFeed: {
        enabled: true
        retentionInDays: 7
      }
      containerDeleteRetentionPolicy: {
        days: 7
        enabled: true
      }
      restorePolicy: {
        enabled: false
      }
      deleteRetentionPolicy: {
        enabled: true
        days: 7
      }
      isVersioningEnabled: false
    }
    resource uploaderContainer 'containers' = {
      name: 'filebuffer'
      properties: {
        publicAccess: 'None'
      }
    }
  }
  resource defFile 'fileServices' = {
    name: 'default'
    properties: {
      shareDeleteRetentionPolicy: {
        enabled: true
        days: 7
      }
    }
  }
}

// app service plan subnet NSG (for new subnet)
module aspNsg 'br:gtbicepregistry.azurecr.io/network/nsg:1.0' = if (contains(appServicePlanSubnet, 'addressPrefix')) {
  name: 'DeployAppServiceNsg'
  params: {
    name: appServicePlanNsgName
    securityRules: appServicePlanNsgRules
  }
}

// deploy a new subnet for app service plan
module aspSnet 'br:gtbicepregistry.azurecr.io/network/subnet:1.0' = if (contains(appServicePlanSubnet, 'addressPrefix')) {
  name: 'DeployAppServicePlanSubnet'
  scope: az.resourceGroup(vnetRG[appServicePlanSubnet.vnetName])
  params: {
    name: appServicePlanSubnet.name
    addressPrefix: string(appServicePlanSubnet.addressPrefix)
    delegation: 'Microsoft.Web/serverFarms'
    vnetName: appServicePlanSubnet.vnetName
    networkSecurityGroupId: aspNsg.outputs.id
  }
}

// create log analytics workspace
module logWspace 'br:gtbicepregistry.azurecr.io/monitor/log-analytics-workspace:1.0' = {
  name: 'DeployLogAnalyticsWorkspace'
  params: {
    namePrefix: resourceNamePrefix
  }
}

// deploy app insights for powerApp Portal
module d365PortalAppi 'br:gtbicepregistry.azurecr.io/monitor/app-insights:1.0' = {
  name: 'DeployAppInsightsForPortal'
  params: {
    namePrefix: resourceNamePrefix
    workspaceId: logWspace.outputs.id
  }
}

//deploy app insights for file uplaoder api app service
module apiAppi 'br:gtbicepregistry.azurecr.io/monitor/app-insights:1.0' = {
  name: 'DeployAppInsightsForApi'
  params: {
    namePrefix: '${resourceNamePrefix}-app'
    workspaceId: logWspace.outputs.id
  }
}

//deploy app insights that acts as wrapper for portal file scan which is hosted on function app
module flowAppi 'br:gtbicepregistry.azurecr.io/monitor/app-insights:1.0' = {
  name: 'DeployAppInsightsForFileScanFlow'
  params: {
    location: location
    namePrefix: '${resourceNamePrefix}-func'
    workspaceId: logWspace.outputs.id
  }
}

module bus 'br:gtbicepregistry.azurecr.io/bus/namespace:1.0' = {
  name: 'DeployBus'
  params: {
    diagnosticLogsToEnable: [
      'OperationalLogs'
    ]
    diagnosticMetricsToEnable: [
      'AllMetrics'
    ]
    diagnosticSettingWorkspaceId: logWspace.outputs.id
    enableManagedIdentity: true
    namePrefix: toLower(replace(resourceNamePrefix, '-', ''))
    networkConfiguration: serviceBus.networkConfiguration
    sku: serviceBus.sku
    zoneRedundant: true
  }
}

module busQueues 'br:gtbicepregistry.azurecr.io/bus/queue:1.0' = [for (queue, i) in serviceBus.queues: if (contains(serviceBus, 'queues')) {
  name: 'DeployQueue_${queue}'
  params: {
    queueName: queue
    serviceBusNamespaceName: bus.outputs.name
  }
}]

module busTopicSub 'br:gtbicepregistry.azurecr.io/bus/topic-subscription:1.0' = [for (each, i) in serviceBus.topics: if (contains(each, 'subscription')) {
  name: 'DeployTopicwithSubscription_${each.name}'
  dependsOn: [
    busQueues
  ]
  params: {
    forwardTo: contains(each, 'forwardTo') ? each.forwardTo : ''
    serviceBusNamespaceName: bus.outputs.name
    subscriptionName: each.subscription
    topicName: each.name
  }
}]

module busTopics 'br:gtbicepregistry.azurecr.io/bus/topic:1.0' = [for (each, i) in serviceBus.topics: if (!contains(each, 'subscription')) {
  name: 'DeployTopic_${each.name}'
  dependsOn: [
    busQueues
  ]
  params: {
    serviceBusNamespaceName: bus.outputs.name
    topicName: each.name
  }
}]

// create sas rule within the bus topic used by services uploader API file sync services and as well as power app flow
resource busSas 'Microsoft.ServiceBus/namespaces/authorizationRules@2022-10-01-preview' = {
  name: '${replace(resourceNamePrefix, '-', '')}sb/portalbackend-sas'
  dependsOn: [
    bus
    busTopics
  ]
  properties: {
    rights: [
      'Manage'
      'Send'
      'Listen'
    ]
  }
}

//optionally create new app service plan for Azure app service app and function app used by portal
module newAsPlan 'br:gtbicepregistry.azurecr.io/web/plan:1.0' = if (contains(appServicePlan, 'sku') && !contains(appServicePlan, 'name') && !contains(appServicePlan, 'resourceGroup')) {
  name: 'DeployAppServicePlan'
  params: {
    location: location
    namePrefix: resourceNamePrefix
    serverOS: 'windows'
    skuName: appServicePlan.sku
    zoneRedundant: true
  }
}

//create key vault
module vault 'br:gtbicepregistry.azurecr.io/vault/key-vault:1.0' = {
  name: 'DeployKeyVault'
  params: {
    enablePurgeProtection: keyVault.purgeProtection
    location: location
    namePrefix: resourceNamePrefix
    networkConfiguration: keyVault.networkConfiguration
  }
}

//create app service to host uploader api
module webapp 'br:gtbicepregistry.azurecr.io/web/site:1.0' = {
  name: 'DeployWebapp'
  dependsOn: [
    vault
  ]
  params: {
    appServicePlanId: contains(appServicePlan, 'sku') ? newAsPlan.outputs.id : existingPlan.id
    appSettings: webappSettings
    corsPolicy: appService.corsPolicy
    diagnosticLogsToEnable: [
      'AppServiceAppLogs'
      'AppServiceConsoleLogs'
      'AppServiceHTTPLogs'
      'AppServicePlatformLogs'
    ]
    diagnosticMetricsToEnable: [
      'AllMetrics'
    ]
    diagnosticSettingWorkspaceId: logWspace.outputs.id
    kind: 'app'
    namePrefix: resourceNamePrefix
    networkConfiguration: appService.networkConfiguration
    newPhysicalPath: 'site\\wwwroot\\UploaderApi' //keep this as default for all envrionments
    runtimeStack: 'dotnet'
    vnetSubnetId: contains(appServicePlanSubnet, 'addressPrefix') ? aspSnet.outputs.id : existingAspSnet.id
  }
}

//vault access policy for app service managed identity.
module kvAccPol1 'br:gtbicepregistry.azurecr.io/vault/access-policy:1.0' = {
  name: 'VaultAccessPolicyForWebAppIdentity'
  params: {
    accessPolicyName: 'add'
    certificatePermissions: []
    keyPermissions: []
    keyVaultName: vault.outputs.name
    principalId: webapp.outputs.objectId
    secretPermissions: [ 'get' ]
  }
}

//vault access policy for app service managed identity.
@batchSize(1)
module kvAccPolVms 'br:gtbicepregistry.azurecr.io/vault/access-policy:1.0' = [for (each, i) in fileSyncVirtualMachines: if (!empty(fileSyncVirtualMachines)) {
  name: 'VaultAccessPolicyForSyncVirtualMachine${i}.Identity'
  params: {
    accessPolicyName: 'add'
    certificatePermissions: [
      'get'
    ]
    keyPermissions: []
    keyVaultName: vault.outputs.name
    principalId: syncVM[i].identity.principalId
    secretPermissions: [ 'get' ]
  }
}]

//create function app to host app insights wrapper
module funcapp 'br:gtbicepregistry.azurecr.io/web/site:1.0' = {
  name: 'DeployPortalFileScanFunctionApp'
  params: {
    appServicePlanId: (contains(appServicePlan, 'sku')) ? newAsPlan.outputs.id : existingAspSnet.id
    appSettings: funcappSettings
    kind: 'functionapp'
    namePrefix: resourceNamePrefix
    networkConfiguration: {} //not configuring private endpoint for the app.
    runtimeStack: ''
    vnetSubnetId: ''
  }
}

//create automation account
module automatAccount 'br:gtbicepregistry.azurecr.io/automation/account:1.0' = {
  name: 'DeployAutomationAccount'
  params: {
    moduleNames: [
      'Microsoft.Online.SharePoint.PowerShell'
      'SharePointPnPPowerShellOnline'
    ]
    namePrefix: resourceNamePrefix
    publicNetworkAccess: true
    runbook: [
      {
        name: 'portalfilescan'
        description: 'PowerShell runbook to update file meta data in staging SharePoint site for portal.'
        type: 'PowerShell'
      }
    ]
  }
}

//Deploy API Management
module apim 'br:gtbicepregistry.azurecr.io/apim/service:1.0' = {
  name: 'DeployAPIManagentService'
  params: {
    apimNsg: {
      name: apimNetworkSecurityGroupName
      rules: apimNsgRules
    }
    diagnosticLogsToEnable: [
      'GatewayLogs'
    ]
    diagnosticMetricsToEnable: [
      'AllMetrics'
    ]
    diagnosticSettingWorkspaceId: logWspace.outputs.id
    logAnalyticsWorkspaceId: logWspace.outputs.id
    namePrefix: resourceNamePrefix
    networkConfiguration: apiManagement.networkConfiguration
    publisherEmail: apiManagement.publisherEmail
    sku: apiManagement.sku
    virtualNetworkType: 'External'
  }
}

//Deploy Cosmos DB
module cos 'br:gtbicepregistry.azurecr.io/cosmosdb/account:1.0' = {
  name: 'DeploCosmosDBAccount'
  params: {
    backupStorageRedundancy: cosmosDB.backupStorageRedundancy
    capacityMode: cosmosDB.capacityMode
    enableManagedIdentity: true
    namePrefix: resourceNamePrefix
    networkConfiguration: cosmosDB.networkconfiguration
    sqlDatabaseName: 'FileSync'
    sqlDBContainers: [
      {
        name: 'ChangeFeedLease'
        partitionKey: '/id'
      }
      {
        name: 'FileSyncJobs'
        partitionKey: '/clrtype'
      }
    ]
  }
}

// storage account private endpoint for blob endpoint
module stAccBlobEndpoint 'br:gtbicepregistry.azurecr.io/network/private-endpoint:1.0' = {
  name: 'DeployStorageAccountBlobPrivateEndpoint'
  dependsOn: [
    funcapp
  ]
  params: {
    namePrefix: '${stAcc.name}-blob'
    privateDnsZoneId: blobPDnsZone.id
    subnetId: stEpSnet.id
    targetResourceId: stAcc.id
    targetSubResource: 'blob'
    zoneGroupConfigName: 'privatelink_blob_core_windows_net'
  }
}

// storage account private endpoint for file endpoint
module stAccFileEndpoint 'br:gtbicepregistry.azurecr.io/network/private-endpoint:1.0' = {
  name: 'DeployStorageAccountFilePrivateEndpoint'
  dependsOn: [
    funcapp
  ]
  params: {
    namePrefix: '${stAcc.name}-file'
    privateDnsZoneId: filePDnsZone.id
    subnetId: stEpSnet.id
    targetResourceId: stAcc.id
    targetSubResource: 'file'
    zoneGroupConfigName: 'privatelink_file_core_windows_net'
  }
}

// API Ops
module apimApp 'br:gtbicepregistry.azurecr.io/apim/api:1.0' = {
  name: 'OnboardAPIOnApiManagementService'
  params: {
    apimServiceName: apim.outputs.name
    description: 'Client Portal File Uploader API'
    name: 'UploaderAPI'
    operations: apiOps
    webappUrl: 'https://${webapp.outputs.url}'
  }
}

//create internal load balancer for ACL Update API solution hosted by sync VMs
module ilb 'br:gtbicepregistry.azurecr.io/network/load-balancer:1.0' = {
  name: 'DeployInternalLoadBalancerForInbound'
  params: {
    backendPoolName: 'backend-pool'
    frontendIPConfigurations: array(internalLoadBalancerFrontendConfig)
    healthProbes: [
      {
        name: 'acl-api-health-probe'
        port: 63999
      }
    ]
    inboundLoadBalancingRules: [
      {
        name: 'acl-api-load'
        frontendPort: '65000'
        backendPort: '65000'
        frontendIPConfigName: internalLoadBalancerFrontendConfig.name
        probeName: 'acl-api-health-probe'
      }
    ]
    name: '${resourceNamePrefix}-ilb'
    outboundRules: []
    type: 'Internal'
  }
}

//create public load balancer for ACL Update API solution hosted by sync VMs for the outbound communication.
module elb 'br:gtbicepregistry.azurecr.io/network/load-balancer:1.0' = {
  name: 'DeployPublicLoadBalancerForOutbound'
  params: {
    backendPoolName: 'backend-pool'
    frontendIPConfigurations: array(internalLoadBalancerFrontendConfig)
    healthProbes: [
      {
        name: 'acl-api-health-probe'
        port: 63998
      }
    ]
    inboundLoadBalancingRules: []
    name: '${resourceNamePrefix}-elb'
    outboundRules: [
      {
        name: 'acl-api-obrule'
        frontendIPConfigName: publicLoadBalancerFrontendConfig.name
      }
    ]
    type: 'Public'
  }
}

// Place the vNics of the VMs behind the load balancer.
module vNics 'br:gtbicepregistry.azurecr.io/network/nic:1.0' = if (!empty(fileSyncVirtualMachines) && !empty(fileSyncVirtualMachinesNetworkConfig)) {
  name: 'UpdateSyncVirtualMachinesNic'
  params: {
    subnetName: fileSyncVirtualMachinesNetworkConfig.subnetName
    vmNames: fileSyncVirtualMachines
    vnetName: fileSyncVirtualMachinesNetworkConfig.vnetName
    loadBalancerIds: [
      ilb.outputs.id
      elb.outputs.id
    ]
  }
}
