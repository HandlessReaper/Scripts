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


#Random Passwort generieren
#0-9, a-z, A-Z als ASCII -> in Char umwandeln -> 12 Zeichen zufällig auswählen
$Password = -join((0x30..0x39)+(0x41..0x5A)+(0x61..0x7A) | Get-Random -Count 12 | ForEach-Object {[char]$_})
Write-Host "Password wurde generiert: $Password"

#encrypten des Passworts 
$SecurePassword = ($Password | ConvertTo-SecureString -AsPlainText -Force)

#Call zu New-ADUser um AD User zu erstellen (cmdlet)
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
