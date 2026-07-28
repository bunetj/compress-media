# resize.ps1
param(
    [switch]$resize,
    $p,
    $s,
    $r,
    [switch]$bit8,
    [switch]$jpg,
    $q,
    [switch]$replace,
    [switch]$recurse,
    [switch]$log,
    [switch]$help
)

if($help -or $args[0] -eq '--help'){@'
-s n    select files > n MB
-r n    select files > n*1000 px in height/width (resolution)
-resize by 50% by default
-p n    by n %
-bit8
-jpg
-jpg -q

-replace        overwrites. otherwise puts in _compressed\ near
-recurse        looks in subfolders

-log    auto-created
'@;exit}

if(!$resize -and !$bit8 -and !$jpg){Write-Error "Need -resize, -bit8, or -jpg";exit}
if($args[0] -match '^\d+$'){Write-Error "-resize <number> invalid";exit}

$pct = if($p){$p}else{50}
$qual = if($q){$q}else{85}
if($log){$logFile = "errors.txt"; "" > $logFile; $ErrorActionPreference = "SilentlyContinue"}

$files = @()
if($recurse){
    $files += Get-ChildItem -Recurse -Filter "*.jpg"
    $files += Get-ChildItem -Recurse -Filter "*.jpeg"
    $files += Get-ChildItem -Recurse -Filter "*.png"
} else {
    $files += Get-ChildItem -Filter "*.jpg"
    $files += Get-ChildItem -Filter "*.jpeg"
    $files += Get-ChildItem -Filter "*.png"
}

if($s){$files = $files | Where-Object {$_.Length / 1MB -gt $s}}
if($r){
    $dims = magick identify -format "%w %h" $files.FullName 2>$null
    $i = 0
    $files = $files | Where-Object {
        $w,$h = $dims[$i++] -split ' '
        [int]$w -gt ($r*1000) -or [int]$h -gt ($r*1000)
    }
}

if(!$files){Write-Host "No files match";exit}

if(!$replace){
    $outDir = "..\$((Get-Location).Path.Split('\')[-1])_compressed"
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    $total = $files.Count; $i = 0
    foreach($f in $files){
        try {
            $outFile = "$outDir\$($f.Name)"
            if($jpg -and $f.Extension -notin '.jpg','.jpeg'){$outFile = "$outDir\$($f.BaseName).jpg"}
            if($resize){magick $f.FullName -resize "$pct%" $outFile}
            if($bit8){magick $outFile -depth 8 $outFile}
            if($jpg -and $f.Extension -notin '.jpg','.jpeg'){magick $f.FullName -quality $qual $outFile}
        } catch {
            $err = "[ERROR] $($f.FullName): $_"
            if($log){$err >> $logFile}
        }
        $i++; Write-Progress -Activity "Processing" -Status " " -PercentComplete (($i/$total)*100)
    }
    if($log -and (Test-Path $logFile)){Write-Host "Errors logged to: $logFile"}
    Write-Host "Done! Saved to: $outDir"
    exit
}

$total = $files.Count; $i = 0
foreach($f in $files){
    try {
        if($resize -or $bit8 -or $jpg){
            $ext = $f.Extension
            $outFile = $f.FullName
            if($jpg -and $ext -notin '.jpg','.jpeg'){
                $outFile = "$($f.Directory)\$($f.BaseName).jpg"
            }
            
            if($resize){magick $f.FullName -resize "$pct%" $outFile}
            if($bit8){magick $outFile -depth 8 $outFile}
            if($jpg -and $ext -notin '.jpg','.jpeg'){
                magick $f.FullName -quality $qual $outFile
                Remove-Item $f.FullName -Force
            }
        }
    } catch {
        $err = "[ERROR] $($f.FullName): $_"
        if($log){$err >> $logFile}
    }
    $i++; Write-Progress -Activity "Processing" -Status " " -PercentComplete (($i/$total)*100)
}
if($log -and (Test-Path $logFile)){Write-Host "Errors logged to: $logFile"}
Write-Host "Done!"