$ErrorActionPreference = 'Stop'
$f = 'd:\KrishiAi-main\lib\data\repositories\ai_repository.dart'
$c = Get-Content -Raw -Path $f

# Make _mapResultToDiagnosis async (it now needs to be Future<Diagnosis>).
$oldSig = "  Future<Diagnosis> _mapResultToDiagnosis({" + "`n" +
    "    required String cropName," + "`n" +
    "    required DiseaseInferenceResult result," + "`n" +
    "    String? notes," + "`n" +
    "  }) {"
$newSig = "  Future<Diagnosis> _mapResultToDiagnosis({" + "`n" +
    "    required String cropName," + "`n" +
    "    required DiseaseInferenceResult result," + "`n" +
    "    String? notes," + "`n" +
    "  }) async {"
if (-not $c.Contains($oldSig)) { Write-Host 'SIG NOT FOUND'; exit 1 }
$c = $c.Replace($oldSig, $newSig)

# Wrap the top-K branch return in await so the Future<Diagnosis> type matches.
$oldRet = "    return Diagnosis("
if (-not $c.Contains($oldRet)) { Write-Host 'RETURN NOT FOUND'; exit 1 }
# Replace only the first occurrence inside _mapResultToDiagnosis (the one that follows toStrs).
# To be safe, replace the unique occurrence: the line directly after "      return const [];" + blank line.
$marker = "      return const [];" + "`n" +
    "    }" + "`n" +
    "" + "`n" +
    "    return Diagnosis("
$newMarker = "      return const [];" + "`n" +
    "    }" + "`n" +
    "" + "`n" +
    "    return Future<Diagnosis>.value(Diagnosis("
# Find and replace end-of-function closing too. The Diagnosis(...) is multi-line, ends with '    );'.
$c = $c.Replace($marker, $newMarker)
# Now append the closing for Future.value: change the LAST '    );' inside the body before the function closes.
# We do this by replacing the very specific sequence after our marker.
# The body closing pattern: "...      notes: notes,\n    );\n  }\n\n  Future<AIConversation> loadConversation() async {"
$endMarker = "      notes: notes," + "`n" +
    "    );" + "`n" +
    "  }" + "`n" +
    "" + "`n" +
    "  Future<AIConversation> loadConversation() async {"
$endReplace = "      notes: notes," + "`n" +
    "    ));}" + "`n" +
    "" + "`n" +
    "  Future<AIConversation> loadConversation() async {"
if (-not $c.Contains($endMarker)) {
    Write-Host 'END MARKER NOT FOUND - showing snippet around end of _mapResultToDiagnosis:'
    $idx = $c.IndexOf("_mapResultToDiagnosis")
    Write-Host $c.Substring($idx, 1200)
    exit 1
}
$c = $c.Replace($endMarker, $endReplace)

Set-Content -NoNewline -Encoding UTF8 -Path $f -Value $c
Write-Host 'OK _mapResultToDiagnosis wrapped'
