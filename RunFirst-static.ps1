#
# RunFirst.ps1
# When prompted, place the config file in the same folder where the script will be run from.

#Multiple Selection Box
Function MultipleSelectionBox ($inputarray,$prompt,$listboxtype) {
 
# Taken from Technet - http://technet.microsoft.com/en-us/library/ff730950.aspx
# This version has been updated to work with Powershell v3.0.
# Had to replace $x with $Script:x throughout the function to make it work. 
# This specifies the scope of the X variable.  Not sure why this is needed for v3.
# http://social.technet.microsoft.com/Forums/en-SG/winserverpowershell/thread/bc95fb6c-c583-47c3-94c1-f0d3abe1fafc
#
# Function has 3 inputs:
#     $inputarray = Array of values to be shown in the list box.
#     $prompt = The title of the list box
#     $listboxtype = system.windows.forms.selectionmode (None, One, MutiSimple, or MultiExtended)
 
$Script:x = @()
 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
 
$objForm = New-Object System.Windows.Forms.Form 
$objForm.Text = $prompt
$objForm.Size = New-Object System.Drawing.Size(300,600) 
$objForm.StartPosition = "CenterScreen"
 
$objForm.KeyPreview = $True
 
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
    {
        foreach ($objItem in $objListbox.SelectedItems)
            {$Script:x += $objItem}
        $objForm.Close()
    }
    })
 
$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
    {$objForm.Close()}})
 
$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(75,520)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
 
$OKButton.Add_Click(
   {
        foreach ($objItem in $objListbox.SelectedItems)
            {$Script:x += $objItem}
        $objForm.Close()
   })
 
$objForm.Controls.Add($OKButton)
 
$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(150,520)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.Add_Click({$objForm.Close()})
$objForm.Controls.Add($CancelButton)
 
$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Size(10,20) 
$objLabel.Size = New-Object System.Drawing.Size(280,20) 
$objLabel.Text = "Please make a selection from the list below:"
$objForm.Controls.Add($objLabel) 
 
$objListbox = New-Object System.Windows.Forms.Listbox 
$objListbox.Location = New-Object System.Drawing.Size(10,40) 
$objListbox.Size = New-Object System.Drawing.Size(260,20) 
 
$objListbox.SelectionMode = $listboxtype
 
$inputarray | ForEach-Object {[void] $objListbox.Items.Add($_)}
 
$objListbox.Height = 470
$objForm.Controls.Add($objListbox) 
$objForm.Topmost = $True
 
$objForm.Add_Shown({$objForm.Activate()})
[void] $objForm.ShowDialog()
 
Return $Script:x
}

#Typed Inputbox Function
Function InputBox($title,$body,$default){Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName PresentationCore,PresentationFramework
[Microsoft.VisualBasic.Interaction]::InputBox($body, $title, $default)}

#Acknowledge Box Function
Function AckBox([Parameter()][ValidateSet('Error','Question','Exclamation','Information')][string[]]$type,
[Parameter()][ValidateSet('OK','OKCancel','YesNo','YesNoCancel')][string[]]$button,
$title,$body
){[System.Windows.MessageBox]::Show($body,$title,$button,$type)}

#select a file Function
function Get-FileName
{
  param(
      [Parameter(Mandatory=$false)]
      [string] $Filter,
      [Parameter(Mandatory=$false)]
      [switch]$Obj,
      [Parameter(Mandatory=$False)]
      [string]$Title = "Select A File"
    )
 
	[System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
	$OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
  $OpenFileDialog.initialDirectory = $initialDirectory
  $OpenFileDialog.FileName = $Title
  #can be set to filter file types
  IF($Filter -ne $null){
  $FilterString = '{0} (*.{1})|*.{1}' -f $Filter.ToUpper(), $Filter
	$OpenFileDialog.filter = $FilterString}
  if(!($Filter)) { $Filter = "All Files (*.*)| *.*"
  $OpenFileDialog.filter = $Filter
  }
  $OpenFileDialog.ShowDialog() | Out-Null
  ## dont bother asking, just give back the object
  IF($OBJ){
  $fileobject = GI -Path $OpenFileDialog.FileName.tostring()
  Return $fileObject
  }
  else{Return $OpenFileDialog.FileName}
}

#select folder location
function Get-Folder {
    param([string]$Description="Select Folder to place results in",[string]$RootFolder="Desktop")

 [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
     Out-Null     

   $objForm = New-Object System.Windows.Forms.FolderBrowserDialog
        $objForm.Rootfolder = $RootFolder
        $objForm.Description = $Description
        $Show = $objForm.ShowDialog()
        If ($Show -eq "OK")
        {
            Return $objForm.SelectedPath
        }
        Else
        {
            Write-Error "Operation cancelled by user."
        }
}
$SMSProvider = get-wmiobject sms_providerlocation -namespace root\sms -filter “ProviderForLocalSite = True”
$SiteCode = $SMSProvider.SiteCode
$siteserver = $SMSProvider.__SERVER

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-host "My directory is $dir"
$configs = Import-Csv $dir\configs.csv
write-host $configs

do{
    $Company = $configs.Company
	do{
        $Company = InputBox -title "Company" -body "Enter Company/Organization name" -default $Company
    }while($Company -eq " ")
    IF($Company -eq ""){Return}
	$companyApprove = AckBox -type Question -button YesNo -title "Organization Verification" -body “You have entered $Company as your Organization's name is this correct”
}until($companyApprove -eq "Yes")
do{
    do{
        $DBServer = InputBox -title "Server" -body "Enter SCCM DB Server name" -default $siteserver
    }while($DBServer -eq " ")
    IF($DBServer -eq ""){Return}
	$serverApprove = AckBox -type Question -button YesNo -title "Server Verification" -body “You have entered $DBServer as your SCCM DB Server is this correct”
}until($serverApprove -eq "Yes")
do{
    do{
        $SiteCode = InputBox -title "SiteCode" -body "Enter SCCM Site Code" -default $SiteCode
    }while($SiteCode -eq " ")
    IF($SiteCode -eq ""){Return}
    $sitecodeApprove = AckBox -type Question -button YesNo -title "Site Code Verification" -body “You have entered $SiteCode as your SCCM Site Code, is this correct”
}until($sitecodeApprove -eq "Yes")
do{
    do{
        $DB = InputBox -title "DataBase" -body "Enter SCCM Database name" -default $configs.Database
    }while($DB -eq " ")
    IF($DB -eq ""){Return}
	$dbApprove = AckBox -type Question -button YesNo -title "DB Verification" -body “You have entered $DB as your SCCM Database is this correct”
}until($dbApprove -eq "Yes")
do{
    do{
        $siteServer = InputBox -title "Site Server" -body "Enter Primary SCCM Site Server" -default $siteserver
    }while($siteServer -eq " ")
    IF($siteServer -eq ""){Return}
	$siteserverApprove = AckBox -type Question -button YesNo -title "SCCM Site Server Verification" -body “You have entered $siteServer as your Primary SCCM Site Server is this correct”
}until($siteserverApprove -eq "Yes")

$serverlist = (Import-Csv $dir\sccmservrolelist.csv|select -ExpandProperty "Server Name" -Unique) -join ","
AckBox -type Information -button OKCancel -title "SCCM Server List" -body "Next you will be prompted to verify your list of SCCM Servers and DPs, please ensure the list is correct"
$serverlistapprove = Ackbox -type Question -button YesNo -title "Verify your server list, if it looks accurate select Yes" -body $serverlist
If($serverlistapprove -eq "No")
{
    AckBox -type Information -button OKCancel -title "SCCM Server List" -body "Please Select a TXT File that contains a comma seperated list of your SCCM servers"
    $serverfile = Get-FileName -Title "SCCM servers list" -Obj txt
    $serverlist = Get-Content $serverfile
}


$Company
$DBServer
$SiteCode
$DB
$siteServer
$serverlist

$config = 
@"
<Settings>
	<CentralSettings>
		<SCCMCentralDBName>$DB</SCCMCentralDBName>
		<SCCMCentralDBServerName>$DBServer</SCCMCentralDBServerName>
	</CentralSettings>

	<SCCMSettings>
		<ProjectName>$Company</ProjectName>	
		<OutputFileName>ConfigMgr_Servers_Health_Check_Reports</OutputFileName>
		<strServers>$serverlist,</strServers>
		<strMPServers>JAXSCCM02</strMPServers>
		<strServicesServers>$serverlist,</strServicesServers>
		<SiteCode>$SiteCode</SiteCode>
		<SMSProviderServerName>$siteServer</SMSProviderServerName>
		<SMSDBServerName>$DBServer</SMSDBServerName>		
	</SCCMSettings>

	<EmailSettings>
		<TriggerMail>No</TriggerMail>
		<SMTPServer>SMTP_Server_Name</SMTPServer>
		<FromAddress>sccmhealthcheckalert@domainname.com</FromAddress>
		<ToAddress></ToAddress>
		<CCAddress></CCAddress>
		<BCCAddress></BCCAddress>
	</EmailSettings>

	<HealthCheckCustomSettings>
		<CheckServersAvailabilityRpt>Yes</CheckServersAvailabilityRpt>
		<CheckServersDiskSpaceRpt>Yes</CheckServersDiskSpaceRpt>
		<CheckServersMPRpt>Yes</CheckServersMPRpt>
		<CheckSiteServersServicesRpt>Yes</CheckSiteServersServicesRpt>
		<CheckSQLServerServicesRpt>Yes</CheckSQLServerServicesRpt>
		<CheckBackupsRpt>Yes</CheckBackupsRpt>
		<CheckInboxRpt>Yes</CheckInboxRpt>
		<CheckIssueSiteServersRpt>Yes</CheckIssueSiteServersRpt>
		<CheckCompRpt>Yes</CheckCompRpt>
		<CheckWaitingContentRpt>Yes</CheckWaitingContentRpt>
		<GenerateCSVRpt>Yes</GenerateCSVRpt>	    
	</HealthCheckCustomSettings>

	<DefaultSettings>
		<InboxWarningCount>1000</InboxWarningCount>
		<InboxCriticalCount>5000</InboxCriticalCount>
		<WarningDiskSpacePercentage>15</WarningDiskSpacePercentage>
		<CriticalDiskSpacePercentage>10</CriticalDiskSpacePercentage>
		<CheckSiteBackup>Yes</CheckSiteBackup>
		<CheckDBBackup>Yes</CheckDBBackup>	
		<HistoryRpt>-30</HistoryRpt>
	</DefaultSettings>

	<HTMLSettings>
		<HeaderBGColor>#425563</HeaderBGColor>
		<FooterBGColor>#425563</FooterBGColor>
		<TableHeaderBGColor>#01A982</TableHeaderBGColor>
		<TableHeaderRowBGColor>#CCCCCC</TableHeaderRowBGColor>
		<TextColor>white</TextColor>
	</HTMLSettings>		
</Settings>

"@

#$path = Get-Folder -Description "Select Folder to place Config file"
$config|Out-File $dir"\"ConfigFile.xml
