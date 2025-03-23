#Script um einen neuen AD User zu erstellen mit den den Parametern die eingegeben werden

#Parameter kommen vom User 
param(
    [Parameter(Mandatory=$true)]
    [string]$FirstName,

    [Parameter(Mandatory=$true)]
    [string]$LastName,

    [Parameter(Mandatory=$true)]
    [string]$UserName,

    [Parameter(Mandatory=$true)]
    [string]$OU,

    [Parameter(Mandatory=$true)]
    [string]$Domain
)


#Call to New-ADUser um AD User zu erstellen (cmdlet)
New-ADUser `
    -SamAccountName $UserName `
    -UserPrincipalName "$Username@Domain" `
    -Name "$FirstName $LastName" `
    -GivenName $FirstName `
    -Surname $LastName `
    -AccountPassword $SecurePassword `
    -Enabled $true `
    -Path "OU = $OU, DC = LAB, DC = local" `
    -PasswordNeverExpires $false `
    -ChangePasswordAtLogon $true
