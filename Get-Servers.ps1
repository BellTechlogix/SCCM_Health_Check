#
# Get_Servers.ps1
#

$SMSProvider = get-wmiobject sms_providerlocation -namespace root\sms -filter “ProviderForLocalSite = True”
$SiteCode = $SMSProvider.SiteCode
$siteserver = $SMSProvider.__SERVER

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
Write-host "My directory is $dir"

IF($SMSProvider -eq $NULL){
    $localserver = $env:computername
    $SCCMSiteCode = $([WmiClass]"\\localhost\ROOT\ccm:SMS_Client").GetAssignedSite()
    $sitecode = $SCCMSiteCode.sSiteCode
    $siteserver = $SCCMSiteCode.__SERVER
}

$smsserver=$siteserver
$modulepath="\\$smsserver\SMS_$sitecode\AdminConsole\bin"
remove-psdrive -Name $sitecode -ErrorAction SilentlyContinue -Force
if ($env:username -eq "system"){
    $usercreds=get-credential -message "Enter your User ID and Password to access network resources" -username "domain\"
    if (!(Test-Path "x:\windows\system32\windowspowershell\v1.0\modules\configurationmanager")){
    new-psdrive -Name "y" -Root $modulepath -PSProvider FileSystem -Credential $usercreds -ErrorAction SilentlyContinue
    Copy-Item y: -Destination x:\windows\system32\windowspowershell\v1.0\modules\configurationmanager -recurse
    }
    import-module configurationmanager
    new-psdrive -Name "$sitecode" -PSProvider CMSite -Root $smsserver -Credential $usercreds
    set-location $sitecode":"
}
else{
    if (!(Test-Path "CRW:")){
        if(($ENV:SMS_ADMIN_UI_PATH).length -gt 0){
            Import-Module (Join-Path $(Split-Path $ENV:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1)
            start-sleep 5
            new-psdrive -Name "$sitecode" -PSProvider CMSite -Root $smsserver -ErrorAction SilentlyContinue
            }
        else{
            new-psdrive -Name "y" -Root $modulepath -PSProvider FileSystem
            import-module "y:\configurationmanager\ConfigurationManager.psd1" -erroraction silentlycontinue
            start-sleep 5
            new-psdrive -Name "$sitecode" -PSProvider CMSite -Root $smsserver -ErrorAction SilentlyContinue}
            }
    set-location $sitecode":"
}


  #region SiteRoles
If ($ListAllInformation){
  $SiteRolesTable = @()  
  $SiteRoles = Get-CMSiteRole -SiteCode $SiteCode

  foreach ($SiteRole in $SiteRoles) {
    If (($SiteRole.RoleName -eq 'SMS Component Server') `
        -or ($SiteRole.RoleName -eq 'SMS Site Server') `
        -or ($SiteRole.RoleName -eq 'SMS Notification Server') `
        -or ($SiteRole.RoleName -eq 'SMS DM Enrollment Service') `
        -or ($SiteRole.RoleName -eq 'SMS Multicast Service Point')
    ) {
        # Nothing to do
        continue
    }

    $RoleName = ""
    # Get Role settings
    $RoleSettings = @()
    Switch ($SiteRole.RoleName) {
        #region RoleSiteSystem
        'SMS Site System' {
            $RoleName = "Site system"
            $RoleSettings += @("--B--General--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "Server Remote Public Name" }).Value1 -ne "") {
                $RoleSettings += @("- Specify FQDN for use on the Internet - CHECKED")
                $RoleSettings += @("--TAB--Internet FQDN: $(($SiteRole.Props | ? { $_.PropertyName -eq "Server Remote Public Name" }).Value1)")
            }
            Else {
                $RoleSettings += @("- Specify FQDN for use on the Internet - UNCHECKED")
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "FDMOperation" }).Value -eq 1) {
                $RoleSettings += @("- Require the site server to initiate connections - CHECKED")
            }
            Else {
                $RoleSettings += @("- Require the site server to initiate connections - UNCHECKED")
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "UseMachineAccount" }).Value -eq 1) {
                $RoleSettings += @("- Installation account: Site server's computer")
            }
            Else {
                $RoleSettings += @("- Installation account: $(($SiteRole.Props | ? { $_.PropertyName -eq "UserName" }).Value2)")
            }
            $RoleSettings += @("- Active Directory forest: $(($SiteRole.Props | ? { $_.PropertyName -eq "ForestFQDN" }).Value1)")
            $RoleSettings += @("- Active Directory domain: $(($SiteRole.Props | ? { $_.PropertyName -eq "DomainFQDN" }).Value1)")
            $RoleSettings += @("--B--Proxy--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "UseProxy" }).Value -eq 1) {
                $RoleSettings += @("- Proxy: Configured")
                $RoleSettings += @("--TAB--Proxy server name: $(($SiteRole.Props | ? { $_.PropertyName -eq "ProxyName" }).Value2)")
                $RoleSettings += @("--TAB--Port: $(($SiteRole.Props | ? { $_.PropertyName -eq "ProxyServerPort" }).Value)")
                If (($SiteRole.Props | ? { $_.PropertyName -eq "ProxyUserName" }).Value2 -ne "") {
                    $RoleSettings += @("--TAB--Proxy account: $(($SiteRole.Props | ? { $_.PropertyName -eq "ProxyUserName" }).Value2)")
                }
                Else {
                    $RoleSettings += @("--TAB--Proxy account: No account configured")
                }
            }
            Else {
                $RoleSettings += @("- Proxy: Not configured")
            }
        }
        #endregion RoleSiteSystem
        #region RoleDP
        'SMS Distribution Point' {
            $RoleName = "Distribution point"
            $RoleSettings += @("--B--General--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "UpdateBranchCacheKey" }).Value -eq 1) {
                $RoleSettings += @("- BranchCache: Enabled")
            }
            Else {
                $RoleSettings += @("- BranchCache: Disabled")
            }
            $RoleSettings += @("- Description: $(($SiteRole.Props | ? { $_.PropertyName -eq "Description" }).Value1)")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "SslState" }).Value -eq 63) {
                $RoleSettings += @("- Communication: HTTPS")
                If (($SiteRole.Props | ? { $_.PropertyName -eq "TokenAuthEnabled" }).Value -eq 1) {
                    $RoleSettings += @("--TAB--Allow mobile devices to connect - CHECKED")
                }
                Else {
                    $RoleSettings += @("--TAB--Allow mobile devices to connect - UNCHECKED")
                }
            }
            Else {
                $RoleSettings += @("- Communication: HTTP")
                If (($SiteRole.Props | ? { $_.PropertyName -eq "IsAnonymousEnabled" }).Value -eq 1) {
                    $RoleSettings += @("--TAB--Allow clients to connect anonymously - CHECKED")
                }
                Else {
                    $RoleSettings += @("--TAB--Allow clients to connect anonymously - UNCHECKED")
                }
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "CertificateFile" }).Value1 -eq "") {
                $RoleSettings += @("- Certificate: Self-signed")
            }
            Else {
                $RoleSettings += @("- Certificate: Imported")
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "PreStagingAllowed" }).Value -eq 1) {
                $RoleSettings += @("- Enable for prestaged content - CHECKED")
            }
            Else {
                $RoleSettings += @("- Enable for prestaged content - UNCHECKED")
            }
            $RoleSettings += @("--B--PXE--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "IsPXE" }).Value -eq 1) {
                $RoleSettings += @("- PXE support: Enabled")
                If (($SiteRole.Props | ? { $_.PropertyName -eq "IsActive" }).Value -eq 1) {
                    $RoleSettings += @("--TAB--Allow to respond to incoming PXE requests - CHECKED")
                }
                Else {
                    $RoleSettings += @("--TAB--Allow to respond to incoming PXE requests - UNCHECKED")
                }
                If (($SiteRole.Props | ? { $_.PropertyName -eq "SupportUnknownMachines" }).Value -eq 1) {
                    $RoleSettings += @("--TAB--Enable unknow computer support - CHECKED")
                }
                Else {
                    $RoleSettings += @("--TAB--Enable unknow computer support - UNCHECKED")
                }
                If (($SiteRole.Props | ? { $_.PropertyName -eq "PXEPassword" }).Value1 -ne "") {
                    $RoleSettings += @("--TAB--Require a password when computers use PXE - CHECKED")
                }
                Else {
                    $RoleSettings += @("--TAB--Require a password when computers use PXE - UNCHECKED")
                }
                Switch (($SiteRole.Props | ? { $_.PropertyName -eq "UdaSetting" }).Value) {
                    0 {$RoleSettings += @("- User device affinity: Do not use user device affinity")}
                    1 {$RoleSettings += @("- User device affinity: Allow user device affinity with manual approval")}
                    2 {$RoleSettings += @("- User device affinity: Allow user device affinity woth automatic approval")}
                }
                If (($SiteRole.Props | ? { $_.PropertyName -eq "BindPolicy" }).Value -eq 0) {
                    $RoleSettings += @("- Respond to PXE requests on all network interfaces - CHECKED")
                }
                Else {
                    $RoleSettings += @("- Respond to PXE requests on specific network interfaces - CHECKED")
                }
                $RoleSettings += @("- PXE response delay (seconds): $(($SiteRole.Props | ? { $_.PropertyName -eq "ResponseDelay" }).Value)")
            }
            Else {
                $RoleSettings += @("- PXE support: Disabled")
            }
            $RoleSettings += @("--B--Multicast--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "IsMulticast" }).Value -eq 1) {
                $RoleSettings += @("- Multicast support: Enabled")
                $MCSettings = (Get-CMMulticastServicePoint -SiteSystemServerName ($SiteRole.NALPath).ToString().Split('\\')[2]).Props
                If ($MCSettings -eq $Null) {
                    $RoleSettings += @("--TAB--Multicast configuration unavailable")
                }
                Else {
                    If (($MCSettings | ? { $_.PropertyName -eq "AuthType" }).Value -eq 1) {
                        $RoleSettings += @("- Multicast connection account: $(($MCSettings | ? { $_.PropertyName -eq "UserName" }).Value1)")
                    }
                    Else {
                        $RoleSettings += @("- Multicast connection account: DP's computer account")
                    }
                    If (($MCSettings | ? { $_.PropertyName -eq "IpAddressSource" }).Value -eq 1) {
                        $RoleSettings += @("- Multicast address settings: Use IPv4 addresses within any range - CHECKED")
                    }
                    Else {
                        $RoleSettings += @("- Multicast address settings: Use IPv4 addresses from the following range - CHECKED")
                        $RoleSettings += @("--TAB--Address start range: $(($MCSettings | ? { $_.PropertyName -eq "StartIpAddress" }).Value1)")
                        $RoleSettings += @("--TAB--Address end range: $(($MCSettings | ? { $_.PropertyName -eq "EndIpAddress" }).Value1)")
                    }
                    $RoleSettings += @("- UDP settings:")
                    $RoleSettings += @("--TAB--Port range start: $(($MCSettings | ? { $_.PropertyName -eq "StartPort" }).Value)")
                    $RoleSettings += @("--TAB--Port range end: $(($MCSettings | ? { $_.PropertyName -eq "EndPort" }).Value)")
                    $RoleSettings += @("- Maximum clients: $(($MCSettings | ? { $_.PropertyName -eq "Multicast Max Clients" }).Value)")
                    If (($MCSettings | ? { $_.PropertyName -eq "Multicast Session Schedule Cast" }).Value -eq 1) {
                        $RoleSettings += @("- Scheduled multicast - CHECKED")
                        $RoleSettings += @("--TAB--Session start delay (minutes): $(($MCSettings | ? { $_.PropertyName -eq "Multicast Session Start Delay" }).Value)")
                        $RoleSettings += @("--TAB--Minimum session size (clients): $(($MCSettings | ? { $_.PropertyName -eq "Multicast Session Minimum Size" }).Value)")
                    }
                    Else {
                        $RoleSettings += @("- Scheduled multicast - UNCHECKED")
                    }
                }
            }
            Else {
                $RoleSettings += @("- Multicast support: Disabled")
            }
            $RoleSettings += @("--B--Content Validation--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "DPMonEnabled" }).Value -eq 1) {
                $RoleSettings += @("- Content validation schedule: Enabled")
                $Schedule = Convert-CMSchedule -ScheduleString ($SiteRole.Props | ? { $_.PropertyName -eq "DPMonSchedule" }).Value1
                if ($Schedule.DaySpan -gt 0) {
                    $RoleSettings += @("--TAB--Occurs every $($Schedule.DaySpan) days effective $($Schedule.StartTime)")
                }
                elseif ($Schedule.HourSpan -gt 0) {
                    $RoleSettings += @("--TAB--Occurs every $($Schedule.HourSpan) hours effective $($Schedule.StartTime)")
                }
                elseif ($Schedule.MinuteSpan -gt 0) {
                    $RoleSettings += @("--TAB--Occurs every $($Schedule.MinuteSpan) minutes effective $($Schedule.StartTime)")
                }
                elseif ($Schedule.ForNumberOfWeeks) {
                    $RoleSettings += @("--TAB--Occurs every $($Schedule.ForNumberOfWeeks) weeks on $(Convert-WeekDay $Schedule.Day) effective $($Schedule.StartTime)")
                }
                elseif ($Schedule.ForNumberOfMonths) {
                    if ($Schedule.MonthDay -gt 0) {
                        $RoleSettings += @("--TAB--Occurs on day $($Schedule.MonthDay) of every $($Schedule.ForNumberOfMonths) months effective $($Schedule.StartTime)")
                    }
                    elseif ($Schedule.MonthDay -eq 0) {
                        $RoleSettings += @("--TAB--Occurs the last day of every $($Schedule.ForNumberOfMonths) months effective $($Schedule.StartTime)")
                    }
                    elseif ($Schedule.WeekOrder -gt 0) {
                        switch ($Schedule.WeekOrder) {
                            0 {$order = 'last'}
                            1 {$order = 'first'}
                            2 {$order = 'second'}
                            3 {$order = 'third'}
                            4 {$order = 'fourth'}
                        }
                        $RoleSettings += @("--TAB--Occurs the $($order) $(Convert-WeekDay $Schedule.Day) of every $($Schedule.ForNumberOfMonths) months effective $($Schedule.StartTime)")
                    }
                }
                Switch (($SiteRole.Props | ? { $_.PropertyName -eq "DPMonPriority" }).Value) {
                    4 { $ValidPriority = "Lowest" }
                    5 { $ValidPriority = "Low" }
                    6 { $ValidPriority = "Medium" }
                    7 { $ValidPriority = "High" }
                    8 { $ValidPriority = "Highest" }
                }
                $RoleSettings += @("- Content validation priority: $ValidPriority")
            }
            Else {
                $RoleSettings += @("- Content validation schedule: Disabled")
            }
            $RoleSettings += @("--B--Boundary Groups--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "DistributeOnDemand" }).Value -eq 1) {
                $RoleSettings += @("- Enable for on-demand distribution - CHECKED")
            }
            Else {
                $RoleSettings += @("- Enable for on-demand distribution - UNCHECKED")
            }
            # Get schedule and rate limit
            $DPInfo = Get-WmiObject -Namespace "root\sms\site_$SiteCode" -Query "select * from SMS_SCI_address where ItemName = '$(($SiteRole.NALPath).ToString().Split('\\')[2])|MS_LAN'"  -ComputerName $SMSProvider
            If ($DPInfo) {
                # Schedule
                $RoleSettings += @("--B--Schedule--/B--")
                $RoleSettings += @("- Legend: 1 means all Priorities, 2 means all but low, 3 is high only, 4 means none")
                $iDay = 1
                ForEach ($DPSchedule in $DPInfo.UsageSchedule) {
                    $RoleSettings += @("--TAB--$(Convert-WeekDay $iDay): $($DPSchedule.HourUsage)")
                    $iDay++
                }
                # Rate limits
                $RoleSettings += @("--B--Rate Limits--/B--")
                If ($DPInfo.UnlimitedRateForAll) {
                    $RoleSettings += @("- Rate limit: Unlimited")
                }
                ElseIf (-not [String]::IsNullOrEmpty($DPInfo.RateLimitingSchedule)) {
                    $RoleSettings += @("- Rate limit: Per hour (in %)")
                    $RoleSettings += @("--TAB--Schedule: $($DPInfo.RateLimitingSchedule)")
                }
                Else {
                    $RoleSettings += @("- Rate limit: Pulse mode")
                    $RoleSettings += @("--TAB--Size of data block (KB): $($DPInfo.PropLists.Values[1])")
                    $RoleSettings += @("--TAB--Delay between data blocks (seconds): $($DPInfo.PropLists.Values[2])")
                }
                $RoleSettings += @("--B--Pull Distribution Point--/B--")
                If (($SiteRole.Props | ? { $_.PropertyName -eq "IsPullDP" }).Value -eq 1) {
                    $RoleSettings += @("- Enable to pull content from other DP - CHECKED")
                }
                Else {
                    $RoleSettings += @("- Enable to pull content from other DP - UNCHECKED")
                }
            }
        }
        #endregion RoleDP
        #region RoleMP
        'SMS Management Point' {
            $RoleName = "Management point"
            $RoleSettings += @("--B--General--/B--")
            If ($SiteRole.SslState -eq 1) { $RoleSettings += @("- Client connections: HTTPS") }
            Else { $RoleSettings += @("- Client connections: HTTP") }
            If (Get-CMAlert -Name "Not healthy*Management point*$(($SiteRole.NALPath).ToString().Split('\\')[2])*") {
                $RoleSettings += @("- Generate alert when the MP is not healthy - CHECKED")
            }
            Else {
                $RoleSettings += @("- Generate alert when the MP is not healthy - UNCHECKED")
            }
            $RoleSettings += @("--B--Management Point Database--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "UseSiteDatabase" }).Value -eq 1) {
                $RoleSettings += @("- Database: Site database")
            }
            Else {
                $RoleSettings += @("- Database: Database replica")
                $RoleSettings += @("--TAB--Database server: $(($SiteRole.Props | ? { $_.PropertyName -eq "SQLServerName" }).Value1)")
                $RoleSettings += @("--TAB--Database name: $(($SiteRole.Props | ? { $_.PropertyName -eq "DatabaseName" }).Value1)")
            }
            If (-not [String]::IsNullOrEmpty(($SiteRole.Props | ? { $_.PropertyName -eq "UserName" }).Value1)) {
                $RoleSettings += @("- Connection account: $(($SiteRole.Props | ? { $_.PropertyName -eq "UserName" }).Value1)")
            }
            Else {
                $RoleSettings += @("- Connection account: MP's computer account")
            }
        }
        #endregion RoleMP
        #region RoleFSP
        'SMS Fallback Status Point' {
            $RoleName = "Fallback status point"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- Number of state messages: $(($SiteRole.Props | ? { $_.PropertyName -eq "Throttle Count" }).Value)")
            $RoleSettings += @("- Throttle interval (seconds): $(($SiteRole.Props | ? { $_.PropertyName -eq "Throttle Interval" }).Value)")
        }
        #endregion RoleFSP
        #region RoleSQL
        'SMS SQL Server' {
            $RoleName = "Site database server"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- Instance: $(($SiteRole.PropLists.Values -split ", ")[2])")
            $SqlSettings = Get-CMDatabaseProperty -SiteCode $SiteCode #I laugh this cmdlet
            $RoleSettings += @("- Service broker port: $((($SqlSettings -match "Service Broker") -split ",")[1])")
            If ((($SqlSettings -match "IsCompression") -split ",")[1] -eq "1") {
                $RoleSettings += @("- Enable data compression - CHECKED")
            }
            Else {
                $RoleSettings += @("- Enable data compression - UNCHECKED")
            }
            $RoleSettings += @("- Data retention (days): $((($SqlSettings -match "Retention") -split ",")[1])")
        }
        #endregion RoleSQL
        #region RoleRSP
        'SMS SRS Reporting Point' {
            $RoleName = "Reporting services point"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- Database server name: $(($SiteRole.Props | ? { $_.PropertyName -eq "DatabaseServerName" }).Value2)")
            $RoleSettings += @("- Database name: $(($SiteRole.Props | ? { $_.PropertyName -eq "DatabaseName" }).Value2)")
            $RoleSettings += @("- Folder name: $(($SiteRole.Props | ? { $_.PropertyName -eq "RootFolder" }).Value2)")
            $RoleSettings += @("- Reporting Services server instance: $(($SiteRole.Props | ? { $_.PropertyName -eq "ReportServerInstance" }).Value2)")
            $RoleSettings += @("- Reporting Services manager URI: $(($SiteRole.Props | ? { $_.PropertyName -eq "ReportManagerUri" }).Value2)")
            $RoleSettings += @("- Reporting Services server URI: $(($SiteRole.Props | ? { $_.PropertyName -eq "ReportServerUri" }).Value2)")
            $RoleSettings += @("- Reporting Services account: $(($SiteRole.Props | ? { $_.PropertyName -eq "Username" }).Value2)")
        }
        #endregion RoleRSP
        #region RoleSUP
        'SMS Software Update Point' {
            $RoleName = "Software update point"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- WSUS port: $(($SiteRole.Props | ? { $_.PropertyName -eq "WSUSIISPort" }).Value)")
            $RoleSettings += @("- WSUS SSL port: $(($SiteRole.Props | ? { $_.PropertyName -eq "WSUSIISSSLPort" }).Value)")
            $RoleSettings += @("- WSUS DB name: $(($SiteRole.Props | ? { $_.PropertyName -eq "DBServerName" }).Value2)")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "SSLWSUS" }).Value -eq 1) {
                $RoleSettings += @("- WSUS requires SSL - CHECKED")
            }
            Else {
                $RoleSettings += @("- WSUS requires SSL - UNCHECKED")
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "IsIntranet" }).Value -eq 1) {
                If (($SiteRole.Props | ? { $_.PropertyName -eq "IsINF" }).Value -eq 1) {
                    $RoleSettings += @("- WSUS connection type: Allow Internet and Intranet client connections")
                }
                Else {
                    $RoleSettings += @("- WSUS connection type: Allow Intranet-only client connections")
                }
            }
            Else {
                $RoleSettings += @("- WSUS connection type: Allow Internet-only client connections")
            }
            $RoleSettings += @("--B--Proxy And Account Settings--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "UseProxy" }).Value -eq 1) {
                $RoleSettings += @("- Use proxy when synchronizing software updates - CHECKED")
            }
            Else {
                $RoleSettings += @("- Use proxy when synchronizing software updates - UNCHECKED")
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "UseProxyForADR" }).Value -eq 1) {
                $RoleSettings += @("- Use proxy when downloading content by using ADR - CHECKED")
            }
            Else {
                $RoleSettings += @("- Use proxy when downloading content by using ADR - UNCHECKED")
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "WSUSAccessAccount" }).Value2 -ne "") {
                $RoleSettings += @("- WSUS connection account: $(($SiteRole.Props | ? { $_.PropertyName -eq "WSUSAccessAccount" }).Value2)")
            }
            Else {
                $RoleSettings += @("- WSUS connection account: No account defined")
            }
        }
        #endregion RoleSUP
        #region RoleSC
        'SMS Application Web Service' {
            $RoleName = "Application Catalog web service point"
            $RoleSettings += @("--B--General--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "ServiceIISWebSite" }).Value1 -eq "") {
                $RoleSettings += @("- IIS website: Default Web Site")
            }
            Else {
                $RoleSettings += @("- IIS website: $(($SiteRole.Props | ? { $_.PropertyName -eq "ServiceIISWebSite" }).Value1)")
            }
            $RoleSettings += @("- Web application name: $(($SiteRole.Props | ? { $_.PropertyName -eq "ServiceName" }).Value1)")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "SslState" }).Value -eq 0) {
                $RoleSettings += @("- Port: $(($SiteRole.Props | ? { $_.PropertyName -eq "ServicePort" }).Value) (HTTP)")
            }
            Else {
                $RoleSettings += @("- Port: $(($SiteRole.Props | ? { $_.PropertyName -eq "ServicePort" }).Value) (HTTPS)")
            }
        }
        #endregion RoleSC
        #region RoleSCWeb
        'SMS Portal Web Site' {
            $RoleName = "Application Catalog website point"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- IIS web site: $(($SiteRole.Props | ? { $_.PropertyName -eq "PortalIISWebSite" }).Value1)")
            $RoleSettings += @("- Web application name: $(($SiteRole.Props | ? { $_.PropertyName -eq "PortalName" }).Value1)")
            $RoleSettings += @("- NetBIOS name: $(($SiteRole.Props | ? { $_.PropertyName -eq "NetbiosName" }).Value1)")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "SslState" }).Value -eq 0) {
                $RoleSettings += @("- Port: $(($SiteRole.Props | ? { $_.PropertyName -eq "PortalPort" }).Value) (HTTP)")
            }
            Else {
                $RoleSettings += @("- Port: $(($SiteRole.Props | ? { $_.PropertyName -eq "PortalSslPort" }).Value) (HTTPS)")
            }
            $RoleSettings += @("--B--Customization--/B--")
            $RoleSettings += @("Organization name: $(($SiteRole.Props | ? { $_.PropertyName -eq "BrandingString" }).Value1)")
            $RoleSettings += @("Website theme: #$(($SiteRole.Props | ? { $_.PropertyName -eq "PortalThemeColor" }).Value1)")
        }
        #endregion RoleSCWeb
        #region RoleSCP
        'SMS Dmp Connector' {
            $RoleName = "Service connection point"
            $RoleSettings += @("--B--General--/B--")
            If (($SiteRole.Props | ? { $_.PropertyName -eq "OfflineMode" }).Value -eq 0) {
                $RoleSettings += @("- Mode: Online")
            }
            Else {
                $RoleSettings += @("- Mode: Offline")
            }
        }
        #endregion RoleSCP
        #region RoleAI
        'AI Update Service Point' {
            $RoleName = "Asset Intelligence synchronization point"
            $RoleSettings += @("--B--General--/B--")
            $AISettings = Get-CMAssetIntelligenceProxy
            If ($AISettings.ProxyEnabled) {
                $RoleSettings += @("- Use this AI synchronization point - CHECKED")
                $RoleSettings += @("- Port: $($AISettings.Port)")
            }
            Else {
                $RoleSettings += @("- Use this AI synchronization point - UNCHECKED")
            }
            If (-not [String]::IsNullOrEmpty($AISettings.ProxyCertPath)) {
                $RoleSettings += @("- Certificate path: $($AISettings.ProxyCertPath)")
            }
            Else {
                $RoleSettings += @("- Certificate path: None")
            }
            $RoleSettings += @("--B--Synchronization settings--/B--")
            If ($AISettings.PeriodicCatalogUpdateEnabled) {
                $RoleSettings += @("- Synchronization on a schedule: Enabled")
                $Schedule = Convert-CMSchedule -ScheduleString $AISettings.PeriodicCatalogUpdateSchedule
                if ($Schedule.DaySpan -gt 0) {
                    $RoleSettings += @("--TAB--Occurs every $($Schedule.DaySpan) days effective $($Schedule.StartTime)")
                }
                elseif ($Schedule.HourSpan -gt 0) {
                    $RoleSettings += @("--TAB--Occurs every $($Schedule.HourSpan) hours effective $($Schedule.StartTime)")
                }
                elseif ($Schedule.MinuteSpan -gt 0) {
                    $RoleSettings += @("--TAB--Occurs every $($Schedule.MinuteSpan) minutes effective $($Schedule.StartTime)")
                }
                elseif ($Schedule.ForNumberOfWeeks) {
                    $RoleSettings += @("--TAB--Occurs every $($Schedule.ForNumberOfWeeks) weeks on $(Convert-WeekDay $Schedule.Day) effective $($Schedule.StartTime)")
                }
                elseif ($Schedule.ForNumberOfMonths) {
                    if ($Schedule.MonthDay -gt 0) {
                        $RoleSettings += @("--TAB--Occurs on day $($Schedule.MonthDay) of every $($Schedule.ForNumberOfMonths) months effective $($Schedule.StartTime)")
                    }
                    elseif ($Schedule.MonthDay -eq 0) {
                        $RoleSettings += @("--TAB--Occurs the last day of every $($Schedule.ForNumberOfMonths) months effective $($Schedule.StartTime)")
                    }
                    elseif ($Schedule.WeekOrder -gt 0) {
                        switch ($Schedule.WeekOrder) {
                            0 {$order = 'last'}
                            1 {$order = 'first'}
                            2 {$order = 'second'}
                            3 {$order = 'third'}
                            4 {$order = 'fourth'}
                        }
                        $RoleSettings += @("--TAB--Occurs the $($order) $(Convert-WeekDay $Schedule.Day) of every $($Schedule.ForNumberOfMonths) months effective $($Schedule.StartTime)")
                    }
                }
            }
            Else {
                $RoleSettings += @("- Synchronization on a schedule: Disabled")
            }
        }
        #endregion RoleAI
        #region RoleEP
        'SMS Endpoint Protection Point' {
            $RoleName = "Endpoint Protection point"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- License Terms and Privacy Statement acknowledgement - CHECKED")
            $RoleSettings += @("--B--Cloud Protection Service--/B--")
            $RoleSettings += @("- Check manually the membership type selected")
        }
        #endregion RoleEP
        #region RoleEnroll
        'SMS Enrollment Server' {
            $RoleName = "Enrollment point"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- Website name: $(($SiteRole.Props | ? { $_.PropertyName -eq "ServiceIISWebSite" }).Value1)")
            $RoleSettings += @("- Port: $(($SiteRole.Props | ? { $_.PropertyName -eq "ServicePort" }).Value)")
            $RoleSettings += @("- Virtual application name: $(($SiteRole.Props | ? { $_.PropertyName -eq "ServiceName" }).Value1)")
            If (-not [String]::IsNullOrEmpty(($SiteRole.Props | ? { $_.PropertyName -eq "UserName" }).Value1)) {
                $RoleSettings += @("- Connection account: $(($SiteRole.Props | ? { $_.PropertyName -eq "UserName" }).Value1)")
            }
            Else {
                $RoleSettings += @("- Connection account: Enrollment point's computer account")
            }
        }
        #endregion RoleEnroll
        #region RoleEnrollWeb
        'SMS Enrollment Web Site' {
            $RoleName = "Enrollment proxy point"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- Enrollment point: HTTPS://$(($SiteRole.Props | ? { $_.PropertyName -eq "ServiceHostName" }).Value1):$(($SiteRole.Props | ? { $_.PropertyName -eq "ServicePort" }).Value)/$(($SiteRole.Props | ? { $_.PropertyName -eq "ServiceName" }).Value1)")
            $RoleSettings += @("- Website name: $(($SiteRole.Props | ? { $_.PropertyName -eq "EnrollWebIISWebSite" }).Value1)")
            $RoleSettings += @("- Port: $(($SiteRole.Props | ? { $_.PropertyName -eq "EnrollWebPort" }).Value)")
            $RoleSettings += @("- Virtual application name: $(($SiteRole.Props | ? { $_.PropertyName -eq "EnrollWebName" }).Value1)")
        }
        #endregion RoleEnrollWeb
        #region RoleSMP
        'SMS State Migration Point' {
            $RoleName = "State migration point"
            $RoleSettings += @("--B--General--/B--")
            $RoleSettings += @("- Folder details:")
            ($SiteRole.PropLists | ? { $_.PropertyListName -eq "Directories" }).Values | % {
                $StateDirectory = $_ -split "=|;"
                Switch ($StateDirectory[7]) {
                    1 { $SpaceUnit = "MB" }
                    2 { $SpaceUnit = "GB" }
                    3 { $SpaceUnit = "%" }
                }
                $RoleSettings += @("--TAB--Storage folder: $($StateDirectory[1]) | Max clients: $($StateDirectory[3]) | Min free space: $($StateDirectory[5])$SpaceUnit")
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "SMPStoreDeletionCycleTimeInMinutes" }).Value -eq 0) {
                $RoleSettings += @("- Deletion policy: Immediatly")
            }
            Else {
                $RoleSettings += @("- Deletion policy: $(($SiteRole.Props | ? { $_.PropertyName -eq "SMPStoreDeletionCycleTimeInMinutes" }).Value) minutes")
            }
            If (($SiteRole.Props | ? { $_.PropertyName -eq "SMPQuiesceState" }).Value -eq 1) {
                $RoleSettings += @("- Enable restore-only mode - CHECKED")
            }
            Else {
                $RoleSettings += @("- Enable restore-only mode - UNCHECKED")
            }
        }
        #endregion RoleSMP
        <#
        TODO
            Certificate registration point
        #>
        Default {
            $RoleName = $SiteRole.RoleName
            $RoleSettings += @("No data available")
        }
    }
    $SiteRoleobject = New-Object -TypeName PSObject -Property @{'Server Name' = ($SiteRole.NALPath).ToString().Split('\\')[2]; 'Role' = $RoleName; 'Properties' = ($RoleSettings -join '--CRLF--')}
    $SiteRolesTable += $SiteRoleobject
  }
  $SiteRolesTable = $SiteRolesTable | Sort-Object -Property 'Server Name', 'Role' | Select 'Server Name', 'Role', 'Properties'
}else{
  $SiteRolesTable = @()  
  $SiteRoles = Get-CMSiteRole -SiteCode $SiteCode | Select-Object -Property NALPath, rolename

  foreach ($SiteRole in $SiteRoles) {
    if (-not (($SiteRole.rolename -eq 'SMS Component Server') -or ($SiteRole.rolename -eq 'SMS Site System'))) {
        $SiteRoleobject = New-Object -TypeName PSObject -Property @{'Server Name' = ($SiteRole.NALPath).ToString().Split('\\')[2]; 'Role' = $SiteRole.RoleName}
        $SiteRolesTable += $SiteRoleobject
    }
  }
}
$SiteRolesTable|export-csv $dir\sccmservrolelist.csv -NoTypeInformation
