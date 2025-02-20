# USER configuratable settings
$DEBUG = $true
 
$EsxiHostsPath = ""
$DDI = [pscustomobject]@{
    DNS = ""
    NTP = ""
}
 
$SYSLOG_PROTOCOL = ""
$SYSLOG_HOST = ""
$SYSLOG_PORT = ""
 
#####
#       No touchie
#####
Import-module vmware.powercli
 
$SYSLOG = "$($SYSLOG_PROTOCOL)://$($SYSLOG_HOST):$($SYSLOG_PORT)"
 
# Load up all the CSV files in the directory for environments to change
$CSV = Get-files -path $EsxiHostsPath -include *.CSV
 
# Ignore invalid certificates
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
 
# If debug is enabled, then we will not actually make any changes, just report what we would do.
if ($DEBUG) {
    $WhatIfPreference = $true
}
else {
    $WhatIfPreference = $false
}
 
# Get the CSV files
foreach ($CSV in $CSVs) {
    $ORG = Import-csv $CSV
 
    # Get the hosts in the CSV
    foreach ($host in $ORG) {
        # Determine the host type and connect
        try {
            # Determine what we have. This may not really be needed, but lets continue on this path for now,.
            switch ($host.Type) {
                "ESXi" {
                    $this_Host = Connect-VIServer -Server $host.Hostname -User $host.Username -Password $host.Password
                    SecureESXi-Host -theHost $this_Host
                }
                "vCenter" {
                    Connect-VIServer -Server $host.Hostname -User $host.Username -Password $host.Password
                    $Clusters = Get-Cluster
                    $sxiHosts = $Clusters | Get-VMHost
 
                    foreach ($sxiHost in $sxiHosts) {
                        SecureESXi-Host -theHost $sxiHost
                    }
 
                    SecureVcenter-Host -theHost
                   
                }
                default {
                    Write-Host "Unknown host type"
                }
            }
        }
        catch {
            Write-Host $_.Exception.Message
        }
        # Run the same set of commands on each host
        Disconnect-VIServer -Server * -Confirm:$false -Force:$true
    }
}
 
 
 
function Write-Log {
    param (
        [string]$Message,
        [string]$LogFile = "$EsxiHostsPath\Secure-ESXI-log.txt"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] - $Message"
    Add-Content -Path $LogFile -Value $logMessage
}
 
function SecureESXi-Host {
    param (
        $theHost
    )
 
    <#
    This should be made more dynamic, but for now, we will just do the following.
    Later on make this read from a JSON file and loop the necessary actions to secure the host.
 
    Action required as of 2/20/2025
   
    [x] Validate NTP
    [x] Validate DNS
    [x] Configure syslog
    [x] Turn of SSH at boot
#>
 
    try {
        # DNS
        $theHost | Set-VMHostNetwork -DomainName $DDI.DNS -Confirm:$false
        Write-Log -Message "DNS settings updated for host $($theHost.Name)"
       
        # SYSLOG
        $thehost | Get-advancedsetting -Name Syslog.global.logHost | Set-AdvancedSetting -Value $SYSLOG
        Write-Log -Message "Syslog settings updated for host $($theHost.Name)"
       
        # Exec Installed Only
        $theHost | Get-AdvancedSetting -Name VMkernel.Boot.execInstalledOnly | Set-AdvancedSetting -Value $True
        Write-Log -Message "ExecInstalledOnly setting updated for host $($theHost.Name)"
       
        # NTP
        $theHost | Set-VMHostNTPServer -NtpServer $DDI.NTP -Confirm:$false
        $theHost | Get-VMHostService | Where-Object { $_.Key -eq "ntpd" } | Stop-VMHostService
        $theHost | Get-VMHostService | Where-Object { $_.Key -eq "ntpd" } | Start-VMHostService
        Write-Log -Message "NTP settings updated for host $($theHost.Name)"
       
        # SSH
        $theHost | Get-VMHostService | Where-Object { $_.Key -eq "TSM-SSH" } | Stop-VMHostService
        $theHost | Get-VMHostService | Where-Object  { $_.Key -eq "TSM-SSH" } | Set-VMHostService -Policy Off -Confirm:$false
        Write-Log -Message "SSH service stopped for host $($theHost.Name)"
       
        return $true
    }
    catch {
        Write-Log -Message "Error securing host $($theHost.Name): $($_.Exception.Message)"
        return $false
    }
}
