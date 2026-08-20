$Source = "$env:APPDATA\Code\User"
$Target = "$env:ONEDRIVE\Backup\VSCode"

robocopy $Source $Target /MIR /R:1 /W:1