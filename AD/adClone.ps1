# Quick script to clone an user user. 

$jsonObject = @(
    @{
        "OLDSAM" = ""
        "NEWSAM" = ""
        "Type" = ""
    }
)
 
# Replace with your Administrative OU
$AdminOU = "OU=Administrators,OU=$DIVISION,DC=com"
 
foreach ($item in $jsonObject) {
    $prev = Get-ADUser $item.OldSam -Properties Manager, Division, MemberOf
 
    $newUserParams = @{
        SamAccountName = $item.NEWSAM
        Enabled = $false
        Manager = $prev.Manager
        DisplayName = "$($item.NEWSAM) (SA)"
        Division = $prev.Division
        UserPrincipalName = "$($item.NEWSAM)@assaabloy.com"
        Path = $AdminOU
        Name = $item.NEWSAM
    }
 
    New-ADUser @newUserParams
    Set-ADUser $item.NEWSAM -Replace @{EmployeeType = $item.Type}
 
    # Add user to groups
    Add-ADPrincipalGroupMembership -Identity $item.NEWSAM -MemberOf $prev.MemberOf
}

