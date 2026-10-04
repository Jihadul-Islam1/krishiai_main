$path = 'd:\KrishiAi-main\lib\presentation\screens\ai\crop_doctor_screen.dart'
$enc = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($path, $enc)
$NL = "`n"
$old = "import '../../../core/network/disease_api_service.dart';" + $NL + "import '../../../core/network/disease_api_service.dart';" + $NL + "import '../../providers/app_providers.dart';"
$new = "import '../../../core/network/disease_api_service.dart';" + $NL + "import '../../providers/app_providers.dart';"
if ($text.Contains($old)) {
  $text = $text.Replace($old, $new)
  Write-Host 'dedup OK'
} else {
  Write-Host 'dedup MISS'
}
[System.IO.File]::WriteAllText($path, $text, $enc)
Write-Host ('final len=' + $text.Length)