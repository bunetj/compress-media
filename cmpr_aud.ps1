# audio-compress.ps1
# Flexible audio compressor - smart or forced

param(
    [string]$Bitrate = "auto",        # 64, 96, 128, 192, or "auto"
    [switch]$Force,                   # Compress everything (even if efficient)
    [switch]$Recurse,                 # Process subfolders
    [switch]$Replace,                 # Replace originals (DANGEROUS!)
    [switch]$Help
)

# ============================================
#  HELP
# ============================================
if ($Help) {
    Write-Host @"
AUDIO COMPRESSOR

USAGE:
  .\audio-compress.ps1 [-Bitrate <value>] [-Force] [-Recurse] [-Replace]

OPTIONS:
  -Bitrate <value>   Target bitrate in kbps (64, 96, 128, 192)
                     Default: "auto" (uses 70% of original)
  
  -Force             Compress ALL files (even if already efficient)
                     Without -Force, only compresses files >192kbps

  -Recurse           Process audio files in ALL subfolders

  -Replace           REPLACE originals with compressed versions
                     WARNING: Original files are DELETED!
                     Without -Replace, creates -compressed copies

  -Help              Show this help

EXAMPLES:
  .\audio-compress.ps1                              # Smart mode (creates copies)
  .\audio-compress.ps1 -Replace                    # Smart mode (REPLACES originals!)
  .\audio-compress.ps1 -Bitrate 128 -Replace       # Compress all to 128k & replace
  .\audio-compress.ps1 -Force -Bitrate 96 -Recurse # Compress everything in subfolders

"@
    exit 0
}

# ============================================
#  SETTINGS
# ============================================
$MaxBitrate = 192    # Only compress if bitrate > this (unless -Force)

# ============================================
#  GET FILES (with or without subfolders)
# ============================================
$AudioExtensions = @(".mp3", ".m4a", ".aac", ".flac", ".wav", ".ogg", ".wma")

if ($Recurse) {
    $Files = Get-ChildItem -Recurse -File | Where-Object { 
        $AudioExtensions -contains $_.Extension.ToLower() -and
        $_.BaseName -notmatch "-compressed$"
    }
} else {
    $Files = Get-ChildItem -File | Where-Object { 
        $AudioExtensions -contains $_.Extension.ToLower() -and
        $_.BaseName -notmatch "-compressed$"
    }
}

if ($Files.Count -eq 0) {
    Write-Host "No audio files found." -ForegroundColor Yellow
    exit 0
}

$Count = 0
$Compressed = 0
$Skipped = 0

Write-Host "Scanning $($Files.Count) files..." -ForegroundColor Cyan
if ($Recurse) { Write-Host "  (including subfolders)" -ForegroundColor DarkGray }
if ($Replace) { Write-Host "  ⚠️  REPLACE MODE: Originals will be DELETED!" -ForegroundColor Red }
Write-Host ""

foreach ($File in $Files) {
    $Count++
    
    # Determine output path
    if ($Replace) {
        # Replace mode: overwrite original
        $Out = $File.FullName
    } else {
        # Safe mode: create -compressed copy
        if ($Recurse) {
            $SubPath = $File.DirectoryName.Substring((Get-Location).Path.Length + 1)
            if ($SubPath) {
                New-Item -ItemType Directory -Path $SubPath -ErrorAction SilentlyContinue | Out-Null
                $Out = Join-Path $SubPath "$($File.BaseName)-compressed$($File.Extension)"
            } else {
                $Out = "$($File.BaseName)-compressed$($File.Extension)"
            }
        } else {
            $Out = "$($File.BaseName)-compressed$($File.Extension)"
        }
    }
    
    # In safe mode, skip if output already exists
    if (-not $Replace -and (Test-Path $Out)) {
        Write-Host "[$Count/$($Files.Count)] SKIP: $($File.Name) (already compressed)" -ForegroundColor Gray
        $Skipped++
        continue
    }
    
    Write-Host "[$Count/$($Files.Count)] $($File.Name)" -NoNewline
    
    # Get duration
    $Duration = & ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "`"$($File.FullName)`"" 2>$null
    $Duration = [math]::Round([double]$Duration)
    
    if ($Duration -lt 10) {
        Write-Host " ⏭️ Too short ($Duration sec)" -ForegroundColor Gray
        $Skipped++
        continue
    }
    
    # Calculate current bitrate
    $SizeBits = $File.Length * 8
    $CurrentBitrate = [math]::Round($SizeBits / $Duration / 1000)
    
    Write-Host " - ${Duration}s, ${CurrentBitrate}kbps" -NoNewline
    
    # ============================================
    #  DECIDE: COMPRESS OR SKIP?
    # ============================================
    $ShouldCompress = $false
    $TargetBitrate = 0
    
    if ($Force) {
        $ShouldCompress = $true
        if ($Bitrate -eq "auto") {
            $TargetBitrate = [math]::Min(128, [math]::Round($CurrentBitrate * 0.7))
        } else {
            $TargetBitrate = [int]$Bitrate
        }
    } else {
        if ($CurrentBitrate -gt $MaxBitrate) {
            $ShouldCompress = $true
            if ($Bitrate -eq "auto") {
                $TargetBitrate = [math]::Min(128, [math]::Round($CurrentBitrate * 0.7))
            } else {
                $TargetBitrate = [int]$Bitrate
            }
        } else {
            Write-Host " ✅ Efficient (skip)" -ForegroundColor Green
            $Skipped++
            continue
        }
    }
    
    $TargetBitrate = [math]::Max(64, $TargetBitrate)
    
    Write-Host " → ${TargetBitrate}kbps" -NoNewline
    
    # ============================================
    #  COMPRESS
    # ============================================
    # For replace mode, compress to a temp file first
    if ($Replace) {
        $TempOut = "$($File.FullName).tmp"
    } else {
        $TempOut = $Out
    }
    
    switch -Wildcard ($File.Extension) {
        ".mp3" { 
            ffmpeg -i "`"$($File.FullName)`"" -c:a libmp3lame -b:a ${TargetBitrate}k -y "`"$TempOut`"" 2>$null 
        }
        ".m4a" { 
            ffmpeg -i "`"$($File.FullName)`"" -c:a aac -b:a ${TargetBitrate}k -y "`"$TempOut`"" 2>$null 
        }
        ".aac" { 
            ffmpeg -i "`"$($File.FullName)`"" -c:a aac -b:a ${TargetBitrate}k -y "`"$TempOut`"" 2>$null 
        }
        ".flac" { 
            ffmpeg -i "`"$($File.FullName)`"" -c:a flac -compression_level 8 -y "`"$TempOut`"" 2>$null 
        }
        ".wav" { 
            ffmpeg -i "`"$($File.FullName)`"" -c:a pcm_s16le -y "`"$TempOut`"" 2>$null 
        }
        ".ogg" { 
            ffmpeg -i "`"$($File.FullName)`"" -c:a libvorbis -b:a ${TargetBitrate}k -y "`"$TempOut`"" 2>$null 
        }
        ".wma" { 
            ffmpeg -i "`"$($File.FullName)`"" -c:a wmav2 -b:a ${TargetBitrate}k -y "`"$TempOut`"" 2>$null 
        }
        default { 
            Write-Host " ⏭️ Unknown format" -ForegroundColor Gray
            $Skipped++
            continue 
        }
    }
    
    if (Test-Path $TempOut) {
        $Orig = [math]::Round($File.Length / 1MB, 1)
        $New = [math]::Round((Get-Item $TempOut).Length / 1MB, 1)
        $Saved = [math]::Round((1 - $New / $Orig) * 100, 0)
        
        if ($Replace) {
            # Replace mode: swap temp with original
            Remove-Item $File.FullName -Force
            Rename-Item $TempOut $File.FullName
            Write-Host " ✅ REPLACED: $Orig MB → $New MB (saved $Saved%)" -ForegroundColor Green
        } else {
            Write-Host " ✅ $Orig MB → $New MB (saved $Saved%)" -ForegroundColor Green
        }
        $Compressed++
    } else {
        Write-Host " ❌ FAILED" -ForegroundColor Red
        if (Test-Path $TempOut) { Remove-Item $TempOut -Force }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Complete!" -ForegroundColor Green
Write-Host "  Files scanned:  $($Files.Count)" -ForegroundColor White
Write-Host "  Compressed:     $Compressed" -ForegroundColor Green
Write-Host "  Skipped:        $Skipped" -ForegroundColor Gray
if ($Recurse) { Write-Host "  Mode: Subfolders included" -ForegroundColor DarkGray }
if ($Replace) { Write-Host "  Mode: REPLACED originals" -ForegroundColor Red }
Write-Host "========================================" -ForegroundColor Cyan