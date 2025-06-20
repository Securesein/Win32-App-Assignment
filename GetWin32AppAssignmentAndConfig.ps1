<#
    .SYNOPSIS
        Retrieves all Win32 apps and their assignments, resolving group names and displaying detailed assignment info.

    .LINK
        https://twentynice.com  
        https://www.linkedin.com/in/sebastiaan-smits-341513b6

    .NOTES
        Version:        0.1
        Author:         Sebastiaan Smits
        Creation Date:  June, 11th 2025
        File:           Get-Win32AppAssignments.ps1

        HISTORY:
        2025-06-11  Initial release with assignment group name resolution and built-in groups handling.

        LICENSE:
        Use this code free of charge at your own risk.
        Never deploy code into production if you do not know what it does.

    .EXAMPLE
        Get-Win32AppAssignments | Format-Table -AutoSize

        Retrieves all Win32 apps and their assignments with resolved group names.
#>
function Get-Win32AppAssignments {
    # Cache for group names to avoid repeated calls
    $groupNameCache = @{}

    # Built-in group IDs with friendly names
    $builtInGroupNames = @{
        "f11a8224-9bf1-4bbc-9340-596104c86781" = "All Devices"
        "b2743c69-a4be-4e4b-888f-fa175f6acdf2" = "All Users"
        # Add other built-in groups here if needed
    }

    # Get all Win32 apps
    $appsUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps`?$top=999"
    $allAppsResponse = Invoke-MgGraphRequest -Method GET -Uri $appsUrl
    $apps = $allAppsResponse.value | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.win32LobApp" }

    $results = foreach ($app in $apps) {
        $appId = $app.id
        $appName = $app.displayName

        # Get assignments for this app
        $assignmentsUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$appId/assignments"
        $assignmentsResponse = Invoke-MgGraphRequest -Method GET -Uri $assignmentsUrl
        $assignments = $assignmentsResponse.value

        # Process assignments
        $processedAssignments = foreach ($assignment in $assignments) {
            $groupId = $assignment.target.groupId

            if ([string]::IsNullOrEmpty($groupId)) {
                # No groupId or empty, label accordingly
                $groupName = "No Group / Unknown"
            }
            elseif ($builtInGroupNames.ContainsKey($groupId)) {
                $groupName = $builtInGroupNames[$groupId]
            }
            else {
                if (-not $groupNameCache.ContainsKey($groupId)) {
                    try {
                        $group = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/v1.0/groups/$groupId"
                        $groupNameCache[$groupId] = $group.displayName
                    }
                    catch {
                        $groupNameCache[$groupId] = "Unknown Group ($groupId)"
                    }
                }
                $groupName = $groupNameCache[$groupId]
            }

            [PSCustomObject]@{
                Intent        = $assignment.intent
                GroupId       = $groupId
                GroupName     = $groupName
                InstallTime   = if ($assignment.installTime) { [datetime]$assignment.installTime } else { $null }
                Deadline      = if ($assignment.deadlineDateTime) { [datetime]$assignment.deadlineDateTime } else { $null }
                Notifications = $assignment.notifications
            }
        }

        [PSCustomObject]@{
            AppName     = $appName
            AppId       = $appId
            Assignments = $processedAssignments
        }
    }

    return $results
}
