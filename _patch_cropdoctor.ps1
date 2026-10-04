$ErrorActionPreference = 'Stop'

function Apply-LF([string]$path, [string]$old, [string]$new) {
    $c = Get-Content -Raw -Path $path
    if (-not $c.Contains($old)) {
        Write-Host ("NOT FOUND in " + $path + ":")
        Write-Host '-----OLD-----'
        Write-Host $old
        Write-Host '-----END-----'
        exit 1
    }
    Set-Content -NoNewline -Encoding UTF8 -Path $path -Value ($c.Replace($old, $new))
}

# 1) crop_doctor_screen.dart imports
$f1 = 'd:\KrishiAi-main\lib\presentation\screens\ai\crop_doctor_screen.dart'
$oldImports = "import '../../../core/network/disease_api_service.dart';`nimport '../../../core/network/disease_api_service.dart';`nimport '../../providers/app_providers.dart';"
$newImports = "import '../../../core/network/disease_api_service.dart';`nimport '../../../data/models/diagnosis.dart';`nimport '../../providers/app_providers.dart';`nimport 'scan_result_screen.dart'; // for TopPrediction"
Apply-LF $f1 $oldImports $newImports

# 2) crop_doctor_screen.dart analyze block
$oldAnalyze = "    DiseaseInferenceResult? backend;`n    Diagnosis diag;`n    bool backendOffline = true;`n    if (_imagePath != null) {`n      try {`n        backend = await repo.analyzeImageWithModel(`n          imagePath: _imagePath!,`n          cropName: _selectedCropName!,`n          notes: notesArg,`n        );`n      } catch (_) {`n        backend = null;`n      }`n    }`n    if (backend != null) {`n      diag = await repo.analyzeImagePlaceholder(`n        cropName: _selectedCropName!,`n        notes: notesArg,`n      );`n    } else {`n      diag = await repo.analyzeImagePlaceholder(`n        cropName: _selectedCropName!,`n        notes: notesArg,`n      );`n    }"
$newAnalyze = "    DiseaseInferenceResult? inference;`n    final Diagnosis diag;`n    bool backendOffline = true;`n    if (_imagePath != null) {`n      try {`n        inference = await repo.analyzeImageWithModel(`n          imagePath: _imagePath!,`n          cropName: _selectedCropName!,`n          notes: notesArg,`n        );`n      } catch (_) {`n        inference = null;`n      }`n    }`n    if (inference != null) {`n      backendOffline = false;`n      diag = await repo.diagnosisFromInference(`n        cropName: _selectedCropName!,`n        notes: notesArg,`n        result: inference!,`n      );`n    } else {`n      diag = await repo.analyzeImagePlaceholder(`n        cropName: _selectedCropName!,`n        notes: notesArg,`n      );`n    }"
Apply-LF $f1 $oldAnalyze $newAnalyze

# 3) crop_doctor_screen.dart extras
$c1 = Get-Content -Raw -Path $f1
$c1 = $c1.Replace("'inferenceMs': backend?.inferenceMs,", "'inferenceMs': inference?.inferenceMs,")
$c1 = $c1.Replace("'topK': backend?.topK", "'topK': inference?.topK")
Set-Content -NoNewline -Encoding UTF8 -Path $f1 -Value $c1
Write-Host 'OK crop_doctor_screen.dart'

# 4) ai_repository.dart: change analyzeImageWithModel signature/body
$f2 = 'd:\KrishiAi-main\lib\data\repositories\ai_repository.dart'
$oldMethod = "  Future<Diagnosis> analyzeImageWithModel({`n    required String cropName,`n    String? imagePath,`n    String? notes,`n  }) async {`n    final api = DiseaseApiService();`n    try {`n      if (imagePath != null && imagePath.isNotEmpty) {`n        final file = File(imagePath);`n        if (await file.exists()) {`n          final result = await api.predictImage(file);`n          return _mapResultToDiagnosis(`n            cropName: cropName,`n            notes: notes,`n            result: result,`n          );`n        }`n      }`n      // No image provided -> use the existing library fallback.`n      return analyzeImagePlaceholder(cropName: cropName, notes: notes);`n    } catch (e, st) {`n      if (kDebugMode) {`n        debugPrint('[AIRepository] /predict failed, falling back: $e\n$st');`n      }`n      return analyzeImagePlaceholder(cropName: cropName, notes: notes);`n    } finally {`n      api.dispose();`n    }`n  }"
$newMethod = "  Future<DiseaseInferenceResult?> analyzeImageWithModel({`n    required String cropName,`n    String? imagePath,`n    String? notes,`n  }) async {`n    final api = DiseaseApiService();`n    try {`n      if (imagePath != null && imagePath.isNotEmpty) {`n        final file = File(imagePath);`n        if (await file.exists()) {`n          final result = await api.predictImage(file);`n          if (kDebugMode) {`n            debugPrint(`n              '[AIRepository] /predict ok top1=' +`n                  (result.topK.isNotEmpty ? result.topK.first.label : '-') +`n                  ' inferenceMs=' +`n                  result.inferenceMs.toString(),`n            );`n          }`n          return result;`n        }`n      }`n      return null;`n    } catch (e, st) {`n      if (kDebugMode) {`n        debugPrint('[AIRepository] /predict failed, falling back: $e\n$st');`n      }`n      return null;`n    } finally {`n      api.dispose();`n    }`n  }`n`n  /// Builds a [Diagnosis] from a [DiseaseInferenceResult]. When the result`n  /// has no top-K entries, falls back to the library-based advisor.`n  Future<Diagnosis> diagnosisFromInference({`n    required String cropName,`n    required DiseaseInferenceResult result,`n    String? notes,`n  }) async {`n    return _mapResultToDiagnosis(`n      cropName: cropName,`n      notes: notes,`n      result: result,`n    );`n  }"
Apply-LF $f2 $oldMethod $newMethod

# 5) Make _mapResultToDiagnosis async
Apply-LF $f2 "  Diagnosis _mapResultToDiagnosis({" "  Future<Diagnosis> _mapResultToDiagnosis({"

Write-Host 'OK ai_repository.dart'
Write-Host 'PATCH COMPLETE'
