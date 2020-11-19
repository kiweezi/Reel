# Sets a new wallpaper from specified unsplash collections.
#
# This is part of a repository hosted here: https://github.com/kiweezi/reel
# Created by Rhys Jones: https://github.com/kiweezi
#



# -- Global Variables --

# The path to the configuration file.
$cfgPath = "$PSScriptRoot\config.json"
# Stores the configuration for the script.
$cfg = (Get-Content $cfgPath | ConvertFrom-Json)

# -- End --



# -- Main --

function Start-Main {
    # Calls the rest of the commands in the script.

    # If the script is not being run as administrator then elevate it to edit scheduled jobs.
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) { 
        # Relaunch as an elevated process.
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit
    }

    # Format image path from config.
    $imgPath = $cfg.imgPath
    # Format the collections from the config.
    $collections = $cfg.collections -join ','
    # Format the uri to call in the rest method.
    $uri = @("https://api.unsplash.com/photos/random/"
        "?client_id=$($cfg.apikey)"
        "&collections=$($collections)"
        "&orientation=$($cfg.options.orientation)"
        "&content_filter=$($cfg.options.contentFilter)"
        ) -join ''

    # Define the script to run in the job.
    $script = {
        # Parameters to pass variables into the script block.
        param($imgPath, $uri)
        # Get scheduled job results.
        $result = Get-Job -Name "Update-Wallpaper" -Newest 2
        # If the previous update failed or the schedule is met, update the wallpaper.
        if (($result[0].State -eq "Failed") -or 
        ([int]($result[1].PSBeginTime).TimeOfDay.TotalMinutes -in 1010..1030))
        {
            # Get the image url and download it to the image path, overwriting the previous.
            $imgUrl = (Invoke-RestMethod -Uri $uri).urls.full
            Invoke-RestMethod -Uri $imgUrl -OutFile $imgPath
        }
    }

    # Set the job to run elevated with a schedule specified in the config.
    $trigger = New-JobTrigger -Daily -At $cfg.schedule.updateTime -DaysInterval $cfg.schedule.dayDelay
    $option = New-ScheduledJobOption -StartIfOnBattery -RunElevated

    # Register the scheduled job or update any existing job.
    if ($null -eq (Get-ScheduledJob -Name $cfg.jobName -ErrorAction Ignore)) {
        # Run the update once.
        $imgUrl = (Invoke-RestMethod -Uri $uri).urls.full
        Invoke-RestMethod -Uri $imgUrl -OutFile $imgPath
    }
    else {
        # Unregister the previous version.
        Unregister-ScheduledJob -Name $cfg.jobName
    }

    # Register the scheduled job with an additional trigger.
    Register-ScheduledJob -Name $cfg.jobName -ScheduledJobOption $option -Trigger $trigger -ScriptBlock $script -ArgumentList $imgPath, $uri
    Get-ScheduledJob -Name $cfg.jobName | Add-JobTrigger -Trigger (New-JobTrigger -AtStartup)

    # Log.
    Write-Host "Set scheduled job: $($cfg.jobName)"
    Start-Sleep -Seconds 1
}


Start-Main

# -- End --



# Terminates the script.
exit