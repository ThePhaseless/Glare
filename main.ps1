param(
    [Parameter(Mandatory = $true)]
    [bool]
    $restore = $false,
    [Parameter(Mandatory = $false)]
    [bool]
    $changeScaling = $true,
    [Parameter(Mandatory = $false)]
    [int]
    $displayToScale = 1
    
)

# change to your sunshine log file path if other than default
$sunshineLogFilePath = "C:/Windows/Temp/sunshine.log"

# if scaling is enabled check if there's a setdpi.exe in the current directory
# if there isn't, stop script and print a message
if ($changeScaling) {
    $setdpi = $PSScriptRoot + "/setdpi.exe"
    if ((Test-Path $setdpi -PathType Leaf) -ne $true) {
        Write-Output "setdpi.exe not found in current directory. Please download it from https://github.com/imniko/SetDPI/releases"
        exit
    }
}
Add-Type -TypeDefinition @"
    using System;
    using System.Runtime.InteropServices;

    public class DisplayDevice {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public struct DISPLAY_DEVICE {
            public uint cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string DeviceString;
            public uint StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string DeviceKey;
        }
    }

    public class DisplaySettings {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Auto)]
        public struct DEVMODE {
            private const int CCHDEVICENAME = 32;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHDEVICENAME)]
            public string dmDeviceName;
            public short dmSpecVersion;
            public short dmDriverVersion;
            public short dmSize;
            public short dmDriverExtra;
            public int dmFields;
            public int dmPositionX;
            public int dmPositionY;
            public int dmDisplayOrientation;
            public int dmDisplayFixedOutput;
            public short dmColor;
            public short dmDuplex;
            public short dmYResolution;
            public short dmTTOption;
            public short dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string dmFormName;
            public short dmLogPixels;
            public int dmBitsPerPel;
            public int dmPelsWidth;
            public int dmPelsHeight;
            public int dmDisplayFlags;
            public int dmDisplayFrequency;
            public int dmICMMethod;
            public int dmICMIntent;
            public int dmMediaType;
            public int dmDitherType;
            public int dmReserved1;
            public int dmReserved2;
            public int dmPanningWidth;
            public int dmPanningHeight;
        }
    }
"@

class Resolution {
    [int]
    $Width
    [int]
    $Height
    [int]
    $RefreshRate
    [int]
    $Scaling

    Resolution([int]$Width, [int]$Height, [int]$RefreshRate, [int]$Scaling) {
        $this.Width = $Width
        $this.Height = $Height
        $this.RefreshRate = $RefreshRate
        $this.Scaling = $Scaling
    }
}

function Get-ClientResolution {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $LogFilePath
    )
    $return = $null

    $lines = Get-Content $LogFilePath
    $lines = $lines | Select-String -Pattern "Debug: mode --"

    if ($lines.Count -eq 0) {
        throw "Could not find resolution in C:/Windows/Temp/sunshine.log"
    }

    foreach ($line in $lines) {
        $line = $line.ToString()
        $line = $line.Split(" ")
        $line = $line[4]

        $return = New-Object Resolution(0, 0, 0, 0)
        $return.Width = [int]$line.Split("x")[0]
        $return.Height = [int]$line.Split("x")[1]
        $return.RefreshRate = [int]$line.Split("x")[2]
        break
    }

    if ($null -eq $return) {
        throw "Could not find resolution in C:/Windows/Temp/sunshine.log"
    }

    Write-Host "Found client resolution: $($return.Width)x$($return.Height)@$($return.RefreshRate)Hz"
    return $return
}

function Set-Scaling {
    param (
        [Parameter(Mandatory = $true)]
        [int]
        $DisplayIndex,
        [Parameter(Mandatory = $true)]
        [int]
        $Scaling
    )

    #if scaling is 0, don't change it
    if ($Scaling -eq 0) {
        Write-Host "Skipping scaling for display $DisplayIndex"
        return
    }
    else {
        Write-Host "Setting scaling for display $DisplayIndex to $Scaling"
    }

    & $PSScriptRoot"\SetDPI.exe" $Scaling $DisplayIndex 
}

function Get-Scaling {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DisplayIndex
    )

    $output = & $PSScriptRoot"\SetDPI.exe" get $DisplayIndex
    $output = $output.Split(":")[1].Trim()
    return [int]$output
}

function Get-OverrideResolution {
    param (
        [Parameter(Mandatory = $true)]
        [Resolution]
        $Resolution
    )

    $return = $null

    $lines = Get-Content $PSScriptRoot"\overrides.txt"
    $lines = $lines | Select-String -Pattern "^[^#]"

    if ($lines.Count -eq 0) {
        return $Resolution
    }

    foreach ($line in $lines) {
        $line = $line.ToString()
        $line = $line.Split("=")

        $left = $line[0]
        $right = $line[1]

        $left = $left.Split("x")
        $right = $right.Split("x")

        $left_width = [int]$left[0]
        $left_height = [int]$left[1]
        $left_refresh_rate = [int]$left[2]

        $right_width = [int]$right[0]
        $right_height = [int]$right[1]
        $right_refresh_rate = [int]$right[2]

        if ($left_width -eq $Resolution.Width -and $left_height -eq $Resolution.Height -and $left_refresh_rate -eq $Resolution.RefreshRate) {
            $return = New-Object Resolution(0, 0, 0, 0)
            $return.Width = $right_width
            $return.Height = $right_height
            $return.RefreshRate = $right_refresh_rate

            if ($line.Count -eq 3) {
                $return.Scaling = [int]$line[2]
            }
            else {
                $return.Scaling = 0
            }
            break
        }
    }

    if ($null -eq $return) {
        return $Resolution
    }

    Write-Host "Overriding resolution: $($Resolution.Width)x$($Resolution.Height)@$($Resolution.RefreshRate)Hz -> $($return.Width)x$($return.Height)@$($return.RefreshRate)Hz"
    if ($return.Scaling -ne 0) {
        Write-Host "Scaling: $($return.Scaling)"
    }
    return $return
}

function Get-DisplayName {
    $return = $null

    $lines = Get-Content "C:/Windows/Temp/sunshine.log"
    $lines = $lines | Select-String -Pattern "Output Name"
    # reverse the array so we can get the last line
    $lines = $lines | Select-Object -Index ($lines.Count - 1)
    if ($lines.Count -eq 0) {
        throw "Could not find display name in C:/Windows/Temp/sunshine.log"
    }

    foreach ($line in $lines) {
        $line = $line.ToString()
        $line = $line.Split(']')[1].Split(":")
        $return = $line[3].Trim()
        break
    }

    if ($null -eq $return) {
        throw "Could not find display name in C:/Windows/Temp/sunshine.log"
    }

    return $return
}

function Get-DisplayDeviceIDFromDeviceName {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DeviceName
    )
    $displayDevices = New-Object DisplayDevice+DISPLAY_DEVICE

    # required for EnumDisplayDevices to work
    $displayDevices.cb = $displayDevices.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($displayDevices)

    # Print all available display devices to the console
    #$deviceNum = 0
    $device = $null
    for ($deviceNum = 0; [DisplayDevice]::EnumDisplayDevices([NullString]::Value, $deviceNum, [ref]$displayDevices, 0); $deviceNum++) {
        # https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-enumdisplaydevicesa
        if ($displayDevices.DeviceName -eq $DeviceName) {
            $device = $displayDevices
            break
        }
    }
    if ($null -eq $device) {
        throw "Could not find device with name $DeviceName"
    }
    return $device.DeviceID
}

function Get-CurrentDisplaySettings {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DeviceID
    )

    $return = $null

    # https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-videocontroller
    ForEach ($video_controller in Get-WmiObject Win32_VideoController) {
        if ($video_controller.PNPDeviceID.Contains($DeviceID)) {
            $return = New-Object Resolution(0, 0, 0, 0)
            $return.Width = $video_controller.CurrentHorizontalResolution
            $return.Height = $video_controller.CurrentVerticalResolution
            $return.RefreshRate = $video_controller.CurrentRefreshRate
            break
        }
    }
    if ($null -eq $return) {
        throw "Could not find display with DeviceID $DeviceID"
    }
    return $return
}

function Save-ResolutionToFile {
    param (
        [Parameter(Mandatory = $true)]
        [Resolution]
        $Resolution,
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath
    )
    $resolution | Export-Clixml -Path $FilePath
}

function Get-ResolutionFromFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $FilePath
    )
    $resolution = Import-Clixml -Path $FilePath
    return $resolution
}

Function Set-ScreenResolution {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $DeviceName,
        [Parameter(Mandatory = $true)]
        [Resolution]
        $Resolution
    )

    $displayDevices = New-Object DisplayDevice+DISPLAY_DEVICE
    $displayDevices.cb = $displayDevices.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($displayDevices)

    $tolerance = 2 # Set the tolerance value for the frequency comparison
    $devMode = New-Object DisplaySettings+DEVMODE
    $devMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devMode)
    $modeNum = 0

    $result = $null
    
    # Iterate through all available display modes
    while ([DisplaySettings]::EnumDisplaySettings($DeviceName, $modeNum, [ref]$devMode)) {
        $frequencyDiff = [Math]::Abs($devMode.dmDisplayFrequency - $Resolution.RefreshRate)

        # If the current mode matches the desired resolution and frequency, change the resolution
        if ($devMode.dmPelsWidth -eq $Resolution.Width -and $devMode.dmPelsHeight -eq $Resolution.Height -and $frequencyDiff -le $tolerance) {
            Write-Host "Found compatible resolution. Changing resolution..."
            $result = [DisplaySettings]::ChangeDisplaySettings([ref]$devMode, 0)
            break
        }
        $modeNum++
    }

    if ($result -eq 0) {
        Write-Host "Resolution changed successfully."
    }
    elseif ($null -eq $result) {
        throw "Could not find compatible resolution."
    }
    else {
        throw "Couldn't change resolution. Error code: $result"
    }
}

$currentDisplay = "\.\\DISPLAY1" # Setting not needed, but added to make the script more readable

try {
    $currentDisplay = Get-DisplayName
}
catch {
    throw "Couldn't access Log file. Please run as administrator or add access for users to log file. Error: $_" 
}

# 0. Check if restore parameter is set

# If True:
# 1. Get the current resolution from the file
# 2. Set the resolution to the original resolution
# 3. Set the scaling to the original scaling if applicable

if ($restore) {
    $originalResolution = Get-ResolutionFromFile -FilePath $PSScriptRoot"\originalResolution.xml"
    # Serialize the resolution
    $originalResolution = New-Object Resolution($originalResolution.Width, $originalResolution.Height, $originalResolution.RefreshRate, $originalResolution.Scaling)
    Set-ScreenResolution -DeviceName ($currentDisplay) -Resolution $originalResolution
    if ($changeScaling -ne 0 && $originalResolution.scaling -ne (Get-Scaling -DisplayIndex $displayToScale)) {
        Set-Scaling -DisplayIndex $displayToScale -Scaling $originalResolution.scaling
    }
    exit
}
# else:
# Done (thank god)
# 1. Get the current resolution of the display
# Done
# 2. Save the current resolution to a file to be restored later (hopefully)
# Done
# 3. Get the client resolution from log file
# Done
# 4. Override resolution if aplicable
# Done
# 5. Set the resolution to the client resolution
# Done
# 6. Set the scaling to the overriden scaling if applicable

# 1. Get the current resolution of the display
$originalResolution = Get-CurrentDisplaySettings -DeviceID (Get-DisplayDeviceIDFromDeviceName -DeviceName ($currentDisplay))
# TODO: Find a better way to find screen indexes
if ($changeScaling -ne 0) {
    $originalResolution.scaling = Get-Scaling -DisplayIndex $displayToScale
}
Write-Host "Current resolution: $($originalResolution.Width)x$($originalResolution.Height)@$($originalResolution.RefreshRate)Hz"
Write-Host "Current scaling: $($originalResolution.scaling)"
# 2. Save the current resolution to a file to be restored later (hopefully)
Save-ResolutionToFile -Resolution $originalResolution -FilePath $PSScriptRoot"\originalResolution.xml"

# 3. Get the client resolution from log file
# 4. Override resolution if aplicable
$clientResolution = Get-OverrideResolution -Resolution (Get-ClientResolution -LogFilePath $sunshineLogFilePath)

# 5. Check if scaling parameter is set
Write-Host "Changing resolution to $clientResolution..."
Set-ScreenResolution -DeviceName $currentDisplay -Resolution $clientResolution

if ($changeScaling -and $clientResolution.scaling -ne $originalResolution.scaling) {
    Set-Scaling -DisplayIndex $displayToScale -Scaling $clientResolution.Scaling
}