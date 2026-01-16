# Win Deck 🎮

**Win Deck** is a PowerShell automation tool that transforms a standard Windows 10/11 PC into a dedicated Steam gaming console. 

It automates the entire setup process—installing Steam, creating a dedicated user, and modifying the Windows Shell—to boot directly into **Steam Big Picture Mode**, bypassing the Windows Explorer desktop entirely for a seamless, console-like experience.

This script is good for users that either cannot run Steam OS, Bazzite, ChimeraOS, etc, because of issues that involve Nvidia drivers not being up to snuff in Linux or just do not want to run Linux at all. This will set the user shell as Steams Big Picture mode automatically replacing Windows Explorer, thus giving a true console experience with Steam.

**This works best on a fresh Windows installation**

## 🚀 Features

* **Automatic Steam Deployment:** specific checks detect if Steam is missing and automatically download/install the latest client.
* **"Win Deck" User Creation:** Creates a secure, isolated local user named `SteamMachine`.
* **Zero-Touch Boot:** Configures the registry to automatically log in the `SteamMachine` user on system startup.
* **Shell Replacement:** Replaces `explorer.exe` with `steam.exe -bigpicture`. The user sees the Steam UI immediately—no taskbars, no desktop icons.

## 📋 Prerequisites

* **OS:** Windows 10 or Windows 11 (Home or Pro)
* **Permissions:** Must be run as **Administrator**.
* **Internet:** Required if Steam needs to be downloaded.

## 🛠️ Usage

1.  Download the script (save as `WinDeck.ps1`).
2.  Right-click the script and select **Run with PowerShell**.
    * *Alternative:* Open PowerShell as Administrator and navigate to the script location:
        ```powershell
        Set-ExecutionPolicy Bypass -Scope Process -Force
        .\WinDeck.ps1
        ```
3.  Follow the interactive prompts:
    * Win Deck will verify the Steam installation.
    * It will create the local user account.
    * Type `y` to restart the computer and enter "Win Deck" mode.

## 🔧 How Win Deck Works

### The "Default User" Hive Method
Unlike standard scripts that only edit the current user's settings, Win Deck uses a more robust deployment method. It mounts the system's **Default User** registry hive (`C:\Users\Default\NTUSER.DAT`) to a temporary drive in `HKEY_USERS`.

It injects the custom Shell configuration into the `Winlogon` key of this template hive. Because Windows uses the Default User profile as the blueprint for all new user profiles, the `SteamMachine` user inherits the Console Mode settings immediately upon creation, ensuring a clean setup without requiring a manual first login.

## ⚠️ Recovery / Uninstall

If you wish to return the PC to a standard desktop experience:

### To restore the Desktop for the Kiosk user:
1.  Press `CTRL + ALT + DEL` and open **Task Manager**.
2.  File > Run new task > Type `regedit`.
3.  Navigate to `HKEY_CURRENT_USER\Software\Microsoft\Windows NT\CurrentVersion\Winlogon`.
4.  Delete the `Shell` entry.
5.  Sign out and sign back in.

### To stop future users from inheriting Win Deck settings:
1.  Open PowerShell as Administrator.
2.  Run the following commands to clean the Default hive:
    ```powershell
    reg load "HKU\WinDeckTemp" "C:\Users\Default\NTUSER.DAT"
    Remove-ItemProperty -Path "Registry::HKEY_USERS\WinDeckTemp\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "Shell" -ErrorAction SilentlyContinue
    reg unload "HKU\WinDeckTemp"
    ```

## ⚖️ Disclaimer

**Win Deck** modifies system registry files and user account settings. While the script includes safety checks (path verification, handle cleanup, error catching), always ensure you have a backup of your important data before running system automation tools. Use at your own risk.

