function Set-Win32AppAssignmentAvailable {
    <#
    .SYNOPSIS
        Sets the Win32 app assignment as Available (optional) for specified groups.
    
    .DESCRIPTION
        Assigns a Win32 application with the "Available" intent, making it optional for enrolled devices in targeted groups.
        This allows users to install the app from the Company Portal.
    
    .LINK
        https://twentynice.com  
        https://www.linkedin.com/in/sebastiaan-smits-341513b6
    
    .NOTES
        Version:        0.1
        Author:         Sebastiaan Smits
        Creation Date:  2025-06-10
        File:           Set-Win32AppAssignmentAvailable.ps1
    
    .PARAMETER AppID
        Application ID (MobileAppId) of the Win32 application to assign.
    
    .PARAMETER MobileApp
        Instead of AppID, you can provide the MobileApp object (type Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp).
    
    .PARAMETER groupID
        One or more Azure AD Group Object IDs to assign the app as Available.
    
    .EXAMPLE
        # Assign app with AppID to two groups as Available
        $groups = @("5f1fc84e-53a0-4b3b-8346-xxxxxxx", "12f1de23-9999-4c3b-1244-yyyyyyy")
        Set-Win32AppAssignmentAvailable -AppID "61e29a3b-fedd-423b-8409-xxxxxx" -groupID $groups
    
    .EXAMPLE
        # Assign app by MobileApp object to one group as Available
        $app = Get-MgDeviceAppManagementMobileApp -MobileAppId "61e29a3b-fedd-423b-8409-xxxxxx"
        Set-Win32AppAssignmentAvailable -MobileApp $app -groupID "5f1fc84e-53a0-4b3b-8346-xxxxxxx"
    
    .LICENSE
        Use this code free of charge at your own risk.
        Never deploy code into production if you do not know what it does.
    #>
    
        [CmdletBinding(DefaultParameterSetName = "AppID")]
        param (
            [Parameter(Mandatory, ParameterSetName = "AppID", ValueFromPipeline)]
            [Parameter(Mandatory, ParameterSetName = "MobileAppObject", ValueFromPipeline)]
            [ValidateNotNullOrEmpty()]
            [string]$AppID,
    
            [Parameter(Mandatory, ParameterSetName = "MobileAppObject", ValueFromPipeline)]
            [ValidateNotNullOrEmpty()]
            [object]$MobileApp,
    
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string[]]$groupID
        )
    
        begin {
            function Test-Module {
                param ([string]$ModuleName)
                if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
                    Write-Host "Installing module $ModuleName"
                    Install-Module -Name $ModuleName -Scope CurrentUser -Force
                }
                Import-Module -Name $ModuleName
            }
    
            Test-Module -ModuleName "Microsoft.Graph.Devices.CorporateManagement"
            Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All"
        }
    
        process {
            # If MobileApp object provided, get its ID
            if ($MobileApp -is [Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp]) {
                $AppID = $MobileApp.ID
            }
            elseif ($MobileApp) {
                throw "Invalid type for MobileApp parameter. Expected Microsoft.GraphMobileApp object."
            }
    
            # Build assignment objects for each group with intent "Available"
            $assignments = @()
            foreach ($id in $groupID) {
                $assignment = [ordered]@{
                    "@odata.type" = "#microsoft.graph.mobileAppAssignment"
                    target = [ordered]@{
                        "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                        groupId = $id
                    }
                    intent = "Available"
                    # For Available assignments, settings can be null or omitted
                    settings = $null
                }
                $assignments += $assignment
            }
    
            # Prepare request body
            $appAssignmentHashtable = @{ mobileAppAssignments = $assignments }
            $body = $appAssignmentHashtable | ConvertTo-Json -Depth 10
    
            # API endpoint URL - Beta endpoint is required for app assignment
            $url = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assign"
    
            # Send assignment request
            try {
                Invoke-MgGraphRequest -Uri $url -Body $body -Method POST -ContentType "application/json" | Out-Null
                Write-Host "App assigned as Available to specified groups successfully."
            }
            catch {
                Write-Error "Failed to assign app: $_"
            }
        }
    }
    