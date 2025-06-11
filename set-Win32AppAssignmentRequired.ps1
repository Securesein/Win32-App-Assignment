function Set-Win32AppAssignmentRequired {
    <#
    .SYNOPSIS
        Sets the WIN32 app assignment as required and configures the assignment settings
    
    .LINK
        https://twentynice.com  
        https://www.linkedin.com/in/sebastiaan-smits-341513b6
    
    .NOTES
        Version:        0.2
        Author:         Sebastiaan Smits
        Creation Date:  June, 25th 2024
        File: set-Win32AppAssignmentRequired.ps1
    
        HISTORY:
        2024-25-06	Initial release
        2025-06-04   Added support for multiple groups
    
        LICENSE:
        Use this code free of charge at your own risk.
        Never deploy code into production if you do not know what it does.
    
    .PARAMETER AppID
        Application ID of the Application you like to change the assignment.
    
    .PARAMETER MobileApp
        Instead of Application ID you can also provide the MobileApp object, can be fetched with "Get-MgDeviceAppManagementMobileApp -MobileAppId ..."
    
    .PARAMETER groupID
        One or more Object IDs of the Groups that need to be assigned.
    
    .PARAMETER Note
        Toast notifications shown to the user.
    
    .PARAMETER deliveryOptimizationPriority
        Use Local time of the device or set time in UTC format.
    
    .PARAMETER startDateTime
        Set time when installation of app can start, needs to be in UTC and formatted like: yyyy-MM-ddTHH:mm:ss.fffZ and converted as string.
    
    .PARAMETER deadlineDateTime
        This date and time specify when the app is installed on the targeted device.
    
    .PARAMETER restartGracePeriod
        Configure if you going to set a Restart Grace Period.
    
    .PARAMETER restartGracePeriodMinutes
        Set the Restart Grace Period period in minutes.
    
    .PARAMETER displayCountdownRestart
        At what time minutes, before the restart, should a countdown be shown to the user.
    
    .PARAMETER allowSnooze
        Configure if you going to allow Snooze for the end user before restart occurs.
    
    .PARAMETER snoozeDurationMinutes
        Set the amount of minutes the user is allowed to Snooze the installation.
    
    .EXAMPLE
    To assign to multiple groups:
    
    $groups = @("5f1fc84e-53a0-4b3b-8346-xxxxxxx", "12f1de23-9999-4c3b-1244-yyyyyyy")
    Get-MgDeviceAppManagementMobileApp -MobileAppId "61e29a3b-fedd-423b-8409-xxxxxx" | ./set-Win32RequiredAppAssignment.ps1 -groupID $groups -startDateTime "2025-06-10T08:00:00.000Z" -deadlineDateTime "2025-06-15T08:00:00.000Z"
    #>
    
    [CmdletBinding(DefaultParameterSetName = "AppID")]
    param (
        [Parameter(Mandatory, ParameterSetName = "AppID", ValueFromPipeline)]
        [Parameter(Mandatory, ParameterSetName = "AppIDrestartSettings", ValueFromPipeline)]
        [Parameter(Mandatory, ParameterSetName = "AppIDrestartAndSnooze", ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string]$AppID,
    
        [Parameter(Mandatory, ParameterSetName = "MobileAppObject", ValueFromPipeline)] 
        [Parameter(Mandatory, ParameterSetName = "MobileAppObjectrestartSettings", ValueFromPipeline)]
        [Parameter(Mandatory, ParameterSetName = "MobileAppObjectrestartAndSnooze", ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [object]$MobileApp,
    
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$groupID,
    
        [switch]$allUser,
    
        [switch]$allDevices,
    
        [ValidateSet("showAll", "showReboot", "hideAll")]
        [string]$Note = "showAll",
    
        [ValidateSet("notConfigured", "foreground")]
        [string]$deliveryOptimizationPriority = "notConfigured",
    
        [switch]$useLocalTime,
    
        [ValidateScript({ [datetime]::ParseExact($_, "yyyy-MM-ddTHH:mm:ss.fffZ", $null) })]
        [string]$startDateTime,
    
        [ValidateScript({ [datetime]::ParseExact($_, "yyyy-MM-ddTHH:mm:ss.fffZ", $null) })]
        [string]$deadlineDateTime,
    
        [Parameter(Mandatory, ParameterSetName = "AppIDrestartSettings")]
        [Parameter(Mandatory, ParameterSetName = "MobileAppObjectrestartSettings")]
        [Parameter(ParameterSetName = "MobileAppObjectrestartAndSnooze")]
        [Parameter(ParameterSetName = "AppIDrestartAndSnooze")]
        [switch]$restartGracePeriod,
    
        [Parameter(ParameterSetName = "AppIDrestartSettings")]
        [Parameter(ParameterSetName = "MobileAppObjectrestartSettings")]
        [Parameter(ParameterSetName = "MobileAppObjectrestartAndSnooze")]
        [Parameter(ParameterSetName = "AppIDrestartAndSnooze")]
        [ValidateRange(1, 20160)]
        [int]$restartGracePeriodMinutes = 1440,
    
        [Parameter(ParameterSetName = "AppIDrestartSettings")]
        [Parameter(ParameterSetName = "MobileAppObjectrestartSettings")]
        [Parameter(ParameterSetName = "MobileAppObjectrestartAndSnooze")]
        [Parameter(ParameterSetName = "AppIDrestartAndSnooze")]
        [ValidateRange(1, 240)]
        [int]$displayCountdownRestart = 15,
    
        [Parameter(Mandatory, ParameterSetName = "MobileAppObjectrestartAndSnooze")]
        [Parameter(Mandatory, ParameterSetName = "AppIDrestartAndSnooze")]
        [switch]$allowSnooze,
    
        [Parameter(ParameterSetName = "MobileAppObjectrestartAndSnooze")]
        [Parameter(ParameterSetName = "AppIDrestartAndSnooze")]
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
        if ($MobileApp -is [Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp]) {
            $AppID = $MobileApp.ID
        } elseif ($MobileApp) {
            throw "Invalid type for MobileApp parameter. Expected [Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp]."
        }
    
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
                intent = "Required"
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
    
        $body # For debug purposes
        Invoke-MgGraphRequest -Uri $url -Body $body -Method POST -OutputType PSObject
    }
    }
    