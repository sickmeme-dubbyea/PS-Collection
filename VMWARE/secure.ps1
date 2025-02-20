# USER configuratable settings
$DEBUG = $False
 
$EsxiHostsPath = "C:\_loosefiles\alberto\VMWARE"
$DDI = [pscustomobject]@{
    DNS = "IP1", "IP2", "IP3"
    NTP = "<<address>>"
}
 
$SYSLOG_PROTOCOL = "<<protocol>>"
$SYSLOG_HOST = "<<address>>"
$SYSLOG_PORT = "<<port>>"
 
#####
#      
#       No touchie
#
#####
 
Import-module vmware.powercli
 
$SYSLOG = "$($SYSLOG_PROTOCOL)://$($SYSLOG_HOST):$($SYSLOG_PORT)"
 
# Load up all the CSV files in the directory for environments to change
$CSVS = Get-ChildItem -path $EsxiHostsPath  | ? { $_.Extension -eq ".csv" }
 
# Ignore invalid certificates
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false
<#
 
# If debug is enabled, then we will not actually make any changes, just report what we would do.
if ($DEBUG) {
    $WhatIfPreference = $true
}
else {
    $WhatIfPreference = $false
} #>
# Get the CSV files
 
function Write-Log {
    param (
        [string]$Message,
        [string]$LogFile = "$EsxiHostsPath\Secure-ESXI-log.txt"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] - $Message"
    Add-Content -Path $LogFile -Value $logMessage
}
function Set-SecureESXiHost {
    param (
        $theHost
    )
 
    <#
    This should be made more dynamic, but for now, we will just do the following.
    Later on make this read from a JSON file and loop the necessary actions to secure the host.
 
    Action required as of 2/20/2025
   
    [-] Validate NTP
    [x] Assign DNS to AA
    [x] Configure syslog
    [x] Turn of SSH at boot
    [x] Turn off ESXi Shell at boot
    [x] Set ExecInstalledOnly to true
   
#>
 
    try {
        # DNS
        Get-VMHOST $theHost | Get-VMHOSTNETWORK |  Set-VMHostNetwork -DnsAddress $DDI.DNS -Confirm:$false
        Write-Log -Message "DNS settings updated for host $(Get-VMHOST $theHost.Name)"
       
        # SYSLOG
        Get-VMHOST $theHost  | Get-advancedsetting -Name Syslog.global.logHost | Set-AdvancedSetting -Value $SYSLOG -confirm:$FALSE
        Write-Log -Message "Syslog settings updated for host $(Get-VMHOST $theHost.Name)"
       
        # Exec Installed Only
        Get-VMHOST $theHost  | Get-AdvancedSetting -Name VMkernel.Boot.execInstalledOnly | Set-AdvancedSetting -Value $True -confirm:$FALSE
        Write-Log -Message "ExecInstalledOnly setting updated for host $(Get-VMHOST $theHost.Name)"
       
        # NTP
           
        <#
                Getting unnecessarily complicated for no reason.
 
                #Remove-VMHostNtpServer -VMHost $theHost.Name -Confirm:$false
                try {
                    Get-VMHOST $theHost | Get-VMHOSTNTPSERVER | Remove-VMHostNtpServer -NtpServer $_ -Confirm:$false
                }
                catch {
                    Write-Host "Error removing NTP server on -> $(thehost.Name)"
                }
 
                for ($i=0; $i -le $DDI.NTP.Count; $i++) {
                    Add-VMHostNtpServer -NtpServer $DDI.NTP[$i] -VMHost $theHost -Confirm:$false
                }
       
        Get-VMHOST $theHost  | Get-VMHostService | Where-Object { $_.Key -eq "ntpd" } | Stop-VMHostService -confirm:$false
        Get-VMHOST $theHost  | Get-VMHostService | Where-Object { $_.Key -eq "ntpd" } | Start-VMHostService -confirm:$false
        Write-Log -Message "NTP settings updated for host $(Get-VMHOST $theHost.Name)"
        #>
       
        # SSH
        Get-VMHOST $theHost  | Get-VMHostService | Where-Object { $_.Key -eq "TSM-SSH" } | Stop-VMHostService  -confirm:$false
        Get-VMHOST $theHost  | Get-VMHostService | Where-Object { $_.Key -eq "TSM-SSH" } | Set-VMHostService -Policy Off -Confirm:$false
 
        #ESXI SHELL
        Get-VMHost $theHost | Get-VMHostService | Where-Object { $_.Label -eq "ESXi Shell" } | Stop-VMHostService  -confirm:$false
        Get-VMHost $theHost | Get-VMHostService | Where-Object { $_.Label -eq "ESXi Shell" } | Set-VMHostService -Policy Off -Confirm:$false
        Write-Log -Message "SSH service stopped for host $(Get-VMHOST $theHost.Name)"
       
        return $true
    }
    catch {
        Write-Host $($_.Exception.Message)
        Write-Log -Message "Error securing host $(Get-VMHOST $theHost.Name): $($_.Exception.Message)"
        return $false
    }
}
 
foreach ($CSV in $CSVs) {
    $ORG = Import-csv $CSV.FullName
 
    # Get the hosts in the CSV
    foreach ($esxiHost in $ORG) {
        # Determine the host type and connect
        try {
            # Determine what we have. This may not really be needed, but lets continue on this path for now,.
            switch ($esxiHost.Type) {
                "esxi" {
                    $this_Host = Connect-VIServer -Server $esxiHost.IP -User $esxiHost.User -Pass $esxiHost.Pass
                    Write-Host $esxiHost.ip
                    Set-SecureESXiHost -theHost $this_Host
                }
                "vCenter" {
                    Connect-VIServer -Server $esxiHost.IP -User $esxiHost.User -Pass $esxiHost.Pass
                    $Clusters = Get-Cluster
                    $sxiHosts = $Clusters | Get-VMHost
 
                    foreach ($subsxiHost in $sxiHosts) {
                        Set-SecureESXiHost -theHost $subsxiHost
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
 
