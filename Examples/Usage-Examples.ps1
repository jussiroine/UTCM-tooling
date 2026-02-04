# UTCM PowerShell Module - Example Usage Scripts

#region Prerequisites
<#
Before using the UTCM module, ensure you have:
1. PowerShell 5.1 or later (PowerShell 7+ recommended)
2. Microsoft.Graph.Authentication module installed
3. Appropriate permissions in your Microsoft 365 tenant

Install required module:
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
#>
#endregion

#region Import and Connect

# Import the UTCM module
Import-Module .\UTCM\UTCM.psd1 -Force

# Connect with interactive authentication
Connect-UTCM

# Or connect to a specific tenant
Connect-UTCM -TenantId "contoso.onmicrosoft.com"

# Or use app-only authentication with certificate
Connect-UTCM -ClientId $appId -TenantId $tenantId -CertificateThumbprint $thumbprint

#endregion

#region Initial Setup (One-time)

# Add the UTCM service principal to your tenant
Initialize-UTCMServicePrincipal

# Grant required permissions to the UTCM service principal
# These permissions allow UTCM to read configuration across workloads
Grant-UTCMPermission -Permissions @(
    'User.Read.All',
    'Policy.Read.All',
    'Directory.Read.All',
    'Policy.ReadWrite.ConditionalAccess'
)

#endregion

#region Working with Monitors

# List all monitors
Get-UTCMMonitor

# Get a specific monitor
Get-UTCMMonitor -Id "12345678-1234-1234-1234-123456789012"

# Filter monitors by status
Get-UTCMMonitor -Status active

# Create a new monitor from a JSON baseline file
New-UTCMMonitor -DisplayName "CA Policy Monitor" `
    -Description "Monitors Conditional Access policies" `
    -BaselineJson ".\Examples\Baselines\ConditionalAccess.json"

# Create a monitor with inline baseline
$baseline = @{
    displayName = "Security Baseline"
    resources = @(
        @{
            resourceType = "conditionalAccessPolicy"
            displayName = "MFA Policy"
            properties = @(
                @{ name = "state"; expectedValue = "enabled" }
            )
        }
    )
}
New-UTCMMonitor -DisplayName "Security Monitor" -Baseline $baseline

# Update a monitor
Set-UTCMMonitor -Id $monitorId -DisplayName "Updated Monitor Name"

# Delete a monitor
Remove-UTCMMonitor -Id $monitorId

#endregion

#region Working with Baselines

# Get the baseline for a monitor
$monitor = Get-UTCMMonitor -DisplayName "CA Policy Monitor" | Select-Object -First 1
Get-UTCMBaseline -MonitorId $monitor.Id

# Generate a baseline template
New-UTCMBaselineTemplate -Template ConditionalAccess

# Save a template to file for customization
New-UTCMBaselineTemplate -Template ExchangeTransport -OutputPath ".\my-baseline.json"

# View supported workloads and resource types
Get-UTCMSupportedResources

# Get resources for a specific workload
Get-UTCMSupportedResources -Workload "Microsoft Entra"

#endregion

#region Working with Drifts

# List all drifts
Get-UTCMDrift

# Get only active (unresolved) drifts
Get-UTCMDrift -Status active

# Get drifts for a specific monitor
Get-UTCMDrift -MonitorId $monitor.Id

# Get drifts by resource type
Get-UTCMDrift -ResourceType "conditionalAccessPolicy"

# Get detailed drift information
$drift = Get-UTCMDrift -Status active | Select-Object -First 1
$drift | Format-List *

# Show drifted properties
$drift.DriftedProperties | Format-Table

#endregion

#region Working with Snapshots

# Create a snapshot from a monitor
$monitor = Get-UTCMMonitor | Select-Object -First 1
New-UTCMSnapshot -MonitorId $monitor.Id -DisplayName "Weekly Snapshot $(Get-Date -Format 'yyyy-MM-dd')"

# List all snapshot jobs
Get-UTCMSnapshotJob

# Check status of a specific snapshot job
Get-UTCMSnapshotJob -Id $jobId

# Get completed snapshots
Get-UTCMSnapshotJob -Status succeeded

# Download a completed snapshot
$job = Get-UTCMSnapshotJob -Status succeeded | Select-Object -First 1
Export-UTCMSnapshot -Id $job.Id -OutputPath ".\snapshots\"

# Clean up old snapshot jobs
Get-UTCMSnapshotJob -Status failed | Remove-UTCMSnapshotJob -Force

#endregion

#region Common Scenarios

# Scenario 1: Quick drift check
Write-Host "Active Drifts:" -ForegroundColor Cyan
$drifts = Get-UTCMDrift -Status active
if ($drifts) {
    $drifts | Format-Table ResourceType, BaselineResourceDisplayName, FirstReportedDateTime
} else {
    Write-Host "No active drifts detected!" -ForegroundColor Green
}

# Scenario 2: Create a comprehensive compliance monitor
$complianceBaseline = @{
    displayName = "Compliance Baseline"
    description = "Comprehensive compliance monitoring"
    resources = @(
        @{
            resourceType = "conditionalAccessPolicy"
            displayName = "All CA Policies"
            properties = @(
                @{ name = "state"; expectedValue = "enabled" }
            )
        }
        @{
            resourceType = "securityDefaults"
            displayName = "Security Defaults"
            properties = @(
                @{ name = "isEnabled"; expectedValue = $false }  # Should be off if CA is used
            )
        }
    )
}

New-UTCMMonitor -DisplayName "Compliance Monitor" `
    -Description "Monitors compliance-critical settings" `
    -Baseline $complianceBaseline

# Scenario 3: Export current state for audit
$monitors = Get-UTCMMonitor
foreach ($m in $monitors) {
    $snapshot = New-UTCMSnapshot -MonitorId $m.Id -DisplayName "Audit $(Get-Date -Format 'yyyyMMdd')"
    Write-Host "Created snapshot for $($m.DisplayName): $($snapshot.Id)"
}

# Scenario 4: Monitor cleanup
# Remove all monitors with "Test" in the name
Get-UTCMMonitor -DisplayName "Test" | Remove-UTCMMonitor -Force

#endregion

#region Disconnect

Disconnect-UTCM

#endregion
