# named parameters: -remove
param (
    [switch]$remove
)
$sunshineConfigPath = "C:\Program Files\Sunshine\config\sunshine.conf"
# $sunshineConfigPath = "$PSScriptRoot\sunshine.conf"
$scriptPath = "$PSScriptRoot\sunshine_autoresolution.ps1"
$scriptPath = $scriptPath.Replace("\", "\\")

# Check if user is running as administrator 
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())


#if not, relaunch as administrator
if ($currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) -eq $false) {
    $arguments = "& '" + $myinvocation.mycommand.definition + "'"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}

$sunshineConfig = Get-Content $sunshineConfigPath

if (!$remove) {
    $changeScaling = (Read-Host "Do you want to change the scaling of your display? (y/N)") -eq "y"
    # check if user is using multiple monitors
    $monitors = Get-WmiObject -Namespace root\wmi -Class WmiMonitorBasicDisplayParams
    $monitorCount = $monitors.Count

    # if user is using multiple monitors, ask which monitor they want to change
    if ($monitorCount -gt 1) {
        Write-Host "If you plan not to stream the default display, set it in sunshine settings!"
        if ($changeScaling) {
            $monitorNumber = Read-Host "Which monitor do you want to scale? (number of display from windows settings)"
        }
    }
    else {
        $monitorNumber = 1
    }

    $commandScript = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `\\\`"$scriptPath`\\\`" -monitorNumber $monitorNumber -changeScaling $changeScaling"
    $prepareCmd = "`"do`": `"$commandScript`", `"undo`": `"$commandScript -restore`",`"elevated`":`"true`"}"
}



for ($i = 0; $i -lt $sunshineConfig.Length; $i++) {
    # for each line in sunshine.conf
    if ($sunshineConfig[$i] -match 'global_prep_cmd') {
        $pattern = '.*sunshine_autoresolution.ps1.*'
        # Split by prep commands
        $globalPrepCmd = $sunshineConfig[$i] -split '({)'

        # remove ']' from last line and add it to the end of the array
        $globalPrepCmd[$globalPrepCmd.Length - 1] = $globalPrepCmd[$globalPrepCmd.Length - 1].Substring(0, $globalPrepCmd[$globalPrepCmd.Length - 1].Length - 1)
        $globalPrepCmd += "]"
        
        # skip 0 bcs is the setting name
        for ($j = 1; $j -lt $globalPrepCmd.Length; $j++) {
            if ($globalPrepCmd[$j] -match $pattern) {
                # reset the line with command
                $globalPrepCmd[$j] = ""
                if ($remove) {
                    $globalPrepCmd[$j - 1] = "" # remove also the previous {
                    if ($globalPrepCmd[$j - 2][$globalPrepCmd[$j - 2].Length - 1] -eq ",") {
                        # remove the comma from the previous line
                        $globalPrepCmd[$j - 2] = $globalPrepCmd[$j - 2].Remove($globalPrepCmd[$j - 2].Length - 1)
                    }
                    break
                }
                else {
                    $globalPrepCmd[$j] = $prepareCmd # add the command back with the new settings
                }
                break
            }
            elseif ($j -eq $globalPrepCmd.Length - 1 -and !$remove) {
                # if the command is not present, add it
                $globalPrepCmd = $globalPrepCmd[0..($globalPrepCmd.Length - 2)] + ",{" + $prepareCmd + "]"
                break
            }
        }
        $sunshineConfig[$i] = $globalPrepCmd -join ""
        if ($sunshineConfig[$i] -eq "global_prep_cmd = []") {
            $sunshineConfig[$i] = ""
        }
        break
    }
    elseif ($i -eq $sunshineConfig.Length - 1 -and !$remove) {
        # if the command is not present, add it
        $sunshineConfig += "global_prep_cmd = [{$prepareCmd]"
        break
    }
}
$sunshineConfig | Set-Content $sunshineConfigPath
Write-Host "Done! Restart Sunshine to apply the changes."
#wait for user input
Read-Host -Prompt "Press Enter to exit"