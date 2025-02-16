
$Communities = @("","")  #Account Type
$Division = ""  #Division
$SaveLOC = ""  #SavePoint
$BatchSize = 100  # Define the batch size
 
# Iterate through communities
foreach ($UserType in $Communities) {
    $Users = Get-AdGroupMember -Identity "G-$($DIVision)-ALL Users-$Usertype"
    $TotalUsers = $Users.Count
    $ProcessedUsers = 0
 
    # Process users in batches
    for ($i = 0; $i -lt $TotalUsers; $i += $BatchSize) {
        $Batch = $Users | Select-Object -Skip $i -First $BatchSize
 
        # Create a hashtable to store results for the batch
        $BatchResults = @{}
 
        # Process each user in the batch
        foreach ($User in $Batch) {
            $Groups = Get-ADPrincipalGroupMembership $User | Select-Object -ExpandProperty Name
            $BatchResults[$User.SamAccountName] = $Groups
            $ProcessedUsers++
        }
 
        # Write results for the batch
        foreach ($UserSam in $BatchResults.Keys) {
            $BatchResults[$UserSam] | Out-File "$SaveLOC\$UserSam.txt"
        }
 
        # Display progress
        Write-Progress -Activity "Processing Users" -Status "Progress" -PercentComplete (($ProcessedUsers / $TotalUsers) * 100)
    }
}
