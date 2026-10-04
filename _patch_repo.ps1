$ErrorActionPreference = 'Stop'
$BSLASH_N = [char]92 + 'n'

$f2 = 'd:\KrishiAi-main\lib\data\repositories\ai_repository.dart'
$c = Get-Content -Raw -Path $f2

# Normalize trailing whitespace on lines containing $st'); and the next analyzeImagePlaceholder line.
$c = [regex]::Replace($c, "(`$st'\);)\s+(\r?\n)", '$1$2')
$c = [regex]::Replace($c, "(\banalyzeImagePlaceholder\(cropName: cropName, notes: notes\);)\s+(\r?\n)", '$1$2')

$oldMethod = "  Future<Diagnosis> analyzeImageWithModel({" + "`n" +
    "    required String cropName," + "`n" +
    "    String? imagePath," + "`n" +
    "    String? notes," + "`n" +
    "  }) async {" + "`n" +
    "    final api = DiseaseApiService();" + "`n" +
    "    try {" + "`n" +
    "      if (imagePath != null && imagePath.isNotEmpty) {" + "`n" +
    "        final file = File(imagePath);" + "`n" +
    "        if (await file.exists()) {" + "`n" +
    "          final result = await api.predictImage(file);" + "`n" +
    "          return _mapResultToDiagnosis(" + "`n" +
    "            cropName: cropName," + "`n" +
    "            notes: notes," + "`n" +
    "            result: result," + "`n" +
    "          );" + "`n" +
    "        }" + "`n" +
    "      }" + "`n" +
    "      // No image provided -> use the existing library fallback." + "`n" +
    "      return analyzeImagePlaceholder(cropName: cropName, notes: notes);" + "`n" +
    "    } catch (e, st) {" + "`n" +
    "      if (kDebugMode) {" + "`n" +
    "        debugPrint('[AIRepository] /predict failed, falling back: `$e" + $BSLASH_N + "`$st');" + "`n" +
    "      }" + "`n" +
    "      return analyzeImagePlaceholder(cropName: cropName, notes: notes);" + "`n" +
    "    } finally {" + "`n" +
    "      api.dispose();" + "`n" +
    "    }" + "`n" +
    "  }"

if (-not $c.Contains($oldMethod)) {
    Write-Host 'OLD METHOD STILL NOT FOUND'
    exit 1
}

$newMethod = "  Future<DiseaseInferenceResult?> analyzeImageWithModel({" + "`n" +
    "    required String cropName," + "`n" +
    "    String? imagePath," + "`n" +
    "    String? notes," + "`n" +
    "  }) async {" + "`n" +
    "    final api = DiseaseApiService();" + "`n" +
    "    try {" + "`n" +
    "      if (imagePath != null && imagePath.isNotEmpty) {" + "`n" +
    "        final file = File(imagePath);" + "`n" +
    "        if (await file.exists()) {" + "`n" +
    "          final result = await api.predictImage(file);" + "`n" +
    "          if (kDebugMode) {" + "`n" +
    "            debugPrint(" + "`n" +
    "              '[AIRepository] /predict ok top1=' +" + "`n" +
    "                  (result.topK.isNotEmpty ? result.topK.first.label : '-') +" + "`n" +
    "                  ' inferenceMs=' +" + "`n" +
    "                  result.inferenceMs.toString()," + "`n" +
    "            );" + "`n" +
    "          }" + "`n" +
    "          return result;" + "`n" +
    "        }" + "`n" +
    "      }" + "`n" +
    "      return null;" + "`n" +
    "    } catch (e, st) {" + "`n" +
    "      if (kDebugMode) {" + "`n" +
    "        debugPrint('[AIRepository] /predict failed, falling back: `$e" + $BSLASH_N + "`$st');" + "`n" +
    "      }" + "`n" +
    "      return null;" + "`n" +
    "    } finally {" + "`n" +
    "      api.dispose();" + "`n" +
    "    }" + "`n" +
    "  }" + "`n" +
    "" + "`n" +
    "  /// Builds a [Diagnosis] from a [DiseaseInferenceResult]. When the result" + "`n" +
    "  /// has no top-K entries, falls back to the library-based advisor." + "`n" +
    "  Future<Diagnosis> diagnosisFromInference({" + "`n" +
    "    required String cropName," + "`n" +
    "    required DiseaseInferenceResult result," + "`n" +
    "    String? notes," + "`n" +
    "  }) async {" + "`n" +
    "    return _mapResultToDiagnosis(" + "`n" +
    "      cropName: cropName," + "`n" +
    "      notes: notes," + "`n" +
    "      result: result," + "`n" +
    "    );" + "`n" +
    "  }"

$c = $c.Replace($oldMethod, $newMethod)

# Make _mapResultToDiagnosis async
$oldSig = "  Diagnosis _mapResultToDiagnosis({"
if (-not $c.Contains($oldSig)) { Write-Host 'OLD SIG NOT FOUND'; exit 1 }
$c = $c.Replace($oldSig, "  Future<Diagnosis> _mapResultToDiagnosis({")

Set-Content -NoNewline -Encoding UTF8 -Path $f2 -Value $c
Write-Host 'OK ai_repository.dart'
