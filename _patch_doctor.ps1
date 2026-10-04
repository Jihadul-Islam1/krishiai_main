$ErrorActionPreference = 'Stop'
$path = 'd:\KrishiAi-main\lib\presentation\screens\ai\crop_doctor_screen.dart'
$enc = New-Object System.Text.UTF8Encoding($false)
$text = [System.IO.File]::ReadAllText($path, $enc)
$NL = "`n"

$oldImp = "import '../../providers/app_providers.dart';"
$newImp = "import '../../../core/network/disease_api_service.dart';" + $NL + "import '../../providers/app_providers.dart';"
if ($text.Contains($oldImp)) { $text = $text.Replace($oldImp, $newImp); 'imports OK' } else { 'imports MISS' }

$oldA = '    final repo = await ref.read(aiRepoProvider.future);' + $NL + '    final diag = await repo.analyzeImagePlaceholder(' + $NL + '      cropName: _selectedCropName!,' + $NL + '      notes: _notesController.text.trim().isEmpty' + $NL + '          ? null' + $NL + '          : _notesController.text.trim(),' + $NL + '    );'
$newA = '    final repo = await ref.read(aiRepoProvider.future);' + $NL + '    final notesText = _notesController.text.trim();' + $NL + '    final notesArg = notesText.isEmpty ? null : notesText;' + $NL + '    DiseaseInferenceResult? backend;' + $NL + '    Diagnosis diag;' + $NL + '    bool backendOffline = true;' + $NL + '    if (_imagePath != null) {' + $NL + '      try {' + $NL + '        backend = await repo.analyzeImageWithModel(' + $NL + '          imagePath: _imagePath!,' + $NL + '          cropName: _selectedCropName!,' + $NL + '          notes: notesArg,' + $NL + '        );' + $NL + '      } catch (_) {' + $NL + '        backend = null;' + $NL + '      }' + $NL + '    }' + $NL + '    if (backend != null) {' + $NL + '      diag = await repo.analyzeImagePlaceholder(' + $NL + '        cropName: _selectedCropName!,' + $NL + '        notes: notesArg,' + $NL + '      );' + $NL + '    } else {' + $NL + '      diag = await repo.analyzeImagePlaceholder(' + $NL + '        cropName: _selectedCropName!,' + $NL + '        notes: notesArg,' + $NL + '      );' + $NL + '    }'
if ($text.Contains($oldA)) { $text = $text.Replace($oldA, $newA); 'analyze OK' } else { 'analyze MISS' }

$oldE = "        'diagnosis': diag," + $NL + "        if (_imagePath != null) 'imagePath': _imagePath," + $NL + "        if (imageRemoteUrl != null) 'imageRemoteUrl': imageRemoteUrl," + $NL + "      }," + $NL + "    );"
$newE = "        'diagnosis': diag," + $NL + "        'backendOffline': backendOffline," + $NL + "        'inferenceMs': backend?.inferenceMs," + $NL + "        'topK': backend?.topK" + $NL + "            .map((p) => TopPrediction(" + $NL + "                  label: p.label," + $NL + "                  labelBn: p.labelBn," + $NL + "                  labelEn: p.labelEn," + $NL + "                  confidence: p.confidence," + $NL + "                  severity: p.severity," + $NL + "                ))" + $NL + "            .toList()," + $NL + "        if (_imagePath != null) 'imagePath': _imagePath," + $NL + "        if (imageRemoteUrl != null) 'imageRemoteUrl': imageRemoteUrl," + $NL + "      }," + $NL + "    );"
if ($text.Contains($oldE)) { $text = $text.Replace($oldE, $newE); 'extra OK' } else { 'extra MISS' }

[System.IO.File]::WriteAllText($path, $text, $enc)
Write-Host ('final len=' + $text.Length)
