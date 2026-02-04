# UTCM - Unified Tenant Configuration Management PowerShell Module

A PowerShell module for interacting with Microsoft Graph Unified Tenant Configuration Management (UTCM) APIs. This module enables automated configuration monitoring, drift detection, and snapshot management across Microsoft 365 workloads.

## Features

- **Configuration Monitoring**: Create and manage monitors that periodically check for configuration drift
- **Drift Detection**: Detect and report deviations from your desired configuration baseline
- **Configuration Snapshots**: Capture point-in-time snapshots of your tenant configuration for auditing
- **Multi-Workload Support**: Monitor settings across Microsoft Defender, Entra, Exchange, Intune, Purview, and Teams

## Prerequisites

- PowerShell 5.1 or later (PowerShell 7+ recommended)
- [Microsoft.Graph.Authentication](https://www.powershellgallery.com/packages/Microsoft.Graph.Authentication) module (v2.0.0+)
- Microsoft 365 tenant with appropriate admin permissions
- **UTCM Preview Enrollment** (see below)
- Required Graph permissions:
  - `ConfigurationMonitoring.Read.All` (for read operations)
  - `ConfigurationMonitoring.ReadWrite.All` (for write operations)
  - `Application.ReadWrite.All` (for service principal setup)
  - `AppRoleAssignment.ReadWrite.All` (for granting permissions)

### UTCM Preview Enrollment

> **Important:** UTCM is currently in **public preview** and requires enrollment before the API becomes available in your tenant.

To check if UTCM is available in your tenant:

```powershell
Connect-UTCM
Test-UTCMAvailability
```

If the UTCM API is not available, you may need to:

1. **Enroll in the preview program** - Visit the [Microsoft 365 Admin Center](https://admin.microsoft.com) and check for preview features
2. **Check regional availability** - UTCM may not be available in all regions during preview
3. **Verify licensing** - Certain Microsoft 365 licenses may be required
4. **Contact Microsoft Support** - If you believe UTCM should be available for your tenant

For more information, see the [UTCM Authentication Setup](https://learn.microsoft.com/en-us/graph/utcm-authentication-setup) documentation.

## Installation

### From Local Source

```powershell
# Clone or download the module to a local directory
git clone <repository-url>

# Import the module
Import-Module .\UTCM\UTCM.psd1

# Or copy to your PowerShell modules path
Copy-Item -Recurse .\UTCM "$env:USERPROFILE\Documents\PowerShell\Modules\"
```

### Install Dependencies

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## Quick Start

### 1. Connect to Microsoft Graph

```powershell
# Interactive authentication
Connect-UTCM

# Connect to specific tenant
Connect-UTCM -TenantId "contoso.onmicrosoft.com"
```

### 2. Check UTCM Availability

```powershell
# Verify UTCM is available in your tenant
Test-UTCMAvailability
```

### 3. Initial Setup (First Time Only)

```powershell
# Create the UTCM service principal in your tenant
Initialize-UTCMServicePrincipal

# Grant required permissions
Grant-UTCMPermission -Permissions @('User.Read.All', 'Policy.Read.All', 'Directory.Read.All')
```

### 4. Create a Configuration Monitor

```powershell
# Using a baseline template
New-UTCMBaselineTemplate -Template ConditionalAccess -OutputPath ".\ca-baseline.json"

# Create the monitor
New-UTCMMonitor -DisplayName "CA Policy Monitor" -BaselineJson ".\ca-baseline.json"
```

### 5. Check for Drifts

```powershell
# List all active drifts
Get-UTCMDrift -Status active
```

### 6. Create a Snapshot

```powershell
$monitor = Get-UTCMMonitor | Select-Object -First 1
New-UTCMSnapshot -MonitorId $monitor.Id -DisplayName "Weekly Backup"
```

## Cmdlet Reference

### Authentication

| Cmdlet | Description |
|--------|-------------|
| `Connect-UTCM` | Connects to Microsoft Graph with UTCM permissions |
| `Disconnect-UTCM` | Disconnects from Microsoft Graph |
| `Test-UTCMAvailability` | Checks if UTCM API is available in your tenant |
| `Initialize-UTCMServicePrincipal` | Adds the UTCM service principal to your tenant |
| `Grant-UTCMPermission` | Grants permissions to the UTCM service principal |

### Monitors

| Cmdlet | Description |
|--------|-------------|
| `Get-UTCMMonitor` | Gets configuration monitors |
| `New-UTCMMonitor` | Creates a new configuration monitor |
| `Set-UTCMMonitor` | Updates an existing monitor |
| `Remove-UTCMMonitor` | Deletes a monitor |

### Baselines & Drifts

| Cmdlet | Description |
|--------|-------------|
| `Get-UTCMBaseline` | Gets the baseline for a monitor |
| `Get-UTCMDrift` | Gets detected configuration drifts |

### Snapshots

| Cmdlet | Description |
|--------|-------------|
| `New-UTCMSnapshot` | Creates a configuration snapshot |
| `Get-UTCMSnapshotJob` | Gets snapshot job status |
| `Export-UTCMSnapshot` | Downloads a completed snapshot |
| `Remove-UTCMSnapshotJob` | Deletes a snapshot job |

### Helpers

| Cmdlet | Description |
|--------|-------------|
| `Get-UTCMSupportedResources` | Lists supported workloads and resource types |
| `New-UTCMBaselineTemplate` | Generates baseline templates |

## Supported Workloads

| Workload | Description |
|----------|-------------|
| Microsoft Defender | Defender for Endpoint, Identity, Office 365, Cloud Apps |
| Microsoft Entra | Conditional Access, Authentication Methods, Cross-tenant Access |
| Microsoft Exchange Online | Transport Rules, Connectors, Organization Config |
| Microsoft Intune | Compliance Policies, Configuration Profiles, App Protection |
| Microsoft Purview | Sensitivity Labels, DLP Policies, Retention |
| Microsoft Teams | Meeting, Messaging, and Calling Policies |

## API Limits

- **Monitors**: Maximum 30 per tenant
- **Monitor Frequency**: Fixed at 6 hours (runs at 6 AM, 12 PM, 6 PM, 12 AM GMT)
- **Resources per Day**: 800 configuration resources across all monitors
- **Snapshot Jobs**: Maximum 12 visible at a time
- **Snapshot Resources**: 20,000 per tenant per month
- **Snapshot Retention**: 7 days

## Examples

See the [Examples](./Examples/) folder for:
- [Usage-Examples.ps1](./Examples/Usage-Examples.ps1) - Comprehensive usage examples
- [Baselines/](./Examples/Baselines/) - Sample baseline configurations

## Documentation

- [UTCM Overview (Microsoft Learn)](https://learn.microsoft.com/en-us/graph/unified-tenant-configuration-management-concept-overview)
- [Authentication Setup](https://learn.microsoft.com/en-us/graph/utcm-authentication-setup)
- [API Reference](https://learn.microsoft.com/en-us/graph/api/resources/unified-tenant-configuration-management-api-overview?view=graph-rest-beta)

## Notes

- This module uses the Microsoft Graph **Beta** API, which is subject to change
- UTCM is currently in **public preview**
- The UTCM service principal AppId is `03b07b79-c5bc-4b5e-9bfa-13acf4a99998`

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please submit issues and pull requests.
