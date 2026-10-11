$ErrorActionPreference = 'Stop'
$projectRoot = $PSScriptRoot
$firebaseProject = 'pemetaan-pohon-11417'
$firebaseCli = Join-Path $projectRoot 'rules_test\node_modules\firebase-tools\lib\bin\firebase.js'
$rulesFile = Join-Path $projectRoot 'firestore.rules'
if (-not (Test-Path $firebaseCli)) {
    throw 'Buka folder rules_test dan jalankan npm install terlebih dahulu.'
}
$config = Get-Content (Join-Path $projectRoot 'firebase.json') -Raw | ConvertFrom-Json
if ($config.firestore.rules -ne 'firestore.rules') {
    throw 'firebase.json harus menunjuk ke firestore.rules.'
}
$before = (Get-FileHash $rulesFile -Algorithm SHA256).Hash
Push-Location (Join-Path $projectRoot 'rules_test')
try {
    & npm.cmd test
    if ($LASTEXITCODE -ne 0) { throw 'Tes rules gagal. Deploy dibatalkan.' }
} finally {
    Pop-Location
}
$after = (Get-FileHash $rulesFile -Algorithm SHA256).Hash
if ($before -ne $after) { throw 'Rules berubah selama tes. Jalankan ulang.' }
Push-Location $projectRoot
try {
    & node $firebaseCli deploy --only firestore:rules --project $firebaseProject --config firebase.json
    if ($LASTEXITCODE -ne 0) { throw 'Deploy gagal. Rules produksi belum terkonfirmasi.' }
    Write-Host "Deploy rules berhasil ke $firebaseProject. SHA256 file yang diuji: $after"
    Write-Host 'Periksa Rules pada database (default) di Firebase Console dan lakukan uji akses setelah deployment.'
} finally {
    Pop-Location
}