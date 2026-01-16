cls
$intro = @'
 /$$      /$$ /$$                 /$$$$$$$                      /$$      
| $$  /$ | $$|__/                | $$__  $$                    | $$      
| $$ /$$$| $$ /$$ /$$$$$$$       | $$  \ $$  /$$$$$$   /$$$$$$$| $$   /$$
| $$/$$ $$ $$| $$| $$__  $$      | $$  | $$ /$$__  $$ /$$_____/| $$  /$$/
| $$$$_  $$$$| $$| $$  \ $$      | $$  | $$| $$$$$$$$| $$      | $$$$$$/ 
| $$$/ \  $$$| $$| $$  | $$      | $$  | $$| $$_____/| $$      | $$_  $$ 
| $$/   \  $$| $$| $$  | $$      | $$$$$$$/|  $$$$$$$|  $$$$$$$| $$ \  $$
|__/     \__/|__/|__/  |__/      |_______/  \_______/ \_______/|__/  \__/
                                                                         
=========================================================================
                        Making Windows Suck Less                                                   
=========================================================================
'@

## Defining configuration settings
$config = @{
	UninstallKey64 = "hklm\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
	UninstallKey32 = "hklm\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
	SteamInstallerPath = join-path $env:userprofile "\Downloads\Steam.exe"
	SteamUrl = "https://store.steampowered.com/about/download"
	AutoLogon = "hklm\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
	DisableLs = "hklm\SOFTWARE\Policies\Microsoft\Power\PowerSettings\0e796bdb-100d-47d6-a2d5-f7d2daa51f51"
}

## Get OS architecture
$os = (gcim win32_operatingsystem).osarchitecture

switch ($os) {
	"64-bit" { $reg = $config.UninstallKey64 }
	"32-bit" { $reg = $config.UninstallKey32 }
}
	
function steamuser {
	$pwd = convertto-securestring "SteamMachine" -asplaintext -force
	$username = "SteamMachine"
	
	if (!(get-localuser | ? { $_.name -eq $username })) {
		write-host "Creating local user $($username): " -nonewline
		try {
			new-localuser -name $username -password $pwd -description "Local user for Steam Machine." -passwordneverexpires -fullname "Steam Machine User" -accountneverexpires | out-null
			write-host "Success" -fore green
			sleep -seconds 1
		}
		catch {
			write-host $_.exception.message
		}
	}
	else {
		write-host "User $username already exists, skipping profile creation" -fore yellow
	}
}

function setshell {
	param (
		[parameter(mandatory = $true)]
		[string]$exepath
	)
	
	$hivepath = "c:\users\Default\NTUSER.DAT"
	$hivename = "Temp_Default"
	$targetkey = "registry::hku\$hivename\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
	
	write-host "Loading default user hive: " -nonewline
	reg load "hku\$hivename" "$hivepath"
	
	## Setting the registry entry to make Steam the shell for the current user
    write-host "Setting Steam as user shell: " -nonewline
    try {
		if (!(test-path $targetkey)) {
			new-item -path $targetkey -force | out-null
		}
		
		$shellvalue = '"{0}" -bigpicture' -f $exepath
		set-itemproperty -path $targetkey -name Shell -value $shellvalue | out-null

        write-host "Success" -fore green
        sleep -seconds 1
	}
	catch {
		write-host $_.exception.message -fore red
	}
	finally {
		[system.gc]::collect()
		[system.gc]::waitforpendingfinalizers()
		
		write-host "Unloading default user hive: " -nonewline
		reg unload "hku\$hivename"
	}
}

function getsteam {
	try {
		## Steam does not have an entry for install location in the registry so grabbing the uninstall string and testing the path 
		$steam = get-itemproperty registry::$($reg) -ea silentlycontinue | ? { $_.displayname -eq "Steam"} 
		
		if (!($steam.uninstallstring)) { return $null }
		$installpath = split-path $steam.uninstallstring -parent
		$exepath = join-path $installpath "Steam.exe"
		
		if (test-path $exepath) { return $exepath } else { return $null }
	}
	catch {
		return $null
	}
}

function restart {
    $answer = read-host "Restart computer to apply change? [y/n]"

    if ($answer -match "^y$") {
        restart-computer
    }
    else {
        exit
    }
}

function installsteam {
	write-host "Downloading Steam client: " -nonewline
	$download = invoke-restmethod -uri $($config.SteamUrl)
	$download = [string]$download
	
	$pattern = "https://cdn\.[^./]+\.steamstatic\.com/client/installer/SteamSetup\.exe"
	$installer = ([regex]::matches($download, $pattern)).value[0]
	
	invoke-webrequest -uri $($installer) -outfile $($config.SteamInstallerPath)
	write-host "Success" -fore green
	
	write-host "Installing Steam client: " -nonewline
	try {
		start-process $($config.SteamInstallerPath) -argumentlist "/S" -wait
		
		## Check for Steam install
		$steam =  get-itemproperty registry::$($reg) -ea silentlycontinue | ? {$_.displayname -eq "Steam"}
			
		while ($null -eq $steam) {
			sleep -seconds 3
			$steam =  get-itemproperty registry::$($reg) -ea silentlycontinue | ? {$_.displayname -eq "Steam"}
				
			if ($steam) {
				break
			}		
		}
		write-host "Success" -fore green
		sleep -seconds 1
	}
	catch {
		write-host $_.exception.message -fore red
	}
}

function autologon {
	$name = @("AutoAdminLogon","DefaultUserName","DefaultPassword")
	$value = @("1","SteamMachine","SteamMachine")
	
	for ($i = 0; $i -lt $name.count; $i++ ) {
		try {
			$key = get-itemproperty registry::$($config.AutoLogon) | ? { $_ -match $name[$i] }
			
			if ($null -ne $key) {
				write-host "Editing autologon setting $($name[$i]): " -nonewline
				set-itemproperty -path registry::$($config.AutoLogon) -name $($name[$i]) -value $($value[$i]) -force | out-null
				write-host "Success" -fore green
				sleep -seconds 1
			}
			else {
				write-host "Creating autologon setting $($name[$i]): " -nonewline
				new-itemproperty -path registry::$($config.AutoLogon) -name $($name[$i]) -propertytype string -value $($value[$i]) | out-null
				write-host "Success" -fore green
				sleep -seconds 1
			}
		}
		catch {
			write-host $_.exception.message -fore red
		}
	}
}

function disablelsonsleep {
	if (!(test-path registry::$($config.DisableLs))) {
		write-host "Disabling lockscreen on wakeup: " -nonewline
		try {
			new-item -path registry::$($config.DisableLs) -force | out-null
			new-itemproperty -path registry::$($config.DisableLs) -name "DCSettingIndex" -propertytype dword -value "0" | out-null
			new-itemproperty -path registry::$($config.DisableLs) -name "ACSettingIndex" -propertytype dword -value "0" | out-null
			write-host "Success" -fore green
		}
		catch {
			write-host $_.exception.message -fore red
		}
			
	}
}

write-host "$intro`n" -fore cyan
write-host "Checking registry for Steam entry: " -nonewline
$steamReg = get-itemproperty registry::$($reg) -ea silentlycontinue | ? { $_.displayname -eq "Steam"} 
$steamInstall = getsteam

if ($steamReg) {
    write-host "Success" -fore green

    write-host "Checking for path for Steam executable: " -nonewline
    if (test-path $steamInstall) {
        write-host "Executable found at $($steamInstall)" -fore yellow
        sleep -seconds 1
		
		## Creating local user SteamMachine
		steamuser
		
		## Creating autologon settings
		autologon
		
		## Setting Steam as shell for default user
		setshell -exepath $steamInstall
		
		## Setting gpo to disable lockscreen on wake from sleep
		disablelsonsleep
		
		## Restarting to apply settings
		restart
    }
}
else {
	## If steam is not istalled ask user if they want to download and install steam client
    $install = read-host "Steam not detected! Do you want to download and install Steam? [y/n]"
	
	while ($install -notmatch '^(y|n|)$') {
		write-host "Please enter a valid selection [y/n]"
		$install = Read-Host "Enter a valid selection"
	}

	if ($install -match "^y$") {
		## Install Steam
		installsteam
		
		$steamInstall = getsteam
		
		if ($steamInstall) {
			## Creating local user SteamMachine
			steamuser
		
			## Creating autologon settings
			autologon
		
			## Setting Steam as shell for local user
			setshell -exepath $steamInstall
			
			## Setting gpo to disable lockscreen on wake from sleep
			disablelsonsleep
		
			## Restarting to apply settings
			restart
		}
		else {
			write-host "Steam installed but cannot determine install location aborting..." -fore red
		}
	}
	else {
		write-host "Steam not detected! Please install Steam and run script again" -fore yellow
	}

}
