<# Charles Witherspoon
 
Description: Performs bulk password resets from users in "today.txt" file. Based on requirements from SECOPS / SOC departments. 
Utalizes sourceType variable to flip from "samaccountname","UserPrincipalName", or etc to provide the necessary property in AD. 
 
v.03
 
Prerequsites: 
- The account running the script will need to have send on behalf of permissions from 
- You will need access to active directory from some account (RSAT tools)
 
Instruction:
 
1) Change the variable 'sourceType' after determining what type of data do you have. Are you given Mail, SAMACCOUNTNAMES, or UserPrincipalNames. Please update this value accordingly. 
2) Create a file titled "today.txt" with your data in the same directory as the downloaded script. Assign one "account type" per line in your text file. 
3) You may change the BCC line to determine if mails were sent / recieved. 
4) Run the powershell file from a machine with RSAT tools installed on it. If running this from a client computer, you will need to run the script as your SA account.
 
#>
 
Import-module activedirectory
 
# Global Setup
$paramVars = @{
    Visibility = "Public"
    Scope      = "Global"
    Force      = $TRUE
    Verbose    = $FALSE
}
 
# Variables
 
#Script Setup
New-Variable -name 'rootPath' -Value (Get-Item $PSScriptRoot).FullName @paramVars
 
#Script Specifics
New-Variable -name 'pwChangeStatus' -value $TRUE @paramVars
New-Variable -name 'pw0n3dAccountsFile' -Value "$rootPath\today.txt" @paramVars
 
New-Variable -Name 'sourceType' -Value "mail" @paramVars #Options are samaccountname,userprincipalname,mail
 
$pw0n3dAccounts = Get-Content $pw0n3dAccountsFile
 
#Mail Section
New-Variable -name 'RELAY' -Value "relayauth.assaabloy.net" @paramVars
 
# Redacted
 
New-Variable -Name 'DomainController' -Value "usnewsdcglob001.ad.global" @paramVars
 
function Get-HTMLBody {
    param(
        [parameter(position = 0, mandatory = $TRUE)][string]$Manager,
        [parameter(position = 1, mandatory = $TRUE)][string]$Employee)
 
    $_HTMLBODY = @" 
 
<H2>Security Incident</H2>
Hi {MANAGER}, 
</br>
</br>
You are receiving this email due to an ongoing security incident that the divisional team was alerted to.</br>
To protect the company's assets, the user account for "{EMPLOYEE}" was reset.</br>
</br>
Please inform your employee by the necessary communication that their account will require a password change upon next login. </br>
If you have any questions or concerns, please contact your local helpdesk. 
 
</br>
</br>
Respectfully,</br> 

"@
 
    return $_HTMLBODY -replace "{MANAGER}", $Manager -replace "{EMPLOYEE}", $Employee
}
 
foreach ($pw0nedAccount in $pw0n3dAccounts) {
    #$ifAccount = $pw0nedAccount.Substring(3,($pw0nedAccount.Length-3))
    $ifAccount = $pw0nedAccount
    if (Get-aduser -filter { $sourceType -eq $ifAccount }) {
        $currAcctObj = Get-aduser -filter { $sourceType -eq $ifAccount } -Properties Manager
        Write-host $currAcctObj
        
        Set-aduser -Identity $currAcctObj -ChangePasswordAtLogon $pwChangeStatus -Server $DomainController
       
        $managerObj = (Get-aduser $currAcctObj.Manager -Properties mail) 
      
        $MailData = @{
            From       = "do.not.reply@assaabloy.com"
            Subject    = "Security Incident for your employee: {0} {1}" -f $currAcctObj.GivenName, $currAcctObj.Surname
            To         = $managerObj.mail             
            Body       = Get-HTMLBody -Manager $managerObj.GivenName -Employee $("{0} {1}" -f $currAcctObj.GivenName, $currAcctObj.surname)
            BodyAsHtml = $TRUE
            Port       = "25"
            SmtpServer = $Relay
            BCC        = ""
        }
        Send-MailMessage @MailData 
        sleep 3
    }
 
}
