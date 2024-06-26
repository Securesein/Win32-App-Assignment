<#
.SYNOPSIS
    Sets the WIN32 app assigement as required and configures the assignment settings

.LINK
    https://securesein.com
    https://twentynice.com
    https://www.linkedin.com/in/sebastiaan-smits-341513b6

.NOTES
    Version:        0.1
    Author:         Sebastiaan Smits
    Creation Date:  June, 25th 2024
    File: set-Win32AppAssignmentRequired.ps1

    HISTORY:
    2024-25-06	Initial release

    LICENSE:
    Use this code free of charge at your own risk.
    Never deploy code into production if you do not know what it does.

.PARAMETER AppID
    Application ID of the Application you like to change the assignment.

.PARAMETER MobileApp
    Instead of Application ID you can also provide the MobileApp object, can be fetched with "Get-MgDeviceAppManagementMobileApp -MobileAppId ..."

.PARAMETER groupID
    Object ID of the Group that needs to be assigned.

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
To pipe in a Mobile App object see the following example:

Get-MgDeviceAppManagementMobileApp -MobileAppId "61e29a3b-fedd-423b-8409-******" | ./set-Win32RequiredAppAssignment.ps1 -groupID "5f1fc84e-53a0-4b3b-8346-********"

#>


[CmdletBinding(DefaultParameterSetName = "AppID")]
param (


    [Parameter(Mandatory, ParameterSetName = "AppID", ValueFromPipeline)]
    [Parameter(Mandatory, ParameterSetName = "AppIDrestartSettings", ValueFromPipeline)]
    [Parameter(Mandatory, ParameterSetName = "AppIDrestartAndSnooze", ValueFromPipeline)]
    [string]$AppID,

    [Parameter(Mandatory, ParameterSetName = "MobileAppObject", ValueFromPipeline)] 
    [Parameter(Mandatory, ParameterSetName = "MobileAppObjectrestartSettings", ValueFromPipeline)]
    [Parameter(Mandatory, ParameterSetName = "MobileAppObjectrestartAndSnooze", ValueFromPipeline)]
    [Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp]$MobileApp,

    [Parameter(Mandatory)]
    [string]$groupID,

    [ValidateSet("showAll", "showReboot", "hideAll")]
    [string]$Note = "showAll",

    #Not configured sets 'Background download' to default 
    [ValidateSet("notConfigured", "foreground")]
    [string]$deliveryOptimizationPriority = "notConfigured",

    [switch]$useLocalTime,

    [ValidateScript({
        try {
            $parsedDate = [datetime]::ParseExact($_, "yyyy-MM-ddTHH:mm:ss.fffZ", $null)
            return $true
        } catch {
            throw "The startDateTime must be in the format 'yyyy-MM-ddTHH:mm:ss.fffZ'."
        }
    })]
    [string]$startDateTime,
 
    [ValidateScript({
        try {
            $parsedDate = [datetime]::ParseExact($_, "yyyy-MM-ddTHH:mm:ss.fffZ", $null)
            return $true
        } catch {
            throw "The startDateTime must be in the format 'yyyy-MM-ddTHH:mm:ss.fffZ' and contains only numbers"
        }
    })]
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
    [int32]$restartGracePeriodMinutes = 1440,
    
    [Parameter(ParameterSetName = "AppIDrestartSettings")]
    [Parameter(ParameterSetName = "MobileAppObjectrestartSettings")]
    [Parameter(ParameterSetName = "MobileAppObjectrestartAndSnooze")]
    [Parameter(ParameterSetName = "AppIDrestartAndSnooze")]
    [Int32]$displayCountdownRestart = 15,

    [Parameter(Mandatory, ParameterSetName = "MobileAppObjectrestartAndSnooze")]
    [Parameter(Mandatory, ParameterSetName = "AppIDrestartAndSnooze")]
    [switch]$allowSnooze,

    [Parameter(ParameterSetName = "MobileAppObjectrestartAndSnooze")]
    [Parameter(ParameterSetName = "AppIDrestartAndSnooze")]
    [Int32]$snoozeDurationMinutes = 240

)

process{

    Import-Module Microsoft.Graph.Devices.CorporateManagement   

    ## Check if a MobileApp (Microsoft.Graph.PowerShell.Models.MicrosoftGraphMobileApp) object is provided

    if ($MobileApp){

        $AppID = $MobileApp.ID
        Write-Host $AppID

    }


############ App Availability  & App Installation Deadline setting not set; the complete timeInstallSettings is set to null ###########

if (-not $startDateTime -and -not $deadlineDateTime) {
        
     $timeInstallSettings = $null
       
    }

############ If App Availability Time or App Installation Deadline Time settings configured, configure them in the Hastable ###########

else{

    if($useLocalTime) {
        $LocalTime = "True"
    }
    else {
        $LocalTime = "False"
    }

$timeInstallSettings =  [ordered]@{
            "@odata.type"= "#microsoft.graph.mobileAppInstallTimeSettings";
            "deadlineDateTime" = $deadlineDateTime;
            "startDateTime"= $startDateTime;
            "useLocalTime"= $LocalTime
        }    


}

############ If grace period settings are provided, configure them in the Hastable ###########

if ($restartGracePeriod){
    $restartSettings = [ordered]@{
            "@odata.type"= "#microsoft.graph.win32LobAppRestartSettings";
            "countdownDisplayBeforeRestartInMinutes"= $displayCountdownRestart;
            "gracePeriodInMinutes" = $restartGracePeriodMinutes;
            "restartNotificationSnoozeDurationInMinutes"= $null
        }   

}

############ If snooze settings are provided, configure them in the Hastable ###########

if ($allowSnooze){
    $restartSettings = [ordered]@{
            "@odata.type"= "#microsoft.graph.win32LobAppRestartSettings";
            "countdownDisplayBeforeRestartInMinutes"= $displayCountdownRestart;
            "gracePeriodInMinutes" = $restartGracePeriodMinutes;
            "restartNotificationSnoozeDurationInMinutes"= $snoozeDurationMinutes
        }  
}
    


#####################################################################################################################################################
## This is the main Hash Table that will be converted to JSON and will be Posted to the Graph API endpoint to configure the Application Assignment.##
#####################################################################################################################################################

$appAssignmentHashtable = @{}
$appAssignmentHashtable.mobileAppAssignments = 
@([ordered]@{"@odata.type" = "#microsoft.graph.mobileAppAssignment";
    "target"= 
        [ordered]@{"@odata.type" = "#microsoft.graph.groupAssignmentTarget";
        "groupId"= "$GroupID"; 
};"intent"= "Required";
"settings" = [ordered]@{"@odata.type" = "#microsoft.graph.win32LobAppAssignmentSettings"; 
"notifications" = $Note;
"installTimeSettings" = $timeInstallSettings;
"restartSettings"= $restartSettings;
"deliveryOptimizationPriority"= $deliveryOptimizationPriority}

})


############ Convert the Hastable to JSON ###########

$appAssignmentJSON = $appAssignmentHashtable | ConvertTo-Json -depth 10
$body= $appAssignmentJSON -replace '""','null' #replace empty string to null, that is needed in the Json: https://forums.powershell.org/t/substituting-empty-string-with-null/17022/2

    
    
############ The Graph API uri ###########

$url = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppID/assign"
$body ## for debugging to show the JSON that is sent to Intune, you can remove or comment out##

Invoke-MgGraphRequest -Uri $url -Body $body -Method POST -OutputType PSObject

}
