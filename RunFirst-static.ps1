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

#Allows For Running SQL Queries
Function Invoke-SQLQuery {   
    <#
    .SYNOPSIS
        Quickly run a query against a SQL server.
    .DESCRIPTION
        Simple function to run a query against a SQL server.
    .PARAMETER Instance
        Server name and instance (if needed) of the SQL server you want to run the query against.  E.G.  SQLServer\Payroll
    .PARAMETER Database
        Name of the database the query must run against
    .PARAMETER Credential
        Supply alternative credentials
    .PARAMETER MultiSubnetFailover
        Connect to a SQL 2012 AlwaysOn Availability group.  This parameter requires the SQL2012 Native Client to be installed on
        the machine you are running this on.  MultiSubnetFailover will give your script the ability to talk to a AlwaysOn Availability
        cluster, no matter where the primary database is located.
    .PARAMETER Query
        Text of the query you wish to run.  This parameter is optional and if not specified the script will create a text file in 
        your temporary directory called Invoke-SQLQuery-Query.txt.  You can put your query text in this file and when you save and 
        exit the script will execute that query.
    .PARAMETER NoInstance
        By default Invoke-SQLQuery will add a column with the name of the instance where the data was retrieved.  Use this switch to
        suppress that behavior.
    .PARAMETER PrintToStdOut
        If your query is using the PRINT statement, instead of writing that to the verbose stream, this switch will write that output
        to StdOut.
    .PARAMETER Timeout
        Time Invoke-SQLQuery will wait for SQL Server to return data.  Default is 120 seconds.
    .PARAMETER ListDatabases
        Use this switch to get a list of all databases on the Instance you specified.
    .INPUTS
        String              Will accept the query text from pipeline
    .OUTPUTS
        System.Data.DataRow
    .EXAMPLE
        Invoke-SQLQuery -Instance faxdba101 -Database RightFax -Query "Select top 25 * from Documents where fcsfile <> ''"
        
        Runs a query against faxdba101, Rightfax database.
    .EXAMPLE
        Get-Content c:\sql\commonquery.txt | Invoke-SQLQuery -Instance faxdba101,faxdbb101,faxdba401 -Database RightFax
        
        Run a query you have stored in commonquery.txt against faxdba101, faxdbb101 and faxdba401
    .EXAMPLE
        Invoke-SQLQuery -Instance dbprod102 -ListDatabases
        
        Query dbprod102 for all databases on the SQL server
    .NOTES
        Author:             Martin Pugh
        Date:               7/11/2014
          
        Changelog:
            1.0             Initial Release
            1.1             7/11/14  - Changed $Query parameter that if none specified it will open Notepad for editing the query
            1.2             7/17/14  - Added ListDatabases switch so you can see what databases a server has
            1.3             7/18/14  - Added ability to query multiple SQL servers, improved error logging, add several more examples
                                       in help.
            1.4             10/24/14 - Added support for SQL AlwaysOn
            1.5             11/28/14 - Moved into SQL.Automation Module, fixed bug so script will properly detect when no information is returned from the SQL query
            1.51            1/28/15  - Added support for SilentlyContinue, so you can suppress the warnings if you want 
            1.6             3/5/15   - Added NoInstance switch
            1.61            10/14/15 - Added command timeout
            2.0             11/13/15 - Added ability to stream Message traffic (from PRINT command) to verbose stream.  Enhanced error output, you can now Try/Catch
                                       Invoke-SQLQuery.  Updated documentation. 
            2.01            12/23/15 - Fixed piping query into function
        Todo:
            1.              Alternate port support?
    .LINK
        https://github.com/martin9700/Invoke-SQLQuery
    #>
    [CmdletBinding(DefaultParameterSetName="query")]
    Param (
        [string[]]$Instance = $env:COMPUTERNAME,
        
        [Parameter(ParameterSetName="query",Mandatory=$true)]
        [string]$Database,
        
        [Management.Automation.PSCredential]$Credential,
        [switch]$MultiSubnetFailover,
        
        [Parameter(ParameterSetName="query",ValueFromPipeline=$true)]
        [string]$Query,

        [Parameter(ParameterSetName="query")]
        [switch]$NoInstance,

        [Parameter(ParameterSetName="query")]
        [switch]$PrintToStdOut,

        [Parameter(ParameterSetName="query")]
        [int]$Timeout = 120,

        [Parameter(ParameterSetName="list")]
        [switch]$ListDatabases
    )

    Begin {
        If ($ListDatabases)
        {   
            $Database = "Master"
            $Query = "Select Name,state_desc as [State],recovery_model_desc as [Recovery Model] From Sys.Databases"
        }        
        
        $Message = New-Object -TypeName System.Collections.ArrayList

        $ErrorHandlerScript = {
            Param(
                $Sender, 
                $Event
            )

            $Message.Add([PSCustomObject]@{
                Number = $Event.Errors.Number
                Line = $Event.Errors.LineNumber
                Message = $Event.Errors.Message
            }) | Out-Null
        }
    }

    End {
        If ($Input)
        {   
            $Query = $Input -join "`n"
        }
        If (-not $Query)
        {   
            $Path = Join-Path -Path $env:TEMP -ChildPath "Invoke-SQLQuery-Query.txt"
            Start-Process Notepad.exe -ArgumentList $Path -Wait
            $Query = Get-Content $Path
        }

        If ($Credential)
        {   
            $Security = "uid=$($Credential.UserName);pwd=$($Credential.GetNetworkCredential().Password)"
        }
        Else
        {   
            $Security = "Integrated Security=True;"
        }
        
        If ($MultiSubnetFailover)
        {   
            $MSF = "MultiSubnetFailover=yes;"
        }
        
        ForEach ($SQLServer in $Instance)
        {   
            $ConnectionString = "data source=$SQLServer,1433;Initial catalog=$Database;$Security;$MSF"
            $SqlConnection = New-Object System.Data.SqlClient.SqlConnection
            $SqlConnection.ConnectionString = $ConnectionString
            $SqlCommand = $SqlConnection.CreateCommand()
            $SqlCommand.CommandText = $Query
            $SqlCommand.CommandTimeout = $Timeout
            $Handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] $ErrorHandlerScript
            $SqlConnection.add_InfoMessage($Handler)
            $SqlConnection.FireInfoMessageEventOnUserErrors = $true
            $DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $SqlCommand
            $DataSet = New-Object System.Data.Dataset

            Try {
                $Records = $DataAdapter.Fill($DataSet)
                If ($DataSet.Tables[0])
                {   
                    If (-not $NoInstance)
                    {
                        $DataSet.Tables[0] | Add-Member -MemberType NoteProperty -Name Instance -Value $SQLServer
                    }
                    Write-Output $DataSet.Tables[0]
                }
                Else
                {   
                    Write-Verbose "Query did not return any records"
                }
            }
            Catch {
                $SqlConnection.Close()
                Write-Error $LastError.Exception.Message
                Continue
            }
            $SqlConnection.Close()
        }

        If ($Message)
        {
            ForEach ($Warning in ($Message | Where Number -eq 0))
            {
                If ($PrintToStdOut)
                {
                    Write-Output $Warning.Message
                }
                Else
                {
                    Write-Verbose $Warning.Message -Verbose
                }
            }
            $Errors = @($Message | Where Number -ne 0)
            If ($Errors.Count)
            {
                ForEach ($MsgError in $Errors)
                { 
                    Write-Error "Query Error $($MsgError.Number), Line $($MsgError.Line): $($MsgError.Message)"
                }
            }
        }
    }
}

#String to Get the Database
$string = @"
SELECT Name, database_id create_date
FROM sys.databases
"@

$SMSProvider = get-wmiobject sms_providerlocation -namespace root\sms -filter “ProviderForLocalSite = True”
$SiteCode = $SMSProvider.SiteCode
$siteserver = $SMSProvider.__SERVER
$domain = (Get-WmiObject Win32_ComputerSystem).Domain

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-host "My directory is $dir"
$configs = Import-Csv $dir\configs.csv
write-host $configs
$server_roles = Import-Csv $dir\sccmservrolelist.csv

do{
	$Company = (Get-Culture).textinfo.totitlecase(($domain).split(".")[0].tolower())
	do{
        $Company = InputBox -title "Company" -body "Enter Company/Organization name" -default $Company
    }while($Company -eq " ")
    IF($Company -eq ""){Return}
	$companyApprove = AckBox -type Question -button YesNo -title "Organization Verification" -body “You have entered $Company as your Organization's name is this correct”
}until($companyApprove -eq "Yes")
do{
	$DBServerAuto = ($server_roles|where{$_.Role -eq "SMS SQL Server"})."Server Name"
    do{
        $DBServer = InputBox -title "Server" -body "Enter SCCM DB Server name" -default $DBServerAuto
    }while($DBServer -eq " ")
    IF($DBServer -eq ""){Return}
	$DBserverApprove = AckBox -type Question -button YesNo -title "Server Verification" -body “You have entered $DBServer as your SCCM DB Server is this correct”
}until($DBserverApprove -eq "Yes")
do{
    do{
        $SiteCode = InputBox -title "SiteCode" -body "Enter SCCM Site Code" -default $SiteCode
    }while($SiteCode -eq " ")
    IF($SiteCode -eq ""){Return}
    $sitecodeApprove = AckBox -type Question -button YesNo -title "Site Code Verification" -body “You have entered $SiteCode as your SCCM Site Code, is this correct”
}until($sitecodeApprove -eq "Yes")
do{
    do{
        $DBs = Invoke-SQLQuery -Instance $DBServer -Query $string -Database "Master"
		IF($DBs -ne $NULL -and $DBs -ne ""){$DBName = ($DBs|where{$_.Name -like "*$SiteCode"}).Name}
		$DB = InputBox -title "DataBase" -body "Enter SCCM Database name" -default $DBName
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

$serverlist = ($server_roles|select -ExpandProperty "Server Name" -Unique) -join ","
AckBox -type Information -button OKCancel -title "SCCM Server List" -body "Next you will be prompted to verify your list of SCCM Servers and DPs, please ensure the list is correct"
$serverlistapprove = Ackbox -type Question -button YesNo -title "Verify your server list, if it looks accurate select Yes" -body $serverlist
If($serverlistapprove -eq "No")
{
    AckBox -type Information -button OKCancel -title "SCCM Server List" -body "Please Select a TXT File that contains a comma seperated list of your SCCM servers"
    $serverfile = Get-FileName -Title "SCCM servers list" -Obj txt
    $serverlist = Get-Content $serverfile
}

do{
	$smtpserver = InputBox -title "SMTPServer" -body "Please Enter Your SMTP Server" -default "smtp.$domain"
	$smtpapprove = AckBox -type Question -button YesNo -title "Verify Your SMTP Server" -body "You have entered $smtpserver as your SMTP server is this correct"
}until($smtpapprove -eq "Yes")

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
		<TriggerMail>Yes</TriggerMail>
		<SMTPServer>$smtpserver</SMTPServer>
		<FromAddress>sccmhealthcheckalert@$domain</FromAddress>
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


AckBox -type Exclamation -button OK -title "Information Verification" -body "Your Generated Configuration File will open now, Please Verify the servers are correct"
Start-Process notepad $dir\ConfigFile.xml

$complete = AckBox -type Question -button YesNo "File Correct" -body "To the best of your knowledge do the configured details look correct?"

If($complete -eq "No"){AckBox -type Exclamation -button OK -title "Failed" -body "Please verify that your configs.csv contains the correct information then attempt to rerun the tool, if it is still incorrect after re-run please contact your Administrator"}
