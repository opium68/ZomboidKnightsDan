[CmdletBinding()]
param([string]$ServerRoot='D:/PZDedicated',[string]$Jdk='C:/Program Files/Java/jdk-21')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$out=Join-Path $root 'artifacts/raccoon-expedition'
[void](New-Item -ItemType Directory -Path (Join-Path $out 'classes') -Force)
$engine=Join-Path $ServerRoot 'java/projectzomboid.jar'
$hash=(Get-FileHash -LiteralPath $engine).Hash
$marker=Join-Path $out 'compile-api.sha256'
if(!(Test-Path -LiteralPath $marker) -or (Get-Content -LiteralPath $marker -Raw).Trim() -ne $hash){
    & "$Jdk/bin/java.exe" (Join-Path $root 'native/raccoon/CompileApi.java') $engine (Join-Path $out 'compile-api.jar')
    if($LASTEXITCODE){throw 'Compile API creation failed'}
    Set-Content -LiteralPath $marker -Value $hash
}
$sources=@('RCEAgent.java','RCEProtection.java','RCEBridge.java','OfflineReset.java','RceLuaRunner.java')|ForEach-Object{Join-Path $root ('native/raccoon/'+$_)}
if(Test-Path -LiteralPath (Join-Path $out 'classes/raccoon')){
    foreach($old in Get-ChildItem -LiteralPath (Join-Path $out 'classes/raccoon') -File | Where-Object {$_.Name -match '^(RCEAgent|RCEProtection|RCEBridge).*\.class$'}){
        Remove-Item -LiteralPath $old.FullName
    }
}
& "$Jdk/bin/javac.exe" -cp (Join-Path $out 'compile-api.jar') -d (Join-Path $out 'classes') @sources
if($LASTEXITCODE){throw 'Native bridge compilation failed'}
$manifest=Join-Path $out 'agent-manifest.mf'
[IO.File]::WriteAllText($manifest,"Manifest-Version: 1.0`nPremain-Class: raccoon.RCEAgent`n`n",[Text.UTF8Encoding]::new($false))
$jarArguments=@('cfm',(Join-Path $out 'raccoon-bridge.jar'),$manifest)
foreach($file in Get-ChildItem -LiteralPath (Join-Path $out 'classes/raccoon') -File | Where-Object {$_.Name -match '^(RCEAgent(?:\$.*)?|RCEBridge(?:\$.*)?|RCEProtection(?:\$.*)?|OfflineReset)\.class$'}){
    $jarArguments+=@('-C',(Join-Path $out 'classes'),('raccoon/'+$file.Name))
}
& "$Jdk/bin/jar.exe" @jarArguments
if($LASTEXITCODE){throw 'Native bridge packaging failed'}
Write-Output "Native bridge built for engine SHA256 $hash. Compile API is NOT a runtime dependency."
