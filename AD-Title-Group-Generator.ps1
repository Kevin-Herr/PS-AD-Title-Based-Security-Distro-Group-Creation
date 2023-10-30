###
# Active Directory Title Based Distribution and Security Group Creation (Script will also add users to the appropriate Security Groups)
#    Note 1: Adjust the "ForEach ($user in $users) {" section to your needs, the max length of a name for a group is 63 characters.
#    Note 2: There are more snippets at the end to bulk update visibility in the GAL, Enable Distros, or Adjust Send As Permissions.

$EmployeesOU = "OU=Employees,DC=contoso,DC=com"
$EmployeesOUExclusion = "*OU=Contractors*"

$HideDistributionsFromGAL = $True

$DistributionGroupOU = "OU=Distribution Groups,DC=contoso,DC=com"
$SecurityGroupOU = "OU=Security Groups,DC=contoso,DC=com"

$users = get-aduser -Filter * -SearchBase $EmployeesOU -Properties Name,Description,LastLogon,DistinguishedName,SamAccountName| where {$_.Enabled -eq $True} | Where-Object {$_.DistinguishedName -notlike $EmployeesOUExclusion} | Select Name,Description,SamAccountName,@{N='LastLogon';E={[DateTime]::FromFileTime($_.LastLogon)}}

# Preparing/Clearing the array for new titles.
$titles = @()

ForEach ($user in $users) {
    # Cleaning Titles of Special Characters
    $TitleCleaned = $user.Description -Replace '[^a-zA-Z0-9 ]', ''
    $TitleCleaned = $TitleCleaned -Replace '\s{2,}', ' '
    # Shortening Titles to Ensure Creation as there is a 63 character length limit
    $TitleCleaned = $TitleCleaned.replace('Contact Center','CC')
    $TitleCleaned = $TitleCleaned.replace('Senior','Sr')
    $TitleCleaned = $TitleCleaned.replace('Manager','Mgr')
    $TitleCleaned = $TitleCleaned.replace('Junior','Jr')
    $TitleCleaned = $TitleCleaned.replace('Project Management','PM')
    $TitleCleaned = $TitleCleaned.replace('Database Administrator','DBA')
    $TitleCleaned = $TitleCleaned.replace('Operations','Ops')
    $TitleCleaned = $TitleCleaned.replace('Director','Dir')
    $TitleCleaned = $TitleCleaned.replace('Supervisor','Sup')
    $TitleCleaned = $TitleCleaned.replace('Administrator','Admin')
    $TitleCleaned = $TitleCleaned.replace('Administrative','Admin')
    $TitleCleaned = $TitleCleaned.replace('Education','Edu')
    $TitleCleaned = $TitleCleaned.replace('Organizational','Org')
    $TitleCleaned = $TitleCleaned.replace('Communications','Comms')
    $TitleCleaned = $TitleCleaned.replace('Community','Comm')
    $TitleCleaned = $TitleCleaned.replace('Development','Dev')
    $TitleCleaned = $TitleCleaned.replace('Coordinator','Coord')
    $TitleCleaned = $TitleCleaned.replace('Quality','Qual')
    
    $TitleDistro = 'Role ' + $TitleCleaned + ' Distro'
    
    $TitleDistroNoSpace = $TitleDistro -Replace '[^a-zA-Z0-9]', ''
    $TitleDistroEmail = $TitleDistroNoSpace + '@crisisnetwork.org'

    $TitleRole = 'Role ' + $TitleCleaned + ' Security'
    $TitleRoleNoSpace = $TitleRole -Replace '[^a-zA-Z0-9]', ''
    
    write-output $TitleDistroNoSpace
    write-output $TitleDistroEmail
    write-output $TitleRoleNoSpace


    if ($titles -contains $TitleCleaned) {
        Write-Output "Title Exists in Array"
    } else {
        Write-Output "New Title"
        write-output $user.Description
        $titles += $TitleCleaned

        # Preparing Distro
        $loadgroup = get-adgroup -filter * | where {$_.SamAccountName -eq $TitleDistroNoSpace}
        if ($loadgroup -eq $null) {
            write-output $TitleDistro + '... does not exist. Creating now...'
            new-adgroup -Name $TitleDistro -SamAccountName $TitleDistroNoSpace -GroupCategory Distribution -GroupScope Global -DisplayName $TitleDistro -Path $DistributionGroupOU
            Enable-DistributionGroup -Identity $TitleDistro
            Get-DistributionGroup $distro.SamAccountName | Set-DistributionGroup -HiddenFromAddressListsEnabled:$HideDistributionsFromGAL
        } else {
            write-output $TitleDistro + '... exists.'
        }

        $mailtest = get-adgroup -Filter * | Where {$_.SamAccountName -eq $TitleDistroNoSpace} | Select mail
        if ($mailtest.mail -eq $null) {
            write-output $TitleDistroEmail + " has an Empty Email Address, Updating..."
            Get-ADGroup -Filter * | where {$_.SamAccountName -eq $TitleDistroNoSpace} | set-adgroup -Replace @{mail=$TitleDistroEmail}
        }

        # Preparing Security
        $loadgroup = get-adgroup -filter * | where {$_.SamAccountName -eq $TitleRoleNoSpace}
        if ($loadgroup -eq $null) {
            write-output $TitleRole + '... does not exist. Creating now...'
            new-adgroup -Name $TitleRole -SamAccountName $TitleRoleNoSpace -GroupCategory Security -GroupScope Global -DisplayName $TitleRole -Path $SecurityGroupOU
        } else {
            write-output $TitleRole + '... exists.'
        }
    }

    # Add current user to correct Groups
    Add-ADGroupMember -Identity $TitleRoleNoSpace -Members $user.SamAccountName
    Add-ADGroupMember -Identity $TitleDistroNoSpace -Members $user.SamAccountName
}

Write-Output $titles


###############
####Use Below Code to Enable Distros

#$Distros = get-adgroup -filter * -SearchBase $DistributionGroupOU
#for ($distro in $Distros) {
#	Enable-DistributionGroup -Identity $distro.SamAccountName
#}

###############
####Use Below Code to Modify Send Permissions to Distros

#$Distros = get-adgroup -filter * -SearchBase $DistributionGroupOU
#foreach ($distro in $Distros) {
#	Set-DistributionGroup $distro.SamAccountName -AcceptMessagesOnlyFrom 'contoso.com/Employees/John Doe','contoso.com/Employees/Jane Doe'
#}

###############
####Use Below Code to Hide Distribution Groups from GAL

#$Distros = get-adgroup -filter * -SearchBase $DistributionGroupOU
#foreach ($distro in $Distros) {
#	Get-DistributionGroup $distro.SamAccountName | Set-DistributionGroup -HiddenFromAddressListsEnabled:$true
#}
