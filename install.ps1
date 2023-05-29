param($remove)
#$sunshineConfigPath = "C:\Program Files\Sunshine\config\sunshine.conf"
$sunshineConfigPath = "$PSScriptRoot\sunshine.conf"
$scriptPath = "$PSScriptRoot\sunshine_autoresolution.ps1"

# Check if user is running as administrator 
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$currentUser = $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

# if not, relaunch as administrator
# if ($currentUser) {
#     Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -install" -Verb RunAs
#     exit
# }

$prepareCmd = "{`"do`": `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -monitorNumber $monitorNumber -changeScaling $changeScaling`", `"undo`": `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -restore -monitorNumber $monitorNumber -changeScaling $changeScaling`"}"

$sunshineConfig = Get-Content $sunshineConfigPath
for($i = 0; $i -lt $sunshineConfig.Length; $i++) {
    if ($sunshineConfig[$i] -match 'global_prep_cmd') {
        $pattern = '.*sunshine_autoresolution.ps1.*'
        $globalPrepCmd = $sunshineConfig[$i] -split '({)'
        for($j = 0; $j -lt $globalPrepCmd.Length; $j++) {
            if ($globalPrepCmd[$j] -match $pattern) {
                $globalPrepCmd[$j-1] = ""
                if($remove){$globalPrepCmd[$j] = ""}
                else {
                    $globalPrepCmd[$j] = 
                }
                break
            }
        }
        $sunshineConfig[$i] = $globalPrepCmd -join ""
        if ($sunshineConfig[$i] -eq "global_prep_cmd = []") {
            $sunshineConfig[$i] = ""
        }
    }
}
$sunshineConfig | Set-Content $sunshineConfigPath
exit


# ask user if they want to change scaling of their display
[bool]$changeScaling = Read-Host "Do you want to change the scaling of your display? (y/n)"

# check if user is using multiple monitors
$monitors = Get-WmiObject -Namespace root\wmi -Class WmiMonitorBasicDisplayParams
$monitorCount = $monitors.Count

# if user is using multiple monitors, ask which monitor they want to change
if ($monitorCount -gt 1) {
    Write-Host "If you plan to stream not default display, select it in sunshine settings!"
    if($changeScaling){
        $monitorNumber = Read-Host "Which monitor do you want to scale? (number of display from windows settings)"
    }
} else {
    $monitorNumber = 1
}

# powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Program Files\Sunshine\config\sunshine_autoresolution.ps1" -monitorNumber $monitorNumber -changeScaling $changeScaling
$sunshineConfig = Get-Content $sunshineConfigPath
for($i = 0; $i -lt $sunshineConfig.Length; $i++) {
    if ($sunshineConfig[$i] -match 'global_prep_cmd') {
        $globalPrepCmd = $sunshineConfig[$i] -split '({)'   
    }
}

$sunshineConfig += "global_prep_cmd = [$prepareCmd]"