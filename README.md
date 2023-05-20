# Sunshine Autoresolution

This script is designed to automate the process of changing display resolution when starting and ending game streaming sessions using [Sunshine](https://github.com/LizardByte/Sunshine). It allows you to switch to a specific resolution and scaling mode when starting the streaming session and restore the original resolution when ending the session.

## Inspiration

This script was inspired by the code found in the following GitHub repository: [ResolutionAutomation](https://github.com/Nonary/ResolutionAutomation/tree/precommand_version).

## Prerequisites

Before using this script, make sure you have the following:

- [Sunshine](https://github.com/LizardByte/Sunshine) installed on your system.
- The `setdpi.exe` tool if you plan to change the dpi (scale) when streaming. You can download it from [here](https://github.com/imniko/SetDPI/releases).
- A display that can display the resolution of your client (you add custom resolutions in both AMD and Nvidia settings app)

## Note
The installation process for this script will be simplified once I do the installer like OG script.

## Usage

The script accepts the following parameters:

- `restore` (mandatory): Set this to `$true` if you want to restore the original resolution when ending the streaming session.
- `changeScaling` (optional): Set this to `$true` if you want to change the display scaling mode. Default is `$true`.
- `displayToScale` (optional): Specify the display index to change the scaling mode. This is the number that windows assignes a display to in display settings. Default is `1`.

Add these lines (with modified displayToScale) to your Command Preparations in General section of Sunshine:
#### Do Command
```powershell
powershell.exe -executionpolicy bypass -file "<PathToTheScirptFolder>\main.ps1" -restore:$false -changeScaling:$true -displayToScale:1
```
#### Undo Command
```powershell
powershell.exe -executionpolicy bypass -file "<PathToTheScirptFolder>\main.ps1" -restore:$false -changeScaling:$true -displayToScale:1
```

## Configuration

The script assumes that the Sunshine log file is located at `C:/Windows/Temp/sunshine.log`. If your log file is in a different location, modify the `$sunshineLogFilePath` variable in the script accordingly.

The script can also use an `overrides.txt` file in the script folder for defining custom resolution and scaling settings. Each line in the file should follow the format `original_widthxoriginal_heightxoriginal_refresh_rate=new_widthxnew_heightxnew_refresh_rate[=scaling]`. The `scaling` parameter is optional. An example line in the `overrides.txt` file would be `1920x1080x60=1280x720x60=125`.

## Customization

If you need to modify the script or extend its functionality, you can do so by editing the PowerShell script directly. The script uses PowerShell classes and functions to handle resolution-related operations.

## Disclaimer

This script comes with no warranties or guarantees. Use it at your own risk. The script author and contributors are not responsible for any damages or issues caused by the usage of this script.

## License

This script is licensed under the [MIT License](LICENSE).

## Acknowledgements

- [Nonary](https://github.com/Nonary) - For the inspiration from the [ResolutionAutomation](https://github.com/Nonary/ResolutionAutomation/tree/precommand_version) code.
- [LizardByte](https://github.com/LizardByte) - For developing [Sunshine](https://github.com/LizardByte/Sunshine).
- [imniko](https://github.com/imniko) - For creating the `setdpi.exe` tool.
