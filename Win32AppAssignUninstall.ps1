function Set-Win32AppAssignmentUninstall {
    <#
    .SYNOPSIS
        Sets the WIN32 app assignment as uninstall with configurable assignment settings.
    
    .DESCRIPTION
        Assigns a WIN32 app with uninstall intent to one or more groups, supporting notifications, restart settings, and install time scheduling.
    
    .LINK
        https://twentynice.com  
        https://www.linkedin.com/in/sebastiaan-smits-341513b6
    
    .NOTES
        Version:        0.1
        Author:         Sebastiaan Smits
        Creation Date:  June 10th, 2025
        File:           set-Win32AppAssignmentUninstall.ps1
    
        LICENSE:
        Use this code free of charge at your own risk.
        Never deploy code into production if you do not know what it does.
    
    .PARAMETER AppID
        Application ID of the WIN32 app to assign uninstall intent.
    
    .PARAMETER MobileApp
        MobileApp object instead of AppID, retrieved via Get-MgDeviceAppManagementMobileApp.
    
    .PARAMETER groupID
        One or more Group Object IDs to assign the uninstall intent.
    
    .PARAMETER Note
        Notification setting for uninstall (showAll, showReboot, hideAll).
    
    .PARAMETER deliveryOptimizationPriority
        Delivery optimization priority setting (notConfigured, foreground).
    
    .PARAMETER useLocalTime
        Switch to specify if local time is used in install time settings.
    
    .PARAMETER startDateTime
        UTC start time when uninstall can begin (yyyy-MM-ddTHH:mm:ss.fffZ).
    
    .PARAMETER deadlineDateTime
        UTC deadline time when uninstall must complete (yyyy-MM-ddTHH:mm:ss.fffZ).
    
    .PARAMETER restartGracePeriod
        Switch to enable restart grace period settings.
    
    .PARAMETER restartGracePeriodMinutes
        Minutes for the restart grace period (default 1440, max 20160).
    
    .PARAMETER displayCountdownRestart
        Minutes before restart to display countdown (default 15, max 240).
    
    .PARAMETER allowSnooze
        Switch to allow the user to snooze restart notification.
    
    .PARAMETER snoozeDurationMinutes
        Duration in minutes for snooze (default 240, max 712).
    
    .EXAMPLE
    Assign uninstall to multiple groups with restart and notifications:
    
    $groups = @("5f1fc84e-53a0-4b3b-8346-xxxxxxx", "12f1de23-9999-4c3b-1244-yyyyyyy")
    Get-MgDeviceAppManagementMobileApp -MobileAppId "61e29a3b-fedd-423b-8409-xxxxxx" |
        Set-Win32AppAssignmentUninstall -groupID $groups -Note showAll -restartGracePeriod -allowSnooze -startDateTime "2025-06-10T08:00:00.000Z" -deadlineDateTime "2025-06-15T08:00:00.000Z"
    
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
        [string[]]$groupID,
    
        [ValidateSet("showAll", "showReboot", "hideAll")]
        [string]$Note = "showAll",
    
        [ValidateSet("notConfigured", "foreground")]
        [string]$deliveryOptimizationPriority = "notConfigured",
    
        [switch]$useLocalTime,
    
        [ValidateScript({ [datetime]::ParseExact($_, "yyyy-MM-ddTHH:mm:ss.fffZ", $null) })]
        [string]$startDateTime,
    
        [ValidateScript({ [datetime]::ParseExact($_, "yyyy-MM-ddTHH:mm:ss.fffZ", $null) })]
        [string]$deadlineDateTime,
    
        [switch]$restartGracePeriod,
    
        [ValidateRange(1, 20160)]
        [int]$restartGracePeriodMinutes = 1440,
    
        [ValidateRange(1, 240)]
        [int]$displayCountdownRestart = 15,
    
        [switch]$allowSnooze,
    
        [ValidateRange(1, 712)]
        [int]$snoozeDurationMinutes = 240
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
        Connect-MgGraph
    }
    
    process {
        # Validate or get AppID from MobileApp object
        if ($MobileApp -is [Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp]) {
            $AppID = $MobileApp.ID
        } elseif ($MobileApp) {
            throw "Invalid type for MobileApp parameter. Expected [Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp]."
        }
    
        # Build install time settings if specified
        $timeInstallSettings = if (-not $startDateTime -and -not $deadlineDateTime) {
            $null
        } else {
            [ordered]@{
                "@odata.type" = "#microsoft.graph.mobileAppInstallTimeSettings"
                deadlineDateTime = $deadlineDateTime
                startDateTime    = $startDateTime
                useLocalTime     = $useLocalTime.ToString()
            }
        }
    
        # Build restart settings based on switches
        if ($restartGracePeriod) {
            $restartSettings = [ordered]@{
                "@odata.type" = "#microsoft.graph.win32LobAppRestartSettings"
                countdownDisplayBeforeRestartInMinutes = $displayCountdownRestart
                gracePeriodInMinutes = $restartGracePeriodMinutes
                restartNotificationSnoozeDurationInMinutes = $null
            }
        }
    
        if ($allowSnooze) {
            $restartSettings = [ordered]@{
                "@odata.type" = "#microsoft.graph.win32LobAppRestartSettings"
                countdownDisplayBeforeRestartInMinutes = $displayCountdownRestart
                gracePeriodInMinutes = $restartGracePeriodMinutes
                restartNotificationSnoozeDurationInMinutes = $snoozeDurationMinutes
            }
        }
    
        # Build assignments for each group
        $assignments = @()
        foreach ($id in $groupID) {
            $assignment = [ordered]@{
                "@odata.type" = "#microsoft.graph.mobileAppAssignment"
                target = [ordered]@{
                    "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    groupId = $id
                }
                intent = "Uninstall"
                settings = [ordered]@{
                    "@odata.type" = "#microsoft.graph.win32LobAppAssignmentSettings"
                    notifications = $Note
                    installTimeSettings = $timeInstallSettings
                    restartSettings = $restartSettings
                    deliveryOptimizationPriority = $deliveryOptimizationPriority
                }
            }
            $assignments += $assignment
        }
    
        $appAssignmentHashtable = @{ mobileAppAssignments = $assignments }
        $body = ($appAssignmentHashtable | ConvertTo-Json -Depth 10) -replace '""','null'
        $url = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assign"
    
        $body # Debug output to verify JSON payload
        Invoke-MgGraphRequest -Uri $url -Body $body -Method POST -OutputType PSObject
    }
    }
    