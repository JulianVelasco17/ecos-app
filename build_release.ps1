$current = (Select-String '^version:' pubspec.yaml).Line -replace 'version: ', ''
$name  = $current.Split('+')[0]
$build = [int]$current.Split('+')[1]
$new   = "$name+$($build + 1)"

(Get-Content pubspec.yaml) -replace "^version: .*", "version: $new" | Set-Content pubspec.yaml

Write-Host "Versión: $current -> $new"

flutter build appbundle --release
