$p = "d:\KrishiAi-main\lib\data\repositories\ai_repository.dart"
$methodsPath = "d:\KrishiAi-main\_methods.txt"

$text = [System.IO.File]::ReadAllText($p)
$methods = [System.IO.File]::ReadAllText($methodsPath)

if ($text.Contains("analyzeImageWithModel")) {
  Write-Host "methods already present"
  exit
}

# Inject right before the `loadConversation` method (the seam between
# image analysis and chat persistence).
$marker = "  Future<AIConversation> loadConversation() async {"
if (-not $text.Contains($marker)) {
  Write-Host "ERROR: marker not found"
  exit 1
}

$replacement = $methods + $marker
$text = $text.Replace($marker, $replacement)
[System.IO.File]::WriteAllText($p, $text, [System.Text.Encoding]::UTF8)
Write-Host "injected methods"