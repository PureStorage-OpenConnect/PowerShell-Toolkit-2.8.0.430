<#	
	===========================================================================
	 Created with: 	ISESteroids 2.2 Beta
	 Created by:   	barkz@PureStoragePowerShell.com
	 Coded to:		Blade Runner (Soundtrack from the Motion Picture)
	 Organization: 	Pure Storage, Inc.
	 Filename:     	PureStoragePowerShell.psm1
	 Version:		2.8.0.430
	 Copyright:		2014 Pure Storage, Inc.
	-------------------------------------------------------------------------
	 Module Name: PureStoragePowerShell

	Disclaimer
 	The sample script and documentation are provided AS IS and are not supported by 
	the author or the author's employer, unless otherwise agreed in writing. You bear 
	all risk relating to the use or performance of the sample script and documentation. 
	The author and the author's employer disclaim all express or implied warranties 
	(including, without limitation, any warranties of merchantability, title, infringement 
	or fitness for a particular purpose). In no event shall the author, the author's employer 
	or anyone else involved in the creation, production, or delivery of the scripts be liable 
	for any damages whatsoever arising out of the use or performance of the sample script and 
	documentation (including, without limitation, damages for loss of business profits, 
	business interruption, loss of business information, or other pecuniary loss), even if 
	such person has been advised of the possibility of such damages.
	===========================================================================
#>

<# 	Base requirement for Pure Storage PowerShell Toolkit is PowerShell 3.0 which provides
 	support for the Invoke-RestMethod cmdlet. See http://technet.microsoft.com/en-us/library/hh849971.aspx
 	for full details.
#>
#Requires -Version 3

#region Helper-Functions

function Display-Error()
{
	if (!($_.ErrorDetails))
	{
		<#
		[string] $ErrReturn = $Error[0].Exception
		$ErrReturn += "General Error"
		$ErrReturn += "`r`n"
		$ErrReturn += "At line:" + $Error[0].InvocationInfo.ScriptLineNumber
		$ErrReturn += " char:" + $Error[0].InvocationInfo.OffsetInLine
		$ErrReturn += " For: " + $Error[0].InvocationInfo.Line
		#>
		Write-Host $Error[0].Exception -ForegroundColor 'Red' -BackgroundColor 'Black'
		#Return $Error[0].Exception
	}
	else
	{
		<#
		[string] $ErrReturn = (ConvertFrom-Json $_.ErrorDetails)
		$ErrReturn += "Pure Storage REST API Error"
		$ErrReturn += "`r`n"
		$ErrReturn += "At line:" + $_.InvocationInfo.ScriptLineNumber
		$ErrReturn += " char:" + $_.InvocationInfo.OffsetInLine
		$ErrReturn += " For: " + $_.InvocationInfo.Line
		#>
		$ctx = ConvertFrom-Json $_.ErrorDetails
		$ErrReturn = "Pure Storage REST API: "
		$ErrReturn += $ctx.msg + "(" + $ctx.ctx + ")"
		Write-Host $ErrReturn -ForegroundColor 'Red' -BackgroundColor 'Black'
	}
}

#endregion

#region Miscellenaous-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Open-PureStorageGitHub
{
	try
	{
		$link = "https://github.com/purestorage/PowerShell-Toolkit"
		$browserProcess = [System.Diagnostics.Process]::Start($link)
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-WindowsPowerScheme()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$ComputerName
	)
	
	try
	{
		$PowerScheme = Get-WmiObject -Class WIN32_PowerPlan -Namespace "root\cimv2\power" -ComputerName $ComputerName -Filter "isActive='true'"
		Write-Host $ComputerName "is set to" $PowerScheme.ElementName
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-QueueDepth()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[int]$Qd
	)
	try
	{
		$DriverParam = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\ql2300\Parameters\Device\"
		If (!$DriverParam.DriverParameter)
		{
			$Confirm = Read-Host "The Queue Depth setting for the QLogic Driver (ql2300.sys) does not exist would you like to create it? Y/N"
			switch ($Confirm)
			{
				"Y" { Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\ql2300\Parameters\Device" -Name "DriverParameter" -Value "qd=$Qd" }
				"N" { }
			}
		}
		Else
		{
			$CurrentQD = $DriverParam.DriverParameter
			$Confirm = Read-Host "QLogic Driver Queue Depth is $CurrentQD. Do you want to update to $Qd ? Y/N"
			switch ($Confirm)
			{
				"Y" { Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\ql2300\Parameters\Device" -Name "DriverParameter" -Value "qd=$Qd" }
				"N" { }
			}
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-QuickFixEngineering
{
	Get-WmiObject -Class Win32_QuickFixEngineering `
	| Select-Object -Property Description, HotFixID, InstalledOn `
	| Format-Table -Wrap
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-QueueDepth()
{
	try
	{
		$DriverParam = Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Services\ql2300\Parameters\Device\"
		"Queue Depth is " + $DriverParam.DriverParameter
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-HostBusAdapter()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[string]$ComputerName
	)
	
	$Namespace = "root\WMI"
	try
	{
		$port = Get-WmiObject -ComputerName $ComputerName -Class MSFC_FibrePortHBAAttributes -Namespace $Namespace @PSBoundParameters
		$hbas = Get-WmiObject -ComputerName $ComputerName -Class MSFC_FCAdapterHBAAttributes -Namespace $Namespace @PSBoundParameters
		$hbaProp = $hbas | Get-Member -MemberType Property, AliasProperty | Select -ExpandProperty name | ? { $_ -notlike "__*" }
		$hbas = $hbas | Select $hbaProp
		$hbas | %{ $_.NodeWWN = ((($_.NodeWWN) | % { "{0:x2}" -f $_ }) -join ":").ToUpper() }
		
		ForEach ($hba in $hbas)
		{
			Add-Member -MemberType NoteProperty -InputObject $hba -Name FabricName -Value (($port | ? { $_.instancename -eq $hba.instancename }).attributes | Select @{ Name = 'Fabric Name'; Expression = { (($_.fabricname | % { "{0:x2}" -f $_ }) -join ":").ToUpper() } }, @{ Name = 'Port WWN'; Expression = { (($_.PortWWN | % { "{0:x2}" -f $_ }) -join ":").ToUpper() } }) -passThru
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
Function Register-PfaHostVolumes ()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[string]$Computername
	)
	
	$cmds = "`"RESCAN`""
	$scriptblock = [string]::Join(",", $cmds)
	$diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
	Invoke-Command -ComputerName $Computername -ScriptBlock $diskpart
	
	$disks = Invoke-Command -Computername $Computername { Get-Disk }
	$i = 0
	ForEach ($disk in $disks)
	{
		If ($disk.FriendlyName -like "PURE FlashArray*")
		{
			If ($disk.OperationalStatus -ne 1)
			{
				$disknumber = $disk.Number
				$cmds = "`"SELECT DISK $disknumber`"",
				"`"ATTRIBUTES DISK CLEAR READONLY`"",
				"`"ONLINE DISK`""
				$scriptblock = [string]::Join(",", $cmds)
				$diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
				Invoke-Command -ComputerName $Computername -ScriptBlock $diskpart
			}
		}
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Unregister-PfaHostVolumes()
{
	<#
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)][string]$Computername,
		[Parameter(Mandatory = $False)][string]$Drive,
		[Parameter(Mandatory = $False)][string]$MountPoint
		
	)
	
	$cmds = "`"RESCAN`""
	$scriptblock = [string]::Join(",", $cmds)
	$diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
	Invoke-Command -ComputerName $Computername -ScriptBlock $diskpart
	
	$disks = Invoke-Command -Computername $Computername { Get-Disk }
	$i = 0
	ForEach ($disk in $disks)
	{
		If ($disk.FriendlyName -like "PURE FlashArray*")
		{
			If ($disk.OperationalStatus -ne 1)
			{
				$disknumber = $disk.Number
				$cmds = "`"SELECT DISK $disknumber`"",
				"`"ATTRIBUTES DISK CLEAR READONLY`"",
				"`"OFFLINE DISK`""
				$scriptblock = [string]::Join(",", $cmds)
				$diskpart = $ExecutionContext.InvokeCommand.NewScriptBlock("$scriptblock | DISKPART")
				Invoke-Command -ComputerName $Computername -ScriptBlock $diskpart
			}
		}
	}
	#>
}

#endregion

#region FA-Authentication-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaApiVersion()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray
	)
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
	
	try
	{
		$url = "https://$FlashArray/api/api_version"
		$wc = New-Object System.Net.WebClient
		$restapiver = $wc.DownloadString($url) | ConvertFrom-Json
		$global:PureStorageRestApi = $restapiver.version.GetValue($restapiver.version.Count - 1)
		$global:PureStorageURIBase = "https://$FlashArray/api/$global:PureStorageRestApi"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaApiToken()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[PSCredential]$Credential,
		[ValidateSet('1.0', '1.1', '1.2', '1.3', '1.4')]
		[string]$RESTAPI
	)
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
	
	try
	{
		if (-not (Test-Connection -ComputerName $FlashArray -Quiet))
		{
			Display-Error
		}
		else
		{
			$AuthAction = @{
				username = $Credential.GetNetWorkCredential().Username
				password = $Credential.GetNetWorkCredential().Password
			}
			
			if (!($RESTAPI))
			{
				Get-PfaApiVersion -FlashArray $FlashArray
			}
			else
			{
				$global:PureStorageURIBase = "https://$FlashArray/api/$RESTAPI"
			}
			
			$global:FlashArray = $FlashArray
			
			try
			{
				$Uri = "$PureStorageURIBase/auth/apitoken"
				return (Invoke-RestMethod -Method POST -Uri $Uri -Body $AuthAction)
			}
			Catch
			{
				Display-Error
			}
		}
	}
	Catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Connect-PfaController()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[string]$HttpTimeOut,
		[Parameter(Mandatory = $True, Position = 1, ValueFromPipelineByPropertyName = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$API_Token
	)
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
	
	$SessionAuthentication = @{ api_token = $API_Token }
	$global:HttpTimeOut = $HttpTimeOut
	
	try
	{
		$Uri = "$PureStorageURIBase/auth/session"
		$Return = Invoke-RestMethod -Method POST -Uri $Uri -Body $SessionAuthentication -SessionVariable Session -TimeoutSec $HttpTimeOut
		$Session
	}
	Catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disconnect-PfaController()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/auth/session"
		$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		
		Display-Error
	}
	
}

#endregion

#region FA-VSS-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaShadowCopy()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[string]$ScriptName = "PUREVSS-SNAP",
		[Parameter(Mandatory = $True)]
		[string]$MetadataFile,
		[Parameter(Mandatory = $True)]
		[string]$ShadowCopyAlias,
		[Parameter(Mandatory = $True)]
		[string]$ExposeAs
	)
	
	$dsh = "./$ScriptName.PFA"
	"RESET",
	"LOAD METADATA $MetadataFile.cab",
	"IMPORT",
	"EXPOSE %$ShadowCopyAlias% $ExposeAs",
	"EXIT" | Set-Content $dsh
	DISKSHADOW /s $dsh
	Remove-Item $dsh
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaShadowCopy()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $True)]
		[string[]]$Volume,
		[Parameter(Mandatory = $True)]
		[string]$ScriptName = "PUREVSS-SNAP",
		[Parameter(Mandatory = $True)]
		[string]$MetadataFile,
		[Parameter(Mandatory = $True)]
		[string]$ShadowCopyAlias,
		[ValidateSet('On', 'Off')]
		[string]$VerboseMode = "On"
	)
	$dsh = "./$ScriptName.PFA"
	
	foreach ($Vol in $Volume)
	{
		"ADD VOLUME $Vol ALIAS $ShadowCopyAlias PROVIDER {781c006a-5829-4a25-81e3-d5e43bd005ab}"
	}
	
	
	"RESET",
	"SET CONTEXT PERSISTENT",
	"SET OPTION TRANSPORTABLE",
	"SET METADATA $MetadataFile.cab",
	"SET VERBOSE $VerboseMode",
	"BEGIN BACKUP",
	"ADD VOLUME $Volume ALIAS $ShadowCopyAlias PROVIDER {781c006a-5829-4a25-81e3-d5e43bd005ab}",
	"CREATE",
	"END BACKUP" | Set-Content $dsh
	DISKSHADOW /s $dsh
	Remove-Item $dsh
}

#endregion

#region FA-Array-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Watch-PfaPerformance()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array" + "?action=monitor"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaArray
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	try
	{
		$Array = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array" -WebSession $Session -TimeoutSec $HttpTimeOut
		
		New-Object -TypeName PSObject -Property @{
			"Version" = $array.version
			"Revision" = $array.revision
			"Name" = $array.array_name
			"ID" = $array.id
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaHistoricalPerformance()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateSet('1h', '3h', '24h', '7d', '30d', '90d', '1y')]
		[string]$TimePeriod,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array" + "?action=monitor&historical=$TimePeriod"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaConfiguration
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Array = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array" -WebSession $Session -TimeoutSec $HttpTimeOut
		$Banner = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?banner=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$Idle_timeout = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?idle_timeout=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$NTPServer = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?ntpserver=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$PhoneHomeStatus = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?phonehome=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$Proxy = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?proxy=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$RelayHost = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?relayhost=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$SCSItimeout = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?scsi_timeout=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$SenderDomain = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?senderdomain=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$SpaceStats = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?space=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$SyslogServer = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?syslogserver=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$Controllers = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?controllers=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		$ConnectionKey = Invoke-RestMethod -Method GET -Uri "$PureStorageURIBase/array?connection_key=true" -WebSession $Session -TimeoutSec $HttpTimeOut
		
		New-Object -TypeName PSObject -Property @{
			"Version" = $array.version
			"Revision" = $array.revision
			"Name" = $array.array_name
			"ID" = $array.id
			"Banner" = $banner.banner
			"Controllers" = $controllers
			"IdleTimeout" = $idle_timeout.idle_timeout
			"NTPServer" = $ntpServer.ntpserver
			"PhoneHomeStatus" = $phoneHomeStatus.phonehome
			"Proxy" = $proxy.proxy
			"RelayHost" = $relayHost.relayhost
			"SCSITimeout" = $SCSItimeout.scsitimeout
			"SenderDomain" = $senderDomain.senderdomain
			"SpaceStats" = $spaceStats
			"SyslogServer" = $syslogServer.syslogserver
			"ConnectionKey" = $ConnectionKey.connection_key
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaSpace
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$uri = "$PureStorageURIBase/array?space=true"
		Invoke-RestMethod -Method GET -Uri $uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaConnection
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/connection"
		Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaConsoleLock
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/console_lock"
		Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaPhoneHome
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/phonehome"
		Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaRemoteAssist
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/remoteassist"
		Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaConnection
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$ManagementAddress,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$ConnectionKey,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$ReplicationAddress,
		#[Parameter(Mandatory = $True)][ValidateNotNullOrEmpty()][string] $Type = "replication",

		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$ArrayConnection = $null
		$ArrayConnection = [ordered]@{
			management_address = $ManagementAddress
			connection_key = $ConnectionKey
			replication_address = $ReplicationAddress
			type = [Object[]]"replication"
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/array/connection"
		Invoke-RestMethod -Method POST -Uri $Uri -Body $ArrayConnection -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaConnection
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/connection/$Name"
		Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaBanner
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Banner,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array?banner=$Banner"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaIdleTimeout
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[int]$IdleTimeout,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array?idle_timeout=$IdleTimeout"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaName
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array?name=$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaNtpServer
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Servers,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$AddNtpServer = $null
		$AddNtpServer = @{
			ntpserver = [Object[]]$Servers
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/array?ntpserver"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $AddNtpServer -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaProxy
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array?proxy=$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaRelayHost
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array?relayhost=$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaScsiTimeout
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[int]$Timeout,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array?scsi_timeout=$Timeout"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaSenderDomain
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array?senderdomain=$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaSyslogServer
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Servers,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$AddSyslogServer = $null
		$AddSyslogServer = @{
			syslogserver = [Object[]]$Servers
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/array?syslogserver"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $AddSyslogServer -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Enable-PfaConsoleLock
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/console_lock?enabled=true"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disable-PfaConsoleLock
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/console_lock?enabled=false"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Enable-PfaPhonehome
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/phonehome?enabled=true"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disable-PfaPhonehome
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/phonehome?enabled=false"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Send-PfaPhonehomeLogs()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateSet('All', 'Today', 'Yesterday', 'Cancel')]
		[string]$TimePeriod,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		switch ($TimePeriod)
		{
			"All" { $Action = "send_all" }
			"Today" { $Action = "send_today" }
			"Yesterday" { $Action = "send_yesterday" }
			"Cancel" { $Action = "cancel" }
		}
		
		$Uri = "$PureStorageURIBase/array/phonehome" + "?action=$Action"
		$Return = (Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Connect-PfaRemoteAssist
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/remoteassist?action=connect"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disconnect-PfaRemoteAssist
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/array/remoteassist?action=disconnect"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-Volumes-Snapshots-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaVolumes()
{
	
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaPendingVolumes()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume?pending=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaPendingOnlyVolumes()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume?pending_only=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaSnapshots()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume?snap=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaVolumesSpace()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume?space=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Watch-PfaVolumePerformance()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name" + "?action=monitor"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
	
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaHistoricalVolumePerformance()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateSet('1h', '3h', '24h', '7d', '30d', '90d', '1y')]
		[string]$TimePeriod,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name" + "?action=monitor&historical=$TimePeriod"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaVolume()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaVolumeSnapshots()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name" + "?snap=true"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaVolumeSpace()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name" + "?space=true"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaVolumeSharedConnections()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name" + "/hgroup"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaVolumePrivateConnections()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name" + "/host"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaVolumeDiff()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$BlockSize,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Length,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Offset,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	If (!$Offset)
	{
		$Uri = "$PureStorageURIBase/volume/$Name" + "/diff?block_size=$BlockSize&length=$Length"
	}
	Else
	{
		$Uri = "$PureStorageURIBase/volume/$Name" + "/diff?block_size=$BlockSize&length=$Length&offset=$Offset"
	}
	
	try
	{
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaVolume()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Size,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Source,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	$Volume = $null
	If ($Source)
	{
		$Volume = @{
			source = $Source
		} | ConvertTo-Json
	}
	Else
	{
		$Volume = @{
			size = $Size
		} | ConvertTo-Json
	}
	$Uri = "$PureStorageURIBase/volume/$Name"
	
	try
	{
		Invoke-RestMethod -Method Post -Uri $Uri -Body $Volume -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Update-PfaVolume()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Source,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	$Json = [ordered]@{
		overwrite = "true"
		source = $Source
	} | ConvertTo-Json
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name"
		Invoke-RestMethod -Method Post -Uri $Uri -Body $Json -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaSnapshot()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Volumes,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Suffix,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		foreach ($Volume in $Volumes)
		{
			$Snapshot = $null
			$Snapshot = [ordered]@{
				snap = "true"
				source = [Object[]]"$Volume"
				suffix = $Suffix
			} | ConvertTo-Json
			$Uri = "$PureStorageURIBase/volume"
			Invoke-RestMethod -Method Post -Uri $Uri -Body $Snapshot -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaVolume()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Eradicate,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	try
	{
		if ($Eradicate)
		{
			try
			{
				$Uri = "$PureStorageURIBase/volume/$Name"
				$Return = Invoke-RestMethod -Method Delete -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
			}
			catch
			{
				try
				{
					$Uri = "$PureStorageURIBase/volume/$Name" + "?eradicate=true"
					$Response = Invoke-RestMethod -Method Delete -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
				}
				catch
				{
					Display-Error
				}
			}
		}
		else
		{
			$Uri = "$PureStorageURIBase/volume/$Name"
			$Return = Invoke-RestMethod -Method Delete -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaSnapshot()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name"
		$Return = Invoke-RestMethod -Method Delete -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Rename-PfaVolume
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$CurrentName,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$NewName,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	$Rename = @{
		name = "$New"
	} | ConvertTo-Json
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Old"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $Rename -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Resize-PfaVolume
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Size,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Truncate,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	If (!$Truncate)
	{
		$Resize = @{
			size = "$Size"
		} | ConvertTo-Json
	}
	Else
	{
		$Resize = @{
			size = "$Size"
			truncate = "true"
		} | ConvertTo-Json
		
	}
	$Uri = "$PureStorageURIBase/volume/$Name"
	try
	{
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $Resize -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		$Error = ($_ | ConvertFrom-Json)
		switch ($Error.msg)
		{
			"Implicit truncation not permitted."
			{
				Write-Error "Volume $Name cannot be resized without requiring truncation. Please re-run Resize-PfaVolume with the -Truncate switch."
			}
		}
		
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Restore-PfaVolume
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	$Recover = @{
		action = "recover"
	} | ConvertTo-Json
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $Recover -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Restore-PfaSnapshot
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	$Recover = @{
		action = "recover"
	} | ConvertTo-Json
	
	try
	{
		$Uri = "$PureStorageURIBase/volume/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $Recover -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-Hosts-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaHosts()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateSet('Chap', 'Personality', 'Space')]
		[string]$Display,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	switch ($Display)
	{
		"Chap" { $Uri = "$PureStorageURIBase/host?chap=true" }
		"Personality" { $Uri = "$PureStorageURIBase/host?personality=true" }
		"Space" { $Uri = "$PureStorageURIBase/host?space=true" }
		default { $Uri = "$PureStorageURIBase/host" }
	}
	
	try
	{
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaHost()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateSet('Chap', 'Personality', 'Space')]
		[string]$Display,
		[Parameter(Mandatory = $False)]
		[ValidateSet('All', 'Shared', 'Private')]
		[string]$Volume,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	switch ($Display)
	{
		"Chap" { $Uri = "$PureStorageURIBase/host/$Name" + "?chap=true" }
		"Personality" { $Uri = "$PureStorageURIBase/host/$Name" + "?personality=true" }
		"Space" { $Uri = "$PureStorageURIBase/host/$Name" + "?space=true" }
		default
		{
			if ($Volume)
			{
				switch ($Volume)
				{
					"All" { $Uri = "$PureStorageURIBase/host/$Name/volume" }
					"Shared" { $Uri = "$PureStorageURIBase/host/$Name/volume" + "?shared=true" }
					"Private" { $Uri = "$PureStorageURIBase/host/$Name/volume" + "?private=true" }
					default
					{
						$Uri = "$PureStorageURIBase/host/$Name/volume"
					}
				}
			}
			else
			{
				$Uri = "$PureStorageURIBase/host/$Name"
			}
		}
	}
	
	try
	{
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaHost()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$IQNList,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$WWNList,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		if ($IQNList)
		{
			$NewHost = $null
			$NewHost = @{
				iqnlist = [Object[]]$IQNList
			} | ConvertTo-Json
			$Uri = "$PureStorageURIBase/host/$Name"
			Invoke-RestMethod -Method POST -Uri $Uri -Body $NewHost -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
		}
		elseif ($WWNList)
		{
			$NewHost = $null
			$NewHost = @{
				wwnlist = [Object[]]$WWNList
			} | ConvertTo-Json
			$Uri = "$PureStorageURIBase/host/$Name"
			Invoke-RestMethod -Method POST -Uri $Uri -Body $NewHost -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
		}
		else
		{
			$Uri = "$PureStorageURIBase/host/$Name"
			Invoke-RestMethod -Method POST -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Connect-PfaHost()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Volume,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	$HostConnect = $null
	$HostConnect = [ordered]@{
		name = $Name
		vol = $Volume
	} | ConvertTo-Json
	
	try
	{
		$Uri = "$PureStorageURIBase/host/$Name/volume/$Volume"
		Invoke-RestMethod -Method Post -Uri $Uri -Body $HostConnect -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Connect-PfaVolume()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Volume,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	try
	{
		$HostConnect = $null
		$HostConnect = [ordered]@{
			name = $Name
			vol = $Volume
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/host/$Name/volume/$Volume"
		Invoke-RestMethod -Method Post -Uri $Uri -Body $HostConnect -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disconnect-PfaVolume()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Volume,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Host = $null,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$HostGroup = $null,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	If ($Host)
	{
		$Uri = "$PureStorageURIBase/host/$Host/volume/$Volume"
	}
	Else
	{
		If ($HostGroup)
		{
			$Uri = "$PureStorageURIBase/hgroup/$HostGroup/volume/$Volume"
		}
	}
	
	try
	{
		$Return = Invoke-RestMethod -Method Delete -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaHost()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/host/$Name"
		$Return = Invoke-RestMethod -Method Delete -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-HostGroups-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaHostGroups()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Name = $null,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Space,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		If ($Name)
		{
			If (!$Space)
			{
				$Uri = "$PureStorageURIBase/hgroup/$Name"
			}
			else
			{
				$Uri = "$PureStorageURIBase/hgroup/$Name" + "?space=true"
			}
		}
		Else
		{
			If (!$Space)
			{
				$Uri = "$PureStorageURIBase/hgroup"
			}
			else
			{
				$Uri = "$PureStorageURIBase/hgroup?space=true"
			}
		}
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaHostGroupVolumes()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/hgroup/$Name" + "/volume"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaHostGroup()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$HostList,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		if ($HostList)
		{
			$NewHostList = $null
			$NewHostList = @{
				hostlist = [Object[]]$HostList
			} | ConvertTo-Json
			$Uri = "$PureStorageURIBase/hgroup/$Name"
			$Return = Invoke-RestMethod -Method POST -Uri $Uri -Body $NewHostList -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
		}
		else
		{
			$Uri = "$PureStorageURIBase/hgroup/$Name"
			$Return = Invoke-RestMethod -Method POST -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Connect-PfaHostGroup()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Volume,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/hgroup/$Name/volume/$Volume"
		$Return = Invoke-RestMethod -Method Post -Uri $Uri -Body $HostConnect -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Add-PfaHostGroupHosts()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$HostList,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$AddHostList = $null
		$AddHostList = @{
			addhostlist = [Object[]]$HostList
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/hgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $AddHostList -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaHostGroupHosts()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$HostList,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$RemoveHostList = $null
		$RemoveHostList = @{
			remhostlist = [Object[]]$HostList
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/hgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $RemoveHostList -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Update-PfaHostGroupHosts()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$HostList,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$ReplaceHostList = $null
		$ReplaceHostList = @{
			hostlist = [Object[]]$HostList
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/hgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $ReplaceHostList -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Rename-PfaHostGroup()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$NewName,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$UpdateName = @{
			name = $NewName
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/hgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $UpdateName -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaHostGroup
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/hgroup/$Name"
		$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disconnect-PfaHostGroupVolume
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Volume,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/hgroup/$Name" + "/volume/$Volume"
		$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-Protection-Group-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroups()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup"
		Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupsSpace()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Source,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Target,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		If ($Source)
		{
			$Uri = "$PureStorageURIBase/pgroup?space=true&source=true&total=true"
		}
		elseif ($Target)
		{
			$Uri = "$PureStorageURIBase/pgroup?space=true&target=true&total=true"
		}
		else
		{
			$Uri = "$PureStorageURIBase/pgroup?space=true&total=true"
		}
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupsSnapshotSpace()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Source,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Target,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		If ($Source)
		{
			$Uri = "$PureStorageURIBase/pgroup?snap=true&space=true&source=true"
		}
		elseif ($Target)
		{
			$Uri = "$PureStorageURIBase/pgroup?snap=true&space=true&target=true"
		}
		else
		{
			$Uri = "$PureStorageURIBase/pgroup?space=true"
		}
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupsTransferStatisics()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup?snap=true&transfer=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupsPending()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup?pending=true"
		$Return = Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
		return $Return | Where-Object { $_.time_remaining }
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupsSchedule()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Source,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Target,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		If ($Source)
		{
			$Uri = "$PureStorageURIBase/pgroup?retention=true&schedule=true&source=true"
		}
		elseif ($Target)
		{
			$Uri = "$PureStorageURIBase/pgroup?retention=true&schedule=true&target=true"
		}
		else
		{
			$Uri = "$PureStorageURIBase/pgroup?schedule=true"
		}
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupsRetentionPolicy()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Source,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Target,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		If ($Source)
		{
			$Uri = "$PureStorageURIBase/pgroup?retention=true&source=true"
		}
		elseif ($Target)
		{
			$Uri = "$PureStorageURIBase/pgroup?retention=true&target=true"
		}
		else
		{
			$Uri = "$PureStorageURIBase/pgroup?retention=true"
		}
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupsPendingOnly()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup?pending_only=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupsSnapshots()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup?snap=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroup()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupSpace()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[switch]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name" + "?space=true&total=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupSnapshotSpace()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[switch]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name" + "?space=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupTransferStatisics()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name" + "?snap=true&transfer=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupPending()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name" + "?pending=true"
		$Return = Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
		return $Return | Where-Object { $_.time_remaining }
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupSchedule()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name" + "?schedule=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupRetentionPolicy()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name" + "?retention=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupPendingOnly()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name" + "?pending_only=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaProtectionGroupSnapshots()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/pgroup/$Name" + "?snap=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaProtectionGroupSnapshot()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$ProtectionGroupName,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$SnapshotSuffix,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$ReplicateNow,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$ProtectionGroupSnapshot = $null
		if (!$SnapshotSuffix)
		{
			if (!$ReplicateNow)
			{
				$ProtectionGroupSnapshot = [ordered]@{
					apply_retention = "true"
					snap = "true"
					source = [Object[]]$ProtectionGroupName
				} | ConvertTo-Json
			}
			else
			{
				$ProtectionGroupSnapshot = [ordered]@{
					apply_retention = "true"
					replicate_now = "true"
					snap = "true"
					source = [Object[]]$ProtectionGroupName
				} | ConvertTo-Json
			}
		}
		else
		{
			if (!$ReplicateNow)
			{
				$ProtectionGroupSnapshot = [ordered]@{
					apply_retention = "true"
					snap = "true"
					source = [Object[]]$ProtectionGroupName
					suffix = $SnapshotSuffix
				} | ConvertTo-Json
			}
			else
			{
				$ProtectionGroupSnapshot = [ordered]@{
					apply_retention = "true"
					replicate_now = "true"
					snap = "true"
					source = [Object[]]$ProtectionGroupName
					suffix = $SnapshotSuffix
				} | ConvertTo-Json
			}
			
		}
		
		$Uri = "$PureStorageURIBase/pgroup"
		$Return = Invoke-RestMethod -Method POST -Uri $Uri -Body $ProtectionGroupSnapshot -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaProtectionGroup()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$HostGroups,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Hosts,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Volumes,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ReplicationTargets,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$ProtectionGroup = $null
		
		if ($HostGroups -And $ReplicationTargets)
		{
			$ProtectionGroup = [ordered]@{
				hgrouplist = [Object[]]$HostGroups
				targetlist = [Object[]]$ReplicationTargets
			} | ConvertTo-Json
		}
		elseif ($HostGroups)
		{
			$ProtectionGroup = [ordered]@{
				hgrouplist = [Object[]]$HostGroups
			} | ConvertTo-Json
		}
		
		if ($Hosts -And $ReplicationTargets)
		{
			$ProtectionGroup = [ordered]@{
				hostlist = [Object[]]$Hosts
				targetlist = [Object[]]$ReplicationTargets
			} | ConvertTo-Json
		}
		elseif ($Hosts)
		{
			$ProtectionGroup = [ordered]@{
				hostlist = [Object[]]$Hosts
			} | ConvertTo-Json
		}
		
		
		if ($Volumes -And $ReplicationTargets)
		{
			$ProtectionGroup = [ordered]@{
				vollist = [Object[]]$Volumes
				targetlist = [Object[]]$ReplicationTargets
			} | ConvertTo-Json
		}
		elseif ($Volumes)
		{
			$ProtectionGroup = [ordered]@{
				vollist = [Object[]]$Volumes
			} | ConvertTo-Json
		}
		
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method POST -Uri $Uri -Body $ProtectionGroup -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaProtectionGroup()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Eradicate,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		if ($Eradicate)
		{
			try
			{
				$Uri = "$PureStorageURIBase/pgroup/$Name"
				$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
				
				$ProtectionGroup = $null
				$ProtectionGroup = @{
					eradicate = "true"
				} | ConvertTo-Json
				
				$Uri = "$PureStorageURIBase/pgroup/$Name"
				$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -Body $ProtectionGroup -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
				
			}
			catch
			{
				try
				{
					$ProtectionGroup = $null
					$ProtectionGroup = @{
						eradicate = "true"
					} | ConvertTo-Json
					
					$Uri = "$PureStorageURIBase/pgroup/$Name"
					$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -Body $ProtectionGroup -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
				}
				catch
				{
					Display-Error
				}
			}
		}
		else
		{
			$Uri = "$PureStorageURIBase/pgroup/$Name"
			$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaProtectionGroupSnapshots()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Eradicate,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		if ($Eradicate)
		{
			try
			{
				$Uri = "$PureStorageURIBase/pgroup/$Name"
				$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
				
				$ProtectionGroup = $null
				$ProtectionGroup = @{
					eradicate = "true"
				} | ConvertTo-Json
				
				$Uri = "$PureStorageURIBase/pgroup/$Name"
				$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -Body $ProtectionGroup -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
				
			}
			catch
			{
				try
				{
					$ProtectionGroup = $null
					$ProtectionGroup = @{
						eradicate = "true"
					} | ConvertTo-Json
					
					$Uri = "$PureStorageURIBase/pgroup/$Name"
					$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -Body $ProtectionGroup -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
				}
				catch
				{
					Display-Error
				}
			}
		}
		else
		{
			$Uri = "$PureStorageURIBase/pgroup/$Name"
			$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
		}
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Restore-PfaProtectionGroup
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$PGroupRecover = @{
			action = "recover"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $PGroupRecover -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Restore-PfaProtectionGroupSnapshots
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$PGroupRecover = @{
			action = "recover"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $PGroupRecover -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Rename-PfaProtectionGroup
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$NewName,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$PGroupUpdate = @{
			name = $NewName
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $PGroupUpdate -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Enable-PfaProtectionGroupReplication
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$PGroupReplEnable = @{
			replicate_enabled = "true"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $PGroupReplEnable -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disable-PfaProtectionGroupReplication
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$PGroupReplEnable = @{
			replicate_enabled = "false"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $PGroupReplEnable -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Enable-PfaProtectionGroupSnapshots
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$PGroupSnapEnable = @{
			snap_enabled = "true"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $PGroupSnapEnable -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disable-PfaProtectionGroupSnapshots
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$PGroupSanpEnable = @{
			snap_enabled = "false"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $PGroupSnapEnable -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Add-PfaProtectionGroupMembers()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$HostGroups,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Hosts,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Volumes,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ReplicationTargets,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$UpdateProtectionGroup = $null
		
		if ($HostGroups)
		{
			$UpdateProtectionGroup = [ordered]@{
				addhgrouplist = [Object[]]$HostGroups
			} | ConvertTo-Json
		}
		elseif ($Hosts)
		{
			$UpdateProtectionGroup = [ordered]@{
				addhostlist = [Object[]]$Hosts
			} | ConvertTo-Json
		}
		elseif ($Volumes)
		{
			$UpdateProtectionGroup = [ordered]@{
				addvollist = [Object[]]$Volumes
			} | ConvertTo-Json
		}
		elseif ($ReplicationTargets)
		{
			$UpdateProtectionGroup = [ordered]@{
				addtargetlist = [Object[]]$ReplicationTargets
			} | ConvertTo-Json
		}
		
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $UpdateProtectionGroup -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaProtectionGroupMembers()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$HostGroups,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Hosts,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Volumes,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$ReplicationTargets,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$UpdateProtectionGroup = $null
		
		if ($HostGroups)
		{
			$UpdateProtectionGroup = [ordered]@{
				remhgrouplist = [Object[]]$HostGroups
			} | ConvertTo-Json
		}
		elseif ($Hosts)
		{
			$UpdateProtectionGroup = [ordered]@{
				remhostlist = [Object[]]$Hosts
			} | ConvertTo-Json
		}
		elseif ($Volumes)
		{
			$UpdateProtectionGroup = [ordered]@{
				remvollist = [Object[]]$Volumes
			} | ConvertTo-Json
		}
		elseif ($ReplicationTargets)
		{
			$UpdateProtectionGroup = [ordered]@{
				remtargetlist = [Object[]]$ReplicationTargets
			} | ConvertTo-Json
		}
		
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $UpdateProtectionGroup -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Update-PfaProtectionGroupReplication()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateSet('Allow', 'Disallow')]
		[string]$Replication,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		switch ($Replication)
		{
			"Allow" {
				$UpdateProtectionGroup = @{
					allowed = "true"
				} | ConvertTo-Json
			}
			"Disallow" {
				$UpdateProtectionGroup = @{
					allowed = "false"
				} | ConvertTo-Json
			}
		}
		
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $UpdateProtectionGroup -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaProtectionGroupReplicationBlackout()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[int]$StartTime,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[int]$EndTime,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$EndTimeSeconds = $EndTime * 3600
		$StartTimeSeconds = $StartTime * 3600
		
		$SetBlackout = [ordered]@{
			replicate_blackout = @{
				end = $EndTimeSeconds
				start = $StartTimeSeconds
			}
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/pgroup/$Name"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $SetBlackout -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Restore-PfaProtectionGroupVolumeSnapshots()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$ProtectionGroup,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$SnapshotName,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Prefix,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Hostname,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
		
	)
	
	try
	{
		$PGroupVolumes = Get-PfaProtectionGroup -Name $ProtectionGroup -Session $Session
		$PGroupSnapshotsSet = $SnapshotName
		
		ForEach ($PGroupVolume in $PGroupVolumes)
		{
			For ($i = 0; $i -lt $PGroupVolume.volumes.Count; $i++)
			{
				if (($PGroupVolume.source).Contains(":"))
				{
					$ValidPGroupVolName = $PGroupVolume.volumes[$i]
					$ValidSourceName = $PGroupVolume.source
				}
				else
				{
					$ValidPGroupVolName = $PGroupVolume.source + ":" + $PGroupVolume.volumes[$i]
					$ValidSourceName = $PGroupVolume.source + ":"
				}
				
				$NewPGSnapshotVol = ($ValidPGroupVolName).Replace($ValidSourceName, $Prefix + "-")
				$Temp = $PGroupVolume.volumes[$i].Replace($PGroupVolume.source + ":", "")
				$NewSource = ($PGroupSnapshotsSet + "." + $Temp)
				New-PfaVolume -Name $NewPGSnapshotVol -Source $NewSource -Session $Session -ErrorAction Stop
				If ($Hostname)
				{
					Connect-PfaVolume -Name $Hostname -Volume $NewPGSnapshotVol -Session $Session -ErrorAction Stop
				}
			}
		}
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-Connection-Port-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaPorts()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$uri = "$PureStorageURIBase/port"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaInitiators()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/port?initiators=true"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Enable-PfaPorts()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/port?enabled=true"
		$Return = Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disable-PfaPorts()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/port?enabled=false"
		$Return = Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-Alerts-Messages-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaAlerts()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/alert"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaAlertRecipient()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Email = "flasharray-alerts@purestorage.com",
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/alert/$Email"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaAlertRecipient()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Email,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/alert/$Email"
		$Return = (Invoke-RestMethod -Method POST -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Test-PfaAlertRecipient()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Email,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Test = [ordered]@{
			action = "test"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/alert/$Email"
		$Return = (Invoke-RestMethod -Method PUT -Uri $Uri -Body $Test -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Enable-PfaAlertRecipient()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Email,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$SetStatus = [ordered]@{
			enabled = "true"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/alert/$Email"
		$Return = (Invoke-RestMethod -Method PUT -Uri $Uri -Body $SetStatus -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disable-PfaAlertRecipient()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Email,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$SetStatus = [ordered]@{
			enabled = "false"
		} | ConvertTo-Json
		$Uri = "$PureStorageURIBase/alert/$Email"
		$Return = (Invoke-RestMethod -Method PUT -Uri $Uri -Body $SetStatus -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaMessages()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateSet('All', 'Audit', 'Flagged', 'Open', 'Recent', 'User')]
		[string]$Type,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Username,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		switch ($Type)
		{
			"All" { $Uri = "$PureStorageURIBase/message" }
			"Audit" { $Uri = "$PureStorageURIBase/message?audit=true" }
			"Flagged" { $Uri = "$PureStorageURIBase/message?flagged=true" }
			"Open" { $Uri = "$PureStorageURIBase/message?open=true" }
			"Recent" { $Uri = "$PureStorageURIBase/message?recent=true" }
			"User" { $Uri = "$PureStorageURIBase/message?user=$Username" }
		}
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaAlertRecipient()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Email,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/alert/$Email"
		$Return = (Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Hide-PfaMessage()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Id,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/message/$Id" + "?flagged=false"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Show-PfaMessage()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Id,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/message/$Id" + "?flagged=true"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $HideMessage -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-SNMP-Manager-Connections-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaSnmp()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$EngineId,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		If ($EngineId)
		{
			$Uri = "$PureStorageURIBase/snmp?engine_id=true"
		}
		else
		{
			$Uri = "$PureStorageURIBase/snmp"
		}
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaSnmpManager()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Manager,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/snmp/$Manager"
		$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaSnmpManager()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Manager,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/snmp/$Manager"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaSnmpv3Manager()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Manager,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Hostname,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$User,
		[Parameter(Mandatory = $False)]
		[ValidateSet('MD5', 'SHA')]
		[string]$AuthProtocol,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$AuthPassphrase,
		[Parameter(Mandatory = $False)]
		[ValidateSet('AES', 'DES')]
		[string]$PrivacyProtocol,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$PrivacyPassphrase,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$SnmpManagerv3Config = $null
		$SnmpManagerv3Config = @{
			host = $Hostname
			user = $User
			auth_protocol = $AuthProtocol
			auth_passphrase = $AuthPassphrase
			privacy_protocol = $PrivacyProtocol
			privacy_passphrase = $PrivacyPassphrase
			version = "v3"
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/snmp/$Manager"
		$Return = Invoke-RestMethod -Method POST -Uri $Uri -Body $SnmpManagerv3Config -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaSnmpv2cManager()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Manager,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Hostname,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Community,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$SnmpManagerv2cConfig = $null
		$SnmpManagerv2cConfig = @{
			host = $Hostname
			community = $Community
			version = "v2c"
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/snmp/$Manager"
		$Return = Invoke-RestMethod -Method POST -Uri $Uri -Body $SnmpManagerv2cConfig -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Update-PfaSnmpManager()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Manager,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Name,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$SnmpManagerName = $null
		$SnmpManagerName = @{
			name = $Name
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/snmp/$Manager"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $SnmpManagerName -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Test-PfaSnmpManager()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Manager,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$TestSnpManager = @{
			action = "test"
		}
		
		$Uri = "$PureStorageURIBase/snmp/$Manager"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $TestSnpManager -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-SSL-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaSslCert()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/cert"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Export-PfaSslCert()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$Certificate,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[switch]$IntermediateCertificate,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		If (!$Certificate)
		{
			If (!$IntermediateCertificate)
			{
				$Uri = "$PureStorageURIBase/cert"
			}
			Else
			{
				$Uri = "$PureStorageURIBase/cert?intermediate_certificate=true"
			}
		}
		Else
		{
			$Uri = "$PureStorageURIBase/cert?certificate=true"
		}
		
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-Network-Interface-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaDns
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/dns"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaDns
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$Domain,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Nameservers,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Dns = $null
		If ($Domain)
		{
			If ($Namesevers)
			{
				$Dns = @{
					domain = $Domain
					nameservers = [Object[]]$Nameservers
				} | ConvertTo-Json
			}
			else
			{
				$Dns = @{
					domain = $Domain
				} | ConvertTo-Json
			}
			else
			{
			}
		}
		elseif ($Nameservers)
		{
			$Dns = @{
				nameservers = [Object[]]$Nameservers
			} | ConvertTo-Json
		}
		
		$Uri = "$PureStorageURIBase/dns"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $Dns -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaNetwork
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/network"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaNetworkInterface
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[string]$Interface,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/network/$Interface"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}


#endregion

#region FA-Hardware-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaHardware()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/hardware"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaHardwareComponent()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Component,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/hardware/$Component"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Show-PfaHardwareLed()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Component,
		[Parameter(Mandatory = $True)]
		[ValidateSet('On', 'Off')]
		[string]$State,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$LED = $null
		switch ($State)
		{
			"On"
			{
				$LED = @{
					identify = "on"
				} | ConvertTo-Json
			}
			"Off"
			{
				$LED = @{
					identify = "off"
				} | ConvertTo-Json
			}
		}
		
		$Uri = "$PureStorageURIBase/hardware/$Component"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $LED -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaDrives()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/drive"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaDrive()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Location,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/drive/$Location"
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region FA-Users-Cmdlets

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaUsers()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateSet('API_Token', 'Public_Key')]
		[string]$Show,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		switch ($Show)
		{
			"API_Token" { $Uri = "$PureStorageURIBase/admin?api_token=true&expose=true" }
			"Public_Key" { $Uri = "$PureStorageURIBase/admin?publickey=true" }
		}
		
		return (Invoke-RestMethod -Method Get -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaUser()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateSet('API_Token', 'Public_Key')]
		[string]$Show,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$User,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		If ($User)
		{
			switch ($Show)
			{
				"API_Token" { $Uri = "$PureStorageURIBase/admin/$User" + "/apitoken" }
				"Public_Key" { $Uri = "$PureStorageURIBase/admin/$User" + "?publickey=true" }
			}
		}
		else
		{
			switch ($Show)
			{
				"API_Token" { $Uri = "$PureStorageURIBase/admin?api_token=true&expose=true" }
				"Public_Key" { $Uri = "$PureStorageURIBase/admin?publickey=true" }
			}
		}
		
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function New-PfaApiToken()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$User,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/admin/$User" + "/apitoken"
		return (Invoke-RestMethod -Method POST -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Clear-PfaPermissionCache()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$ClearPermCache = $null
		$ClearPermCache = @{
			clear = "true"
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/admin?action=refresh"
		return (Invoke-RestMethod -Method PUT -Uri $Uri -Body $ClearPermCache -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaUserPassword()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$User,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$Old,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$New,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Password = $null
		$Password = @{
			old_password = $Old
			password = $New
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/admin/$User"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $Password -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Set-PfaUserPublicKey()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$User,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$PublicKey,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$PubKey = $null
		$PubKey = @{
			publickey = $PublicKey
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/admin/$User"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $PubKey -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Remove-PfaApiToken()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$User,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/admin/$User" + "/apitoken"
		$Return = Invoke-RestMethod -Method DELETE -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaDirectoryService()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/directoryservice"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaDirectoryServiceGroups()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/directoryservice?groups=true"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Get-PfaDirectoryServiceCertificate()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$Uri = "$PureStorageURIBase/directoryservice?certificate=true"
		return (Invoke-RestMethod -Method GET -Uri $Uri -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Test-PfaDirectoryService()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$DirService = $null
		$DirService = @{
			action = "test"
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/directoryservice"
		$Return = (Invoke-RestMethod -Method PUT -Uri $Uri -Body $DirService -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json")
		return $Return.output
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Enable-PfaDirectoryService()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$DirServiceEnabled = $null
		$DirServiceEnabled = @{
			enabled = "true"
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/directoryservice"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $DirServiceEnabled -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Disable-PfaDirectoryService()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$DirServiceEnabled = $null
		$DirServiceEnabled = @{
			enabled = "false"
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/directoryservice"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $DirServiceEnabled -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Update-PfaDirectoryService()
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $False)]
		[ValidateNotNullOrEmpty()]
		[string]$FlashArray,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string[]]$LdapUri,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$BaseDN,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$GroupBase,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$ArrayAdminGroup,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$StorageAdminGroup,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$ReadOnlyGroup,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$BindUser,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[string]$BindPassword,
		[Parameter(Mandatory = $True)]
		[ValidateNotNullOrEmpty()]
		[Microsoft.PowerShell.Commands.WebRequestSession]
		$Session
	)
	
	try
	{
		$DirServiceConfig = $null
		$DirServiceConfig = @{
			uri = [Object[]]$LdapUri
			base_dn = $BaseDN
			group_base = $GroupBase
			array_admin_group = $ArrayAdminGroup
			storage_admin_group = $StorageAdminGroup
			readonly_group = $ReadOnlyGroup
			bind_user = $BindUser
			bind_password = $BindPassword
		} | ConvertTo-Json
		
		$Uri = "$PureStorageURIBase/directoryservice"
		$Return = Invoke-RestMethod -Method PUT -Uri $Uri -Body $DirServiceConfig -WebSession $Session -TimeoutSec $HttpTimeOut -ContentType "application/json"
	}
	catch
	{
		Display-Error
	}
}

#endregion

#region TBD

#.ExternalHelp PureStoragePowerShell.psm1-help.xml
function Test-Configuration
{
}

#endregion

Export-ModuleMember -function Open-PureStorageGitHub
Set-Alias -Name opengit -Value Open-PureStorageGitHub -Scope Global
Export-ModuleMember -function Get-WindowsPowerScheme -Alias power
Set-Alias -Name power -Value Get-WindowsPowerScheme -Scope Global
Export-ModuleMember -function Get-PfaApiVersion
Export-ModuleMember -function Get-PfaApiToken
Set-Alias -Name token -Value Get-PfaApiToken -Scope Global
Export-ModuleMember -function Connect-PfaController
Set-Alias -Name connect -Value Connect-PfaController -Scope Global
Export-ModuleMember -function Disconnect-PfaController
Export-ModuleMember -function New-PfaShadowCopy
Export-ModuleMember -function Get-PfaShadowCopy
Export-ModuleMember -function Watch-PfaPerformance
Export-ModuleMember -function Get-PfaHistoricalPerformance
Export-ModuleMember -function Get-PfaSpace
Export-ModuleMember -function Get-PfaConfiguration
Export-ModuleMember -Function Get-PfaConnection
Export-ModuleMember -function Get-PfaConsoleLock
Export-ModuleMember -function Get-PfaPhoneHome
Export-ModuleMember -function Get-PfaRemoteAssist
Export-ModuleMember -function New-PfaConnection
Export-ModuleMember -function Remove-PfaConnection
Export-ModuleMember -function Get-PfaArray
Export-ModuleMember -Function Set-PfaBanner
Export-ModuleMember -Function Set-PfaIdleTimeout
Export-ModuleMember -Function Set-PfaName
Export-ModuleMember -Function Set-PfaNtpServer
Export-ModuleMember -Function Set-PfaProxy
Export-ModuleMember -Function Set-PfaRelayHost
Export-ModuleMember -Function Set-PfaScsiTimeout
Export-ModuleMember -Function Set-PfaSenderDomain
Export-ModuleMember -Function Set-PfaSyslogServer
Export-ModuleMember -Function Enable-PfaConsoleLock
Export-ModuleMember -Function Disable-PfaConsoleLock
Export-ModuleMember -Function Enable-PfaPhonehome
Export-ModuleMember -Function Disable-PfaPhonehome
Export-ModuleMember -Function Send-PfaPhonehomeLogs
Export-ModuleMember -Function Connect-PfaRemoteAssist
Export-ModuleMember -Function Disconnect-PfaRemoteAssist
Export-ModuleMember -function Get-PfaVolumes
Export-ModuleMember -function Get-PfaPendingVolumes
Export-ModuleMember -function Get-PfaPendingOnlyVolumes
Export-ModuleMember -function Get-PfaSnapshots
Export-ModuleMember -Function Get-PfaVolumesSpace
Export-ModuleMember -function Get-PfaProtectionGroups
Export-ModuleMember -function Get-PfaProtectionGroupsPending
Export-ModuleMember -function Get-PfaProtectionGroupsPendingOnly
Export-ModuleMember -function Get-PfaProtectionGroupsSchedule
Export-ModuleMember -function Get-PfaProtectionGroupsRetentionPolicy
Export-ModuleMember -function Get-PfaProtectionGroupsTransferStatisics
Export-ModuleMember -Function Get-PfaProtectionGroupsSnapshotSpace
Export-ModuleMember -function Get-PfaProtectionGroupsSpace
Export-ModuleMember -function Get-PfaProtectionGroup
Export-ModuleMember -function Get-PfaProtectionGroupsSnapshots
Export-ModuleMember -function Get-PfaProtectionGroupPending
Export-ModuleMember -function Get-PfaProtectionGroupPendingOnly
Export-ModuleMember -function Get-PfaProtectionGroupSchedule
Export-ModuleMember -function Get-PfaProtectionGroupRetentionPolicy
Export-ModuleMember -function Get-PfaProtectionGroupTransferStatisics
Export-ModuleMember -Function Get-PfaProtectionGroupSnapshotSpace
Export-ModuleMember -function Get-PfaProtectionGroupSpace
Export-ModuleMember -function New-PfaProtectionGroupSnapshot
Export-ModuleMember -function New-PfaProtectionGroup
Export-ModuleMember -function Remove-PfaProtectionGroup
Export-ModuleMember -function Restore-PfaProtectionGroup
Export-ModuleMember -function Rename-PfaProtectionGroup
Export-ModuleMember -function Restore-PfaProtectionGroupVolumeSnapshots
Set-Alias -Name restorepgsnap -Value Restore-PfaProtectionGroupVolumeSnapshots -Scope Global
Export-ModuleMember -function Remove-PfaProtectionGroupSnapshots
Export-ModuleMember -function Restore-PfaProtectionGroupSnapshots
Export-ModuleMember -function Enable-PfaProtectionGroupReplication
Export-ModuleMember -function Disable-PfaProtectionGroupReplication
Export-ModuleMember -function Enable-PfaProtectionGroupSnapshots
Export-ModuleMember -function Disable-PfaProtectionGroupSnapshots
Export-ModuleMember -function Add-PfaProtectionGroupMembers
Export-ModuleMember -function Remove-PfaProtectionGroupMembers
Export-ModuleMember -function Update-PfaProtectionGroupReplication
Export-ModuleMember -Function Set-PfaProtectionGroupReplicationBlackout
Export-ModuleMember -Function Watch-PfaVolumePerformance
Export-ModuleMember -Function Get-PfaVolumeSnapshots
Export-ModuleMember -Function Get-PfaVolume
Export-ModuleMember -Function Get-PfaHistoricalVolumePerformance
Export-ModuleMember -Function Get-PfaVolumeSpace
Export-ModuleMember -Function Get-PfaVolumeSharedConnections
Export-ModuleMember -Function Get-PfaVolumePrivateConnections
Export-ModuleMember -Function Get-PfaVolumeDiff
Export-ModuleMember -function New-PfaVolume
Set-Alias -Name newvol -Value New-PfaVolume -Scope Global
Export-ModuleMember -function Update-PfaVolume
Export-ModuleMember -function New-PfaSnapshot
Set-Alias -Name newsnap -Value New-PfaSnapshot -Scope Global
Export-ModuleMember -function Remove-PfaVolume
Set-Alias -Name delvol -Value Remove-PfaVolume -Scope Global
Export-ModuleMember -function Remove-PfaSnapshot
Set-Alias -Name delsnap -Value Remove-PfaSnapshot -Scope Global
Export-ModuleMember -function Rename-PfaVolume
Export-ModuleMember -function Resize-PfaVolume
Export-ModuleMember -function Restore-PfaVolume
Export-ModuleMember -function Restore-PfaSnapshot
Export-ModuleMember -function Get-PfaHosts
Export-ModuleMember -function Get-PfaHost
Export-ModuleMember -function New-PfaHost
Set-Alias -Name newhost -Value New-PfaHost -Scope Global
Export-ModuleMember -function Connect-PfaHost
Set-Alias -Name connhost -Value Connect-PfaHost -Scope Global
Export-ModuleMember -function Remove-PfaHost
Export-ModuleMember -Function Connect-PfaVolume
Set-Alias -Name connvol -Value Connect-PfaVolume -Scope Global
Export-ModuleMember -function Disconnect-PfaVolume
Export-ModuleMember -function Get-PfaHostGroups
Export-ModuleMember -function Get-PfaHostGroupVolumes
Export-ModuleMember -function New-PfaHostGroup
Export-ModuleMember -function Connect-PfaHostGroup
Set-Alias -Name connhg -Value Connect-PfaHostGroup -Scope Global
Export-ModuleMember -Function Add-PfaHostGroupHosts
Export-ModuleMember -Function Remove-PfaHostGroupHosts
Export-ModuleMember -Function Rename-PfaHostGroup
Export-ModuleMember -Function Update-PfaHostGroupHosts
Export-ModuleMember -function Remove-PfaHostGroup
Export-ModuleMember -function Disconnect-PfaHostGroupVolume
Export-ModuleMember -Function New-PfaProtectionGroupSnapshot
Export-ModuleMember -function Get-PfaPorts
Export-ModuleMember -function Get-PfaInitiators
Export-ModuleMember -function Enable-PfaPorts
Export-ModuleMember -function Disable-PfaPorts
Export-ModuleMember -function Get-PfaAlerts
Export-ModuleMember -function Get-PfaAlertRecipient
Export-ModuleMember -function Test-PfaAlertRecipient
Export-ModuleMember -function Enable-PfaAlertRecipient
Export-ModuleMember -function Disable-PfaAlertRecipient
Export-ModuleMember -function Remove-PfaAlertRecipient
Export-ModuleMember -function New-PfaAlertRecipient
Export-ModuleMember -function Get-PfaMessages
Export-ModuleMember -function Hide-PfaMessage
Export-ModuleMember -function Show-PfaMessage
Export-ModuleMember -function Get-PfaSnmp
Export-ModuleMember -function Get-PfaSnmpManager
Export-ModuleMember -function New-PfaSnmpv3Manager
Export-ModuleMember -function New-PfaSnmpv2cManager
Export-ModuleMember -function Update-PfaSnmpManager
Export-ModuleMember -function Remove-PfaSnmpManager
Export-ModuleMember -function Test-PfaSnmpManager
Export-ModuleMember -function Get-PfaSslCert
Export-ModuleMember -function Export-PfaSslCert
Export-ModuleMember -function Get-PfaDns
Export-ModuleMember -function Set-PfaDns
Export-ModuleMember -function Get-PfaNetwork
Export-ModuleMember -function Get-PfaNetworkInterface
Export-ModuleMember -function Get-PfaHardware
Export-ModuleMember -function Get-PfaHardwareComponent
Export-ModuleMember -function Show-PfaHardwareLed
Export-ModuleMember -function Get-PfaDrives
Export-ModuleMember -function Get-PfaDrive
Export-ModuleMember -function Get-PfaUsers
Export-ModuleMember -function Get-PfaUser
Export-ModuleMember -function New-PfaApiToken
Export-ModuleMember -function Clear-PfaPermissionCache
Export-ModuleMember -function Set-PfaUserPassword
Export-ModuleMember -function Set-PfaUserPublicKey
Export-ModuleMember -function Remove-PfaApiToken
Export-ModuleMember -function Get-PfaDirectoryService
Set-Alias -Name getad -Value Get-PfaDirectoryService -Scope Global
Export-ModuleMember -function Get-PfaDirectoryServiceGroups
Export-ModuleMember -function Get-PfaDirectoryServiceCertificate
Export-ModuleMember -function Test-PfaDirectoryService
Export-ModuleMember -function Disable-PfaDirectoryService
Export-ModuleMember -function Enable-PfaDirectoryService
Export-ModuleMember -function Update-PfaDirectoryService
Export-ModuleMember -function Get-HostBusAdapter
Export-ModuleMember -function Register-PfaHostVolumes
Set-Alias -Name scanhost -Value Register-PfaHostVolumes -Scope Global
Export-ModuleMember -Function Unregister-PfaHostVolumes
Set-Alias -Name removevols -Value Unregister-PfaHostVolumes -Scope Global
Export-ModuleMember -function Get-QuickFixEngineering