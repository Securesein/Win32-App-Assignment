function Set-Win32AppAssignmentAvailable {
    <#
    .SYNOPSIS
        Assigns a Win32 application with the "Available" intent for targeted groups.
    
    .DESCRIPTION
        This function sets the assignment of a Win32 app as "Available" in the Company Portal.
        It supports advanced assignment configuration including install time settings and restart options (for future-proofing).
    
    .LINK
        https://twentynice.com  
        https://www.linkedin.com/in/sebastiaan-smits-341513b6
    
    .NOTES
        Version:        0.2
        Author:         Sebastiaan Smits
        Creation Date:  2025-06-11
        File:           Set-Win32AppAssignmentAvailable.ps1
    
        LICENSE:
        Use this code free of charge at your own risk.
        Never deploy code into production if you do not know what it does.
    
    .PARAMETER AppID
        Application ID (MobileAppId) of the Win32 app.
    
    .PARAMETER MobileApp
        The MobileApp object (as returned by Get-MgDeviceAppManagementMobileApp).
    
    .PARAMETER groupID
        One or more Azure AD Group Object IDs to assign the app to.
    
    .PARAMETER Note
        Notification visibility setting (showAll, showReboot, hideAll). Default is showAll.
    
    .PARAMETER deliveryOptimizationPriority
        Delivery optimization priority (notConfigured, foreground). Default is notConfigured.
    
    .PARAMETER useLocalTime
        Whether to interpret start/deadline dates as local time (default is false).
    
    .PARAMETER startDateTime
        UTC start date/time for install availability.
    
    .PARAMETER deadlineDateTime
        UTC deadline date/time after which app is no longer available (optional).
    
    .PARAMETER restartGracePeriod
        Switch to enable a grace period before device restarts (if enforced by app settings).
    
    .PARAMETER restartGracePeriodMinutes
        Time in minutes for restart grace period (default 1440).
    
    .PARAMETER displayCountdownRestart
        Time in minutes to show restart countdown (default 15).
    
    .PARAMETER allowSnooze
        Whether to allow the user to snooze a pending restart.
    
    .PARAMETER snoozeDurationMinutes
        Duration in minutes for each snooze (default 240).
    
    .EXAMPLE
    $groups = @("group-id-1", "group-id-2")
    Set-Win32AppAssignmentAvailable -AppID "app-id" -groupID $groups -Note showAll -startDateTime "2025-06-12T08:00:00.000Z"
    #>
    
    [CmdletBinding(DefaultParameterSetName = "AppID")]
    param (
        [Parameter(Mandatory, ParameterSetName = "AppID", ValueFromPipeline)]
        [string]$AppID,
    
        [Parameter(Mandatory, ParameterSetName = "MobileAppObject", ValueFromPipeline)]
        [object]$MobileApp,
    
        [Parameter(Mandatory)]
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
        Connect-MgGraph -Scopes "DeviceManagementApps.ReadWrite.All"
    }
    
    process {
        if ($MobileApp -is [Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp]) {
            $AppID = $MobileApp.ID
        }
        elseif ($MobileApp) {
            throw "Invalid type for MobileApp parameter. Expected Microsoft.GraphMobileApp object."
        }
    
        $timeInstallSettings = if (-not $startDateTime -and -not $deadlineDateTime) {
            $null
        } else {
            [ordered]@{
                "@odata.type" = "#microsoft.graph.mobileAppInstallTimeSettings"
                startDateTime = $startDateTime
                deadlineDateTime = $deadlineDateTime
                useLocalTime = $useLocalTime.ToString()
            }
        }
    
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
    
        $assignments = @()
        foreach ($id in $groupID) {
            $assignment = [ordered]@{
                "@odata.type" = "#microsoft.graph.mobileAppAssignment"
                target = [ordered]@{
                    "@odata.type" = "#microsoft.graph.groupAssignmentTarget"
                    groupId = $id
                }
                intent = "Available"
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
    
        $body = @{ mobileAppAssignments = $assignments } | ConvertTo-Json -Depth 10
        $url = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assign"
    
        try {
            Invoke-MgGraphRequest -Uri $url -Method POST -Body $body -ContentType "application/json" | Out-Null
            Write-Host "App successfully assigned as Available."
        }
        catch {
            Write-Error "Failed to assign app: $_"
        }
    }
    }
    