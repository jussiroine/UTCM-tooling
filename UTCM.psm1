#Requires -Version 5.1
<#
.SYNOPSIS
    UTCM - Unified Tenant Configuration Management PowerShell Module

.DESCRIPTION
    This module provides PowerShell cmdlets for interacting with Microsoft Graph
    Unified Tenant Configuration Management (UTCM) APIs. It enables:
    - Configuration monitoring across Microsoft 365 workloads
    - Drift detection and management
    - Configuration snapshots for auditing and baseline creation

.NOTES
    Requires Microsoft.Graph.Authentication module
    Uses Microsoft Graph Beta API endpoints
#>

#region Module Variables

# UTCM Service Principal Application ID (official Microsoft app)
$script:UTCMAppId = '03b07b79-c5bc-4b5e-9bfa-13acf4a99998'

# Microsoft Graph Service Principal Application ID
$script:GraphAppId = '00000003-0000-0000-c000-000000000000'

# Graph Beta API base URI
$script:GraphBetaUri = 'https://graph.microsoft.com/beta'

# UTCM API endpoints
$script:UTCMEndpoints = @{
    Monitors      = '/tenantConfiguration/monitors'
    Drifts        = '/tenantConfiguration/drifts'
    SnapshotJobs  = '/tenantConfiguration/snapshotJobs'
}

# Required permissions for UTCM
$script:UTCMPermissions = @{
    Read      = 'ConfigurationMonitoring.Read.All'
    ReadWrite = 'ConfigurationMonitoring.ReadWrite.All'
}

# Supported workloads and their resource types
$script:SupportedWorkloads = @{
    'Microsoft Defender' = @{
        Description = 'Microsoft Defender for Endpoint, Identity, Office 365, and Cloud Apps'
        ResourceTypes = @('securityDefaults', 'defenderSettings')
    }
    'Microsoft Entra' = @{
        Description = 'Azure Active Directory / Microsoft Entra ID'
        ResourceTypes = @('conditionalAccessPolicy', 'authenticationMethodsPolicy', 'crossTenantAccessPolicy')
    }
    'Microsoft Exchange Online' = @{
        Description = 'Exchange Online mail flow, transport rules, and policies'
        ResourceTypes = @('transportRule', 'acceptedDomain', 'remoteConnector', 'organizationConfig')
    }
    'Microsoft Intune' = @{
        Description = 'Device management and compliance policies'
        ResourceTypes = @('deviceCompliancePolicy', 'deviceConfigurationProfile', 'appProtectionPolicy')
    }
    'Microsoft Purview' = @{
        Description = 'Data governance, compliance, and information protection'
        ResourceTypes = @('sensitivityLabel', 'dlpPolicy', 'retentionPolicy')
    }
    'Microsoft Teams' = @{
        Description = 'Teams policies and settings'
        ResourceTypes = @('teamsMeetingPolicy', 'teamsMessagingPolicy', 'teamsCallingPolicy')
    }
}

#endregion

#region Private Helper Functions

function Test-UTCMConnection {
    <#
    .SYNOPSIS
        Tests if there is an active Microsoft Graph connection with required permissions.
    #>
    [CmdletBinding()]
    param()
    
    try {
        $context = Get-MgContext
        if (-not $context) {
            throw "Not connected to Microsoft Graph. Run Connect-UTCM first."
        }
        return $true
    }
    catch {
        throw "Not connected to Microsoft Graph. Run Connect-UTCM first. Error: $($_.Exception.Message)"
    }
}

function Invoke-UTCMGraphRequest {
    <#
    .SYNOPSIS
        Wrapper for Microsoft Graph API requests with error handling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,
        
        [Parameter()]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',
        
        [Parameter()]
        [object]$Body,
        
        [Parameter()]
        [switch]$Raw
    )
    
    Test-UTCMConnection | Out-Null
    
    $params = @{
        Uri    = $Uri
        Method = $Method
    }
    
    if ($Body) {
        $params['Body'] = $Body | ConvertTo-Json -Depth 20
        $params['ContentType'] = 'application/json'
    }
    
    try {
        $response = Invoke-MgGraphRequest @params
        
        if ($Raw) {
            return $response
        }
        
        # Handle OData collections
        if ($response.value) {
            return $response.value
        }
        
        return $response
    }
    catch {
        $errorMessage = $_.Exception.Message
        if ($_.ErrorDetails.Message) {
            try {
                $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
                $errorMessage = "$($errorDetails.error.code): $($errorDetails.error.message)"
            }
            catch {
                $errorMessage = $_.ErrorDetails.Message
            }
        }
        throw "Graph API request failed: $errorMessage"
    }
}

function ConvertTo-UTCMMonitorObject {
    <#
    .SYNOPSIS
        Converts raw API response to typed PSCustomObject for monitors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject
    )
    
    process {
        if (-not $InputObject) { return }
        
        $obj = [PSCustomObject]@{
            PSTypeName              = 'UTCM.Monitor'
            Id                      = $InputObject.id
            DisplayName             = $InputObject.displayName
            Description             = $InputObject.description
            Status                  = $InputObject.status
            Mode                    = $InputObject.mode
            MonitorRunFrequencyInHours = $InputObject.monitorRunFrequencyInHours
            TenantId                = $InputObject.tenantId
            CreatedDateTime         = if ($InputObject.createdDateTime) { [datetime]$InputObject.createdDateTime } else { $null }
            LastModifiedDateTime    = if ($InputObject.lastModifiedDateTime) { [datetime]$InputObject.lastModifiedDateTime } else { $null }
            CreatedBy               = $InputObject.createdBy
            LastModifiedBy          = $InputObject.lastModifiedBy
            InactivationReason      = $InputObject.inactivationReason
            Parameters              = $InputObject.parameters
        }
        
        return $obj
    }
}

function ConvertTo-UTCMDriftObject {
    <#
    .SYNOPSIS
        Converts raw API response to typed PSCustomObject for drifts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject
    )
    
    process {
        if (-not $InputObject) { return }
        
        $obj = [PSCustomObject]@{
            PSTypeName                 = 'UTCM.Drift'
            Id                         = $InputObject.id
            MonitorId                  = $InputObject.monitorId
            ResourceType               = $InputObject.resourceType
            BaselineResourceDisplayName = $InputObject.baselineResourceDisplayName
            Status                     = $InputObject.status
            FirstReportedDateTime      = if ($InputObject.firstReportedDateTime) { [datetime]$InputObject.firstReportedDateTime } else { $null }
            TenantId                   = $InputObject.tenantId
            ResourceInstanceIdentifier = $InputObject.resourceInstanceIdentifier
            DriftedProperties          = $InputObject.driftedProperties
        }
        
        return $obj
    }
}

function ConvertTo-UTCMSnapshotJobObject {
    <#
    .SYNOPSIS
        Converts raw API response to typed PSCustomObject for snapshot jobs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject
    )
    
    process {
        if (-not $InputObject) { return }
        
        $obj = [PSCustomObject]@{
            PSTypeName        = 'UTCM.SnapshotJob'
            Id                = $InputObject.id
            DisplayName       = $InputObject.displayName
            Description       = $InputObject.description
            Status            = $InputObject.status
            TenantId          = $InputObject.tenantId
            Resources         = $InputObject.resources
            ResourceLocation  = $InputObject.resourceLocation
            CreatedDateTime   = if ($InputObject.createdDateTime) { [datetime]$InputObject.createdDateTime } else { $null }
            CompletedDateTime = if ($InputObject.completedDateTime) { [datetime]$InputObject.completedDateTime } else { $null }
            CreatedBy         = $InputObject.createdBy
            ErrorDetails      = $InputObject.errorDetails
        }
        
        return $obj
    }
}

function ConvertTo-UTCMBaselineObject {
    <#
    .SYNOPSIS
        Converts raw API response to typed PSCustomObject for baselines.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [object]$InputObject
    )
    
    process {
        if (-not $InputObject) { return }
        
        $obj = [PSCustomObject]@{
            PSTypeName  = 'UTCM.Baseline'
            Id          = $InputObject.id
            DisplayName = $InputObject.displayName
            Description = $InputObject.description
            Parameters  = $InputObject.parameters
            Resources   = $InputObject.resources
        }
        
        return $obj
    }
}

#endregion

#region Authentication Cmdlets

function Connect-UTCM {
    <#
    .SYNOPSIS
        Connects to Microsoft Graph with permissions required for UTCM operations.

    .DESCRIPTION
        Establishes a connection to Microsoft Graph using the specified authentication method.
        Requests the ConfigurationMonitoring.Read.All and ConfigurationMonitoring.ReadWrite.All permissions.

    .PARAMETER Scopes
        Additional scopes to request beyond the default UTCM permissions.

    .PARAMETER TenantId
        The tenant ID to connect to. If not specified, uses the home tenant.

    .PARAMETER ClientId
        The application (client) ID to use for authentication. Required for app-only auth.

    .PARAMETER CertificateThumbprint
        Certificate thumbprint for app-only authentication.

    .PARAMETER ClientSecretCredential
        PSCredential object containing the client secret for app-only authentication.

    .EXAMPLE
        Connect-UTCM
        Connects using interactive authentication with default UTCM permissions.

    .EXAMPLE
        Connect-UTCM -TenantId "contoso.onmicrosoft.com"
        Connects to a specific tenant using interactive authentication.

    .EXAMPLE
        Connect-UTCM -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint
        Connects using certificate-based app-only authentication.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        [Parameter()]
        [string[]]$Scopes,
        
        [Parameter()]
        [string]$TenantId,
        
        [Parameter(ParameterSetName = 'AppOnly', Mandatory)]
        [Parameter(ParameterSetName = 'AppOnlySecret', Mandatory)]
        [string]$ClientId,
        
        [Parameter(ParameterSetName = 'AppOnly', Mandatory)]
        [string]$CertificateThumbprint,
        
        [Parameter(ParameterSetName = 'AppOnlySecret', Mandatory)]
        [PSCredential]$ClientSecretCredential
    )
    
    # Build the required scopes
    $requiredScopes = @(
        $script:UTCMPermissions.ReadWrite
    )
    
    if ($Scopes) {
        $requiredScopes += $Scopes
    }
    
    $connectParams = @{}
    
    if ($TenantId) {
        $connectParams['TenantId'] = $TenantId
    }
    
    switch ($PSCmdlet.ParameterSetName) {
        'Interactive' {
            $connectParams['Scopes'] = $requiredScopes
        }
        'AppOnly' {
            $connectParams['ClientId'] = $ClientId
            $connectParams['CertificateThumbprint'] = $CertificateThumbprint
        }
        'AppOnlySecret' {
            $connectParams['ClientId'] = $ClientId
            $connectParams['ClientSecretCredential'] = $ClientSecretCredential
        }
    }
    
    try {
        Write-Verbose "Connecting to Microsoft Graph..."
        Connect-MgGraph @connectParams
        
        $context = Get-MgContext
        Write-Host "Connected to Microsoft Graph" -ForegroundColor Green
        Write-Host "  Account: $($context.Account)" -ForegroundColor Cyan
        Write-Host "  Tenant:  $($context.TenantId)" -ForegroundColor Cyan
        
        return $context
    }
    catch {
        throw "Failed to connect to Microsoft Graph: $($_.Exception.Message)"
    }
}

function Disconnect-UTCM {
    <#
    .SYNOPSIS
        Disconnects from Microsoft Graph.

    .DESCRIPTION
        Terminates the current Microsoft Graph session.

    .EXAMPLE
        Disconnect-UTCM
    #>
    [CmdletBinding()]
    param()
    
    Disconnect-MgGraph
    Write-Host "Disconnected from Microsoft Graph" -ForegroundColor Yellow
}

function Initialize-UTCMServicePrincipal {
    <#
    .SYNOPSIS
        Adds the UTCM service principal to your tenant.

    .DESCRIPTION
        Creates the Unified Tenant Configuration Management service principal in your tenant.
        This is a prerequisite for using UTCM monitoring features.

    .PARAMETER Force
        Skips confirmation prompt.

    .EXAMPLE
        Initialize-UTCMServicePrincipal
        Creates the UTCM service principal in the connected tenant.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [switch]$Force
    )
    
    Test-UTCMConnection | Out-Null
    
    # Check if service principal already exists
    Write-Verbose "Checking if UTCM service principal exists..."
    
    try {
        $existingSp = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$($script:UTCMAppId)'" -Method GET
        
        if ($existingSp.value -and $existingSp.value.Count -gt 0) {
            Write-Host "UTCM service principal already exists in this tenant." -ForegroundColor Yellow
            Write-Host "  Object ID: $($existingSp.value[0].id)" -ForegroundColor Cyan
            Write-Host "  Display Name: $($existingSp.value[0].displayName)" -ForegroundColor Cyan
            return $existingSp.value[0]
        }
    }
    catch {
        Write-Verbose "Service principal not found, will create it."
    }
    
    if (-not $Force -and -not $PSCmdlet.ShouldProcess("UTCM Service Principal", "Create in tenant")) {
        return
    }
    
    # Create the service principal
    Write-Verbose "Creating UTCM service principal..."
    
    $body = @{
        appId = $script:UTCMAppId
    }
    
    try {
        $sp = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals" -Method POST -Body ($body | ConvertTo-Json)
        
        Write-Host "UTCM service principal created successfully!" -ForegroundColor Green
        Write-Host "  Object ID: $($sp.id)" -ForegroundColor Cyan
        Write-Host "  Display Name: $($sp.displayName)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next step: Run Grant-UTCMPermission to grant the required permissions." -ForegroundColor Yellow
        
        return $sp
    }
    catch {
        throw "Failed to create UTCM service principal: $($_.Exception.Message)"
    }
}

function Grant-UTCMPermission {
    <#
    .SYNOPSIS
        Grants permissions to the UTCM service principal.

    .DESCRIPTION
        Assigns Microsoft Graph app roles to the UTCM service principal,
        enabling it to access the required APIs for configuration monitoring.

    .PARAMETER Permissions
        Array of permission names to grant. Defaults to common permissions needed for UTCM.

    .PARAMETER Force
        Skips confirmation prompt.

    .EXAMPLE
        Grant-UTCMPermission -Permissions @('User.Read.All', 'Policy.Read.All')
        Grants the specified permissions to the UTCM service principal.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string[]]$Permissions = @('User.Read.All', 'Policy.Read.All', 'Directory.Read.All'),
        
        [Parameter()]
        [switch]$Force
    )
    
    Test-UTCMConnection | Out-Null
    
    # Get the Microsoft Graph service principal
    Write-Verbose "Getting Microsoft Graph service principal..."
    $graphSp = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$($script:GraphAppId)'" -Method GET
    
    if (-not $graphSp.value -or $graphSp.value.Count -eq 0) {
        throw "Microsoft Graph service principal not found in tenant."
    }
    
    $graphSpId = $graphSp.value[0].id
    $graphAppRoles = $graphSp.value[0].appRoles
    
    # Get the UTCM service principal
    Write-Verbose "Getting UTCM service principal..."
    $utcmSp = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '$($script:UTCMAppId)'" -Method GET
    
    if (-not $utcmSp.value -or $utcmSp.value.Count -eq 0) {
        throw "UTCM service principal not found. Run Initialize-UTCMServicePrincipal first."
    }
    
    $utcmSpId = $utcmSp.value[0].id
    
    $results = @()
    
    foreach ($permission in $Permissions) {
        $appRole = $graphAppRoles | Where-Object { $_.value -eq $permission }
        
        if (-not $appRole) {
            Write-Warning "Permission '$permission' not found in Microsoft Graph. Skipping."
            continue
        }
        
        if (-not $Force -and -not $PSCmdlet.ShouldProcess($permission, "Grant to UTCM service principal")) {
            continue
        }
        
        $body = @{
            principalId = $utcmSpId
            resourceId  = $graphSpId
            appRoleId   = $appRole.id
        }
        
        try {
            Write-Verbose "Granting permission: $permission"
            $result = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$utcmSpId/appRoleAssignments" -Method POST -Body ($body | ConvertTo-Json)
            
            $results += [PSCustomObject]@{
                Permission = $permission
                Status     = 'Granted'
                AppRoleId  = $appRole.id
            }
            
            Write-Host "  Granted: $permission" -ForegroundColor Green
        }
        catch {
            if ($_.Exception.Message -like "*already exists*" -or $_.ErrorDetails.Message -like "*already exists*") {
                $results += [PSCustomObject]@{
                    Permission = $permission
                    Status     = 'Already Granted'
                    AppRoleId  = $appRole.id
                }
                Write-Host "  Already granted: $permission" -ForegroundColor Yellow
            }
            else {
                $results += [PSCustomObject]@{
                    Permission = $permission
                    Status     = "Failed: $($_.Exception.Message)"
                    AppRoleId  = $appRole.id
                }
                Write-Warning "Failed to grant '$permission': $($_.Exception.Message)"
            }
        }
    }
    
    return $results
}

#endregion

#region Monitor Cmdlets

function Get-UTCMMonitor {
    <#
    .SYNOPSIS
        Gets UTCM configuration monitors.

    .DESCRIPTION
        Retrieves one or more configuration monitors from the tenant.
        Monitors run periodically to detect configuration drift.

    .PARAMETER Id
        The ID of a specific monitor to retrieve.

    .PARAMETER DisplayName
        Filter monitors by display name (contains match).

    .PARAMETER Status
        Filter monitors by status (active, inactive).

    .EXAMPLE
        Get-UTCMMonitor
        Gets all configuration monitors in the tenant.

    .EXAMPLE
        Get-UTCMMonitor -Id "12345678-1234-1234-1234-123456789012"
        Gets a specific monitor by ID.

    .EXAMPLE
        Get-UTCMMonitor -Status active
        Gets all active monitors.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('MonitorId')]
        [string]$Id,
        
        [Parameter(ParameterSetName = 'List')]
        [string]$DisplayName,
        
        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('active', 'inactive')]
        [string]$Status
    )
    
    process {
        $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.Monitors)"
        
        if ($Id) {
            $uri = "$uri/$Id"
        }
        else {
            $filters = @()
            
            if ($DisplayName) {
                $filters += "contains(displayName, '$DisplayName')"
            }
            
            if ($Status) {
                $filters += "status eq '$Status'"
            }
            
            if ($filters.Count -gt 0) {
                $uri += "?`$filter=" + ($filters -join ' and ')
            }
        }
        
        $result = Invoke-UTCMGraphRequest -Uri $uri
        
        if ($Id) {
            $result | ConvertTo-UTCMMonitorObject
        }
        else {
            $result | ForEach-Object { $_ | ConvertTo-UTCMMonitorObject }
        }
    }
}

function New-UTCMMonitor {
    <#
    .SYNOPSIS
        Creates a new UTCM configuration monitor.

    .DESCRIPTION
        Creates a new configuration monitor that will periodically check for configuration drift.
        Monitors run every 6 hours at fixed times (6 AM, 12 PM, 6 PM, 12 AM GMT).

    .PARAMETER DisplayName
        A user-friendly name for the monitor.

    .PARAMETER Description
        A description of what the monitor tracks.

    .PARAMETER Baseline
        The baseline configuration as a hashtable or object. Must contain resources and properties to monitor.

    .PARAMETER BaselineJson
        Path to a JSON file containing the baseline configuration.

    .PARAMETER Parameters
        Optional parameters for the baseline as a hashtable.

    .EXAMPLE
        $baseline = @{
            displayName = "CA Policy Baseline"
            resources = @(
                @{
                    resourceType = "conditionalAccessPolicy"
                    properties = @(
                        @{ name = "state"; value = "enabled" }
                    )
                }
            )
        }
        New-UTCMMonitor -DisplayName "CA Monitor" -Baseline $baseline

    .EXAMPLE
        New-UTCMMonitor -DisplayName "Exchange Monitor" -BaselineJson ".\baseline.json"
    #>
    [CmdletBinding(DefaultParameterSetName = 'Object')]
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter(ParameterSetName = 'Object', Mandatory)]
        [hashtable]$Baseline,
        
        [Parameter(ParameterSetName = 'JsonFile', Mandatory)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$BaselineJson,
        
        [Parameter()]
        [hashtable]$Parameters
    )
    
    # Load baseline from JSON if provided
    if ($BaselineJson) {
        $Baseline = Get-Content -Path $BaselineJson -Raw | ConvertFrom-Json -AsHashtable
    }
    
    $body = @{
        displayName = $DisplayName
        baseline    = $Baseline
    }
    
    if ($Description) {
        $body['description'] = $Description
    }
    
    if ($Parameters) {
        $body['parameters'] = $Parameters
    }
    
    $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.Monitors)"
    
    $result = Invoke-UTCMGraphRequest -Uri $uri -Method POST -Body $body
    
    Write-Host "Monitor created successfully!" -ForegroundColor Green
    
    $result | ConvertTo-UTCMMonitorObject
}

function Set-UTCMMonitor {
    <#
    .SYNOPSIS
        Updates an existing UTCM configuration monitor.

    .DESCRIPTION
        Updates the properties of an existing configuration monitor.
        Note: Updating the baseline will delete all previously generated monitoring results and drifts.

    .PARAMETER Id
        The ID of the monitor to update.

    .PARAMETER DisplayName
        New display name for the monitor.

    .PARAMETER Description
        New description for the monitor.

    .PARAMETER Baseline
        New baseline configuration as a hashtable.

    .PARAMETER BaselineJson
        Path to a JSON file containing the new baseline configuration.

    .EXAMPLE
        Set-UTCMMonitor -Id $monitorId -DisplayName "Updated Monitor Name"

    .EXAMPLE
        Set-UTCMMonitor -Id $monitorId -BaselineJson ".\new-baseline.json"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('MonitorId')]
        [string]$Id,
        
        [Parameter()]
        [string]$DisplayName,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter(ParameterSetName = 'Object')]
        [hashtable]$Baseline,
        
        [Parameter(ParameterSetName = 'JsonFile')]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$BaselineJson
    )
    
    process {
        if ($BaselineJson) {
            $Baseline = Get-Content -Path $BaselineJson -Raw | ConvertFrom-Json -AsHashtable
        }
        
        $body = @{}
        
        if ($DisplayName) { $body['displayName'] = $DisplayName }
        if ($Description) { $body['description'] = $Description }
        if ($Baseline) { $body['baseline'] = $Baseline }
        
        if ($body.Count -eq 0) {
            Write-Warning "No properties specified to update."
            return
        }
        
        if ($Baseline -and -not $PSCmdlet.ShouldProcess($Id, "Update monitor baseline (this will delete existing drifts and results)")) {
            return
        }
        
        $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.Monitors)/$Id"
        
        $result = Invoke-UTCMGraphRequest -Uri $uri -Method PATCH -Body $body
        
        Write-Host "Monitor updated successfully!" -ForegroundColor Green
        
        $result | ConvertTo-UTCMMonitorObject
    }
}

function Remove-UTCMMonitor {
    <#
    .SYNOPSIS
        Deletes a UTCM configuration monitor.

    .DESCRIPTION
        Permanently deletes a configuration monitor and all associated drifts and results.

    .PARAMETER Id
        The ID of the monitor to delete.

    .PARAMETER Force
        Skips confirmation prompt.

    .EXAMPLE
        Remove-UTCMMonitor -Id "12345678-1234-1234-1234-123456789012"

    .EXAMPLE
        Get-UTCMMonitor -DisplayName "Test" | Remove-UTCMMonitor -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('MonitorId')]
        [string]$Id,
        
        [Parameter()]
        [switch]$Force
    )
    
    process {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess($Id, "Delete monitor")) {
            return
        }
        
        $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.Monitors)/$Id"
        
        Invoke-UTCMGraphRequest -Uri $uri -Method DELETE | Out-Null
        
        Write-Host "Monitor deleted successfully." -ForegroundColor Green
    }
}

#endregion

#region Baseline Cmdlets

function Get-UTCMBaseline {
    <#
    .SYNOPSIS
        Gets the baseline configuration for a monitor.

    .DESCRIPTION
        Retrieves the configuration baseline attached to a specific monitor.

    .PARAMETER MonitorId
        The ID of the monitor to get the baseline for.

    .EXAMPLE
        Get-UTCMBaseline -MonitorId "12345678-1234-1234-1234-123456789012"

    .EXAMPLE
        Get-UTCMMonitor | Get-UTCMBaseline
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$MonitorId
    )
    
    process {
        $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.Monitors)/$MonitorId/baseline"
        
        $result = Invoke-UTCMGraphRequest -Uri $uri
        
        $result | ConvertTo-UTCMBaselineObject
    }
}

#endregion

#region Drift Cmdlets

function Get-UTCMDrift {
    <#
    .SYNOPSIS
        Gets configuration drifts detected by UTCM monitors.

    .DESCRIPTION
        Retrieves configuration drifts detected across all monitors or for a specific monitor.
        Active drifts are retained indefinitely; fixed drifts are deleted after 30 days.

    .PARAMETER Id
        The ID of a specific drift to retrieve.

    .PARAMETER MonitorId
        Filter drifts by monitor ID.

    .PARAMETER Status
        Filter drifts by status (active, fixed).

    .PARAMETER ResourceType
        Filter drifts by resource type.

    .EXAMPLE
        Get-UTCMDrift
        Gets all configuration drifts.

    .EXAMPLE
        Get-UTCMDrift -Status active
        Gets all active (unresolved) drifts.

    .EXAMPLE
        Get-UTCMDrift -MonitorId $monitorId -Status active
        Gets active drifts for a specific monitor.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory)]
        [string]$Id,
        
        [Parameter(ParameterSetName = 'List')]
        [string]$MonitorId,
        
        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('active', 'fixed')]
        [string]$Status,
        
        [Parameter(ParameterSetName = 'List')]
        [string]$ResourceType
    )
    
    $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.Drifts)"
    
    if ($Id) {
        $uri = "$uri/$Id"
    }
    else {
        $filters = @()
        
        if ($MonitorId) {
            $filters += "monitorId eq '$MonitorId'"
        }
        
        if ($Status) {
            $filters += "status eq '$Status'"
        }
        
        if ($ResourceType) {
            $filters += "resourceType eq '$ResourceType'"
        }
        
        if ($filters.Count -gt 0) {
            $uri += "?`$filter=" + ($filters -join ' and ')
        }
    }
    
    $result = Invoke-UTCMGraphRequest -Uri $uri
    
    if ($Id) {
        $result | ConvertTo-UTCMDriftObject
    }
    else {
        $result | ForEach-Object { $_ | ConvertTo-UTCMDriftObject }
    }
}

#endregion

#region Snapshot Cmdlets

function New-UTCMSnapshot {
    <#
    .SYNOPSIS
        Creates a new configuration snapshot.

    .DESCRIPTION
        Creates a snapshot job to extract the current tenant configuration.
        The snapshot runs asynchronously; use Get-UTCMSnapshotJob to check status.

    .PARAMETER MonitorId
        The ID of the monitor to use as the basis for the snapshot.

    .PARAMETER DisplayName
        A user-friendly name for the snapshot.

    .PARAMETER Description
        A description of the snapshot.

    .PARAMETER Resources
        Array of resource types to include in the snapshot.

    .EXAMPLE
        New-UTCMSnapshot -MonitorId $monitorId -DisplayName "Weekly Backup"

    .EXAMPLE
        New-UTCMSnapshot -MonitorId $monitorId -DisplayName "CA Snapshot" -Resources @("conditionalAccessPolicy")
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Id')]
        [string]$MonitorId,
        
        [Parameter(Mandatory)]
        [string]$DisplayName,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [string[]]$Resources
    )
    
    process {
        $body = @{
            displayName = $DisplayName
        }
        
        if ($Description) {
            $body['description'] = $Description
        }
        
        if ($Resources) {
            $body['resources'] = $Resources
        }
        
        $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.Monitors)/$MonitorId/baseline/createSnapshot"
        
        $result = Invoke-UTCMGraphRequest -Uri $uri -Method POST -Body $body
        
        Write-Host "Snapshot job created. Status: $($result.status)" -ForegroundColor Green
        Write-Host "Use Get-UTCMSnapshotJob -Id '$($result.id)' to check progress." -ForegroundColor Cyan
        
        $result | ConvertTo-UTCMSnapshotJobObject
    }
}

function Get-UTCMSnapshotJob {
    <#
    .SYNOPSIS
        Gets configuration snapshot jobs.

    .DESCRIPTION
        Retrieves snapshot jobs from the tenant. A maximum of 12 snapshot jobs are visible.
        Snapshots are retained for 7 days before automatic deletion.

    .PARAMETER Id
        The ID of a specific snapshot job to retrieve.

    .PARAMETER Status
        Filter snapshot jobs by status.

    .EXAMPLE
        Get-UTCMSnapshotJob
        Gets all snapshot jobs.

    .EXAMPLE
        Get-UTCMSnapshotJob -Id "12345678-1234-1234-1234-123456789012"
        Gets a specific snapshot job.

    .EXAMPLE
        Get-UTCMSnapshotJob -Status succeeded
        Gets all completed snapshot jobs.
    #>
    [CmdletBinding(DefaultParameterSetName = 'List')]
    param(
        [Parameter(ParameterSetName = 'ById', Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Id,
        
        [Parameter(ParameterSetName = 'List')]
        [ValidateSet('notStarted', 'running', 'succeeded', 'failed', 'partiallySuccessful')]
        [string]$Status
    )
    
    process {
        $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.SnapshotJobs)"
        
        if ($Id) {
            $uri = "$uri/$Id"
        }
        elseif ($Status) {
            $uri += "?`$filter=status eq '$Status'"
        }
        
        $result = Invoke-UTCMGraphRequest -Uri $uri
        
        if ($Id) {
            $result | ConvertTo-UTCMSnapshotJobObject
        }
        else {
            $result | ForEach-Object { $_ | ConvertTo-UTCMSnapshotJobObject }
        }
    }
}

function Export-UTCMSnapshot {
    <#
    .SYNOPSIS
        Downloads a completed snapshot to a file.

    .DESCRIPTION
        Downloads the snapshot file from a completed snapshot job.
        The snapshot must be in 'succeeded' or 'partiallySuccessful' status.

    .PARAMETER Id
        The ID of the snapshot job to download.

    .PARAMETER OutputPath
        The path where the snapshot file should be saved.

    .PARAMETER Force
        Overwrite the output file if it exists.

    .EXAMPLE
        Export-UTCMSnapshot -Id $jobId -OutputPath ".\snapshot.json"

    .EXAMPLE
        Get-UTCMSnapshotJob -Status succeeded | Export-UTCMSnapshot -OutputPath ".\snapshots"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Id,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$Force
    )
    
    process {
        # Get the snapshot job to get the resource location
        $job = Get-UTCMSnapshotJob -Id $Id
        
        if ($job.Status -notin @('succeeded', 'partiallySuccessful')) {
            throw "Snapshot job is not complete. Current status: $($job.Status)"
        }
        
        if (-not $job.ResourceLocation) {
            throw "Snapshot job does not have a resource location. It may have expired."
        }
        
        # Determine output file path
        if (Test-Path $OutputPath -PathType Container) {
            $fileName = "snapshot_$($job.Id)_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            $OutputPath = Join-Path $OutputPath $fileName
        }
        
        if ((Test-Path $OutputPath) -and -not $Force) {
            throw "Output file already exists: $OutputPath. Use -Force to overwrite."
        }
        
        Write-Verbose "Downloading snapshot from: $($job.ResourceLocation)"
        
        try {
            $content = Invoke-MgGraphRequest -Uri $job.ResourceLocation -Method GET
            $content | ConvertTo-Json -Depth 50 | Set-Content -Path $OutputPath -Force
            
            Write-Host "Snapshot downloaded to: $OutputPath" -ForegroundColor Green
            
            return Get-Item $OutputPath
        }
        catch {
            throw "Failed to download snapshot: $($_.Exception.Message)"
        }
    }
}

function Remove-UTCMSnapshotJob {
    <#
    .SYNOPSIS
        Deletes a snapshot job.

    .DESCRIPTION
        Deletes a snapshot job from the tenant. Use this to clean up old snapshots
        and make room for new ones (maximum 12 visible jobs).

    .PARAMETER Id
        The ID of the snapshot job to delete.

    .PARAMETER Force
        Skips confirmation prompt.

    .EXAMPLE
        Remove-UTCMSnapshotJob -Id "12345678-1234-1234-1234-123456789012"

    .EXAMPLE
        Get-UTCMSnapshotJob -Status failed | Remove-UTCMSnapshotJob -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$Id,
        
        [Parameter()]
        [switch]$Force
    )
    
    process {
        if (-not $Force -and -not $PSCmdlet.ShouldProcess($Id, "Delete snapshot job")) {
            return
        }
        
        $uri = "$($script:GraphBetaUri)$($script:UTCMEndpoints.SnapshotJobs)/$Id"
        
        Invoke-UTCMGraphRequest -Uri $uri -Method DELETE | Out-Null
        
        Write-Host "Snapshot job deleted successfully." -ForegroundColor Green
    }
}

#endregion

#region Helper Cmdlets

function Get-UTCMSupportedResources {
    <#
    .SYNOPSIS
        Gets the list of supported workloads and resource types.

    .DESCRIPTION
        Returns information about the Microsoft 365 workloads and resource types
        supported by UTCM for configuration monitoring.

    .PARAMETER Workload
        Filter by a specific workload name.

    .EXAMPLE
        Get-UTCMSupportedResources
        Gets all supported workloads and their resource types.

    .EXAMPLE
        Get-UTCMSupportedResources -Workload "Microsoft Entra"
        Gets resource types for Microsoft Entra only.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Microsoft Defender', 'Microsoft Entra', 'Microsoft Exchange Online', 'Microsoft Intune', 'Microsoft Purview', 'Microsoft Teams')]
        [string]$Workload
    )
    
    $workloads = $script:SupportedWorkloads
    
    if ($Workload) {
        $workloads = @{ $Workload = $workloads[$Workload] }
    }
    
    foreach ($name in $workloads.Keys) {
        [PSCustomObject]@{
            PSTypeName    = 'UTCM.SupportedWorkload'
            Workload      = $name
            Description   = $workloads[$name].Description
            ResourceTypes = $workloads[$name].ResourceTypes
        }
    }
}

function New-UTCMBaselineTemplate {
    <#
    .SYNOPSIS
        Creates a baseline template for common scenarios.

    .DESCRIPTION
        Generates a baseline configuration template that can be customized
        and used with New-UTCMMonitor.

    .PARAMETER Template
        The template type to generate.

    .PARAMETER OutputPath
        Optional path to save the template as a JSON file.

    .EXAMPLE
        New-UTCMBaselineTemplate -Template ConditionalAccess
        Returns a baseline template for Conditional Access policies.

    .EXAMPLE
        New-UTCMBaselineTemplate -Template ExchangeTransport -OutputPath ".\baseline.json"
        Saves an Exchange transport rule baseline template to a file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ConditionalAccess', 'ExchangeTransport', 'TeamsPolicy', 'IntuneCompliance', 'SecurityDefaults')]
        [string]$Template,
        
        [Parameter()]
        [string]$OutputPath
    )
    
    $templates = @{
        ConditionalAccess = @{
            displayName = "Conditional Access Baseline"
            description = "Monitor Conditional Access policy configuration"
            resources = @(
                @{
                    resourceType = "conditionalAccessPolicy"
                    displayName = "CA Policy Monitor"
                    properties = @(
                        @{ name = "state"; expectedValue = "enabled" }
                        @{ name = "conditions"; expectedValue = $null }
                        @{ name = "grantControls"; expectedValue = $null }
                    )
                }
            )
        }
        ExchangeTransport = @{
            displayName = "Exchange Transport Rules Baseline"
            description = "Monitor Exchange Online transport rules"
            resources = @(
                @{
                    resourceType = "transportRule"
                    displayName = "Transport Rule Monitor"
                    properties = @(
                        @{ name = "state"; expectedValue = "Enabled" }
                        @{ name = "priority"; expectedValue = $null }
                    )
                }
            )
        }
        TeamsPolicy = @{
            displayName = "Teams Policy Baseline"
            description = "Monitor Microsoft Teams policies"
            resources = @(
                @{
                    resourceType = "teamsMeetingPolicy"
                    displayName = "Meeting Policy Monitor"
                    properties = @(
                        @{ name = "allowTranscription"; expectedValue = $null }
                        @{ name = "allowRecording"; expectedValue = $null }
                    )
                }
            )
        }
        IntuneCompliance = @{
            displayName = "Intune Compliance Baseline"
            description = "Monitor Intune device compliance policies"
            resources = @(
                @{
                    resourceType = "deviceCompliancePolicy"
                    displayName = "Compliance Policy Monitor"
                    properties = @(
                        @{ name = "scheduledActionsForRule"; expectedValue = $null }
                    )
                }
            )
        }
        SecurityDefaults = @{
            displayName = "Security Defaults Baseline"
            description = "Monitor security defaults configuration"
            resources = @(
                @{
                    resourceType = "securityDefaults"
                    displayName = "Security Defaults Monitor"
                    properties = @(
                        @{ name = "isEnabled"; expectedValue = $true }
                    )
                }
            )
        }
    }
    
    $baseline = $templates[$Template]
    
    if ($OutputPath) {
        $baseline | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath
        Write-Host "Baseline template saved to: $OutputPath" -ForegroundColor Green
        return Get-Item $OutputPath
    }
    
    return $baseline
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    # Authentication
    'Connect-UTCM',
    'Disconnect-UTCM',
    'Initialize-UTCMServicePrincipal',
    'Grant-UTCMPermission',
    
    # Monitors
    'New-UTCMMonitor',
    'Get-UTCMMonitor',
    'Set-UTCMMonitor',
    'Remove-UTCMMonitor',
    
    # Baselines
    'Get-UTCMBaseline',
    
    # Drifts
    'Get-UTCMDrift',
    
    # Snapshots
    'New-UTCMSnapshot',
    'Get-UTCMSnapshotJob',
    'Export-UTCMSnapshot',
    'Remove-UTCMSnapshotJob',
    
    # Helpers
    'Get-UTCMSupportedResources',
    'New-UTCMBaselineTemplate'
)
