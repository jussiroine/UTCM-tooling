@{
    # Module manifest for UTCM (Unified Tenant Configuration Management)
    
    # Script module file associated with this manifest
    RootModule = 'UTCM.psm1'
    
    # Version number of this module
    ModuleVersion = '0.1.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Author of this module
    Author = 'Your Organization'
    
    # Company or vendor of this module
    CompanyName = 'Your Organization'
    
    # Copyright statement for this module
    Copyright = '(c) 2026 Your Organization. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PowerShell module for Microsoft Graph Unified Tenant Configuration Management (UTCM) APIs. Enables configuration monitoring, drift detection, and snapshot management across Microsoft 365 workloads.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @(
        @{ ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.0.0' }
    )
    
    # Functions to export from this module
    FunctionsToExport = @(
        # Authentication & Diagnostics
        'Connect-UTCM',
        'Disconnect-UTCM',
        'Test-UTCMAvailability',
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
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess = @('UTCM.Format.ps1xml')
    
    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for discoverability
            Tags = @('Microsoft365', 'Graph', 'UTCM', 'Configuration', 'Monitoring', 'Drift', 'Compliance')
            
            # License URI
            LicenseUri = ''
            
            # Project URI
            ProjectUri = ''
            
            # Release notes
            ReleaseNotes = @'
## 0.1.0
- Initial release
- Support for configuration monitors (CRUD operations)
- Support for drift detection and listing
- Support for configuration snapshots
- Support for UTCM service principal setup
'@
            
            # Prerelease string
            Prerelease = 'preview'
        }
    }
}
