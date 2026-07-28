# video-compress.ps1
param(
    [string]$InputFile,
    [string]$Quality = "smart",        # smart | lossless | high | medium | low | tiny
    [string]$Preset = "medium",
    [string]$OutputDir = ".",
    [switch]$Replace,                   # Replace originals
    [switch]$Recurse,                   # Process subfolders
    [switch]$help
)

function Show-Help {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════╗
║              VIDEO COMPRESSOR - FFmpeg Wrapper                   ║
╚═══════════════════════════════════════════════════════════════════╝

USAGE:
  .\video-compress.ps1 [options]

OPTIONS:
  -InputFile <file>    Compress a single specific file
                       If omitted, processes ALL video files

  -Quality <level>     Compression quality (default: smart)
                       levels:  smart   -> Auto-detect based on bitrate
                                lossless -> CRF 14 (archival)
                                high    -> CRF 18 (visually lossless)
                                medium  -> CRF 23 (sweet spot)
                                low     -> CRF 28 (noticeably compressed)
                                tiny    -> CRF 33 (smallest)

  -Preset <speed>      Encoding speed (default: medium)
                       speeds:  ultrafast | superfast | veryfast | faster |
                                fast | medium | slow | slower | veryslow

  -OutputDir <path>    Where to save compressed files (default: current dir)

  -Replace             REPLACE originals with compressed versions
                       WARNING: Original files are DELETED!

  -Recurse             Process video files in ALL subfolders

  -help, -?            Show this help menu

EXAMPLES:
  .\video-compress.ps1                              # Smart mode (auto)
  .\video-compress.ps1 -Quality high -Preset slow  # High quality
  .\video-compress.ps1 -Quality smart -Recurse     # Smart + subfolders
  .\video-compress.ps1 -Quality tiny -Replace      # Tiny + replace originals

SMART MODE (auto CRF):
  Source bitrate > 10,000 kbps  -> CRF 18 (high quality)
  Source bitrate 5,000-10,000   -> CRF 23 (balanced)
  Source bitrate < 5,000 kbps   -> CRF 26 (light compression)

"@
}

# Show help if requested
if ($help -or $InputFile -eq "help" -or $InputFile -eq "?") {
    Show-Help
    exit 0
}

# Quality to CRF mapping
$QualityMap = @{
    "smart"     = $null   # Will be calculated per file
    "lossless"  = 14
    "high"      = 18
    "medium"    = 23
    "low"       = 28
    "tiny"      = 33
}

# Validate Quality
if (-not $QualityMap.ContainsKey($Quality)) {
    Write-Host "ERROR: Invalid quality '$Quality'" -ForegroundColor Red
    Write-Host "Valid options: smart, lossless, high, medium, low, tiny" -ForegroundColor Yellow
    exit 1
}

# Validate Preset
$ValidPresets = @("ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow")
if ($ValidPresets -notcontains $Preset) {
    Write-Host "ERROR: Invalid preset '$Preset'" -ForegroundColor Red
    Write-Host "Valid options: $($ValidPresets -join ', ')" -ForegroundColor Yellow
    exit 1
}

# ============================================
#  GET FILES (with or without subfolders)
# ============================================
$VideoExtensions = @(".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm", ".m4v", ".mpg", ".mpeg")

if ($InputFile) {
    # Single file mode
    if (-not (Test-Path $InputFile)) {
        Write-Host "ERROR: File not found: $InputFile" -ForegroundColor Red
        exit 1
    }
    $Files = @(Get-Item $InputFile)
} elseif ($Recurse) {
    # Batch mode with subfolders
    $Files = Get-ChildItem -Recurse -File | Where-Object { 
        $VideoExtensions -contains $_.Extension.ToLower()
    }
} else {
    # Batch mode - current directory only
    $Files = Get-ChildItem -File | Where-Object { 
        $VideoExtensions -contains $_.Extension.ToLower()
    }
}

if ($Files.Count -eq 0) {
    Write-Host "No video files found." -ForegroundColor Yellow
    exit 0
}

# ============================================
#  PROCESS FILES
# ============================================
$Total = $Files.Count
$Count = 0
$Processed = 0
$Skipped = 0

Write-Host "Scanning $Total video files..." -ForegroundColor Cyan
if ($Recurse) { Write-Host "  (including subfolders)" -ForegroundColor DarkGray }
if ($Replace) { Write-Host "  ⚠️  REPLACE MODE: Originals will be DELETED!" -ForegroundColor Red }
Write-Host ""

foreach ($File in $Files) {
    $Count++
    
    # Determine output path
    if ($Replace) {
        $OutputFile = $File.FullName
    } else {
        if ($Recurse) {
            $SubPath = $File.DirectoryName.Substring((Get-Location).Path.Length + 1)
            if ($SubPath) {
                $DestDir = Join-Path $OutputDir $SubPath
                New-Item -ItemType Directory -Path $DestDir -ErrorAction SilentlyContinue | Out-Null
                $OutputFile = Join-Path $DestDir "$($File.BaseName)-compressed$($File.Extension)"
            } else {
                $OutputFile = Join-Path $OutputDir "$($File.BaseName)-compressed$($File.Extension)"
            }
        } else {
            $OutputFile = Join-Path $OutputDir "$($File.BaseName)-compressed$($File.Extension)"
        }
    }
    
    # ============================================
    #  SMART CRF DETECTION
    # ============================================
    if ($Quality -eq "smart") {
        # Get video bitrate using ffprobe
        $BitrateInfo = & ffprobe -v error -show_entries format=bit_rate -of default=noprint_wrappers=1:nokey=1 "`"$($File.FullName)`"" 2>$null
        
        if ($BitrateInfo -and $BitrateInfo -gt 0) {
            $BitrateKbps = [math]::Round([int]$BitrateInfo / 1000)
            
            # Smart CRF selection
            if ($BitrateKbps -gt 10000) {
                $CRF = 18   # High quality source (Blu-ray, 4K)
                $QualityLabel = "high (auto)"
            } elseif ($BitrateKbps -gt 5000) {
                $CRF = 23   # Medium quality source
                $QualityLabel = "medium (auto)"
            } else {
                $CRF = 26   # Already compressed source
                $QualityLabel = "light (auto)"
            }
            
            Write-Host "[$Count/$Total] $($File.Name)" -NoNewline
            Write-Host " - ${BitrateKbps}kbps → CRF $CRF ($QualityLabel)" -ForegroundColor DarkGray
        } else {
            # Fallback if bitrate can't be detected
            $CRF = 23
            $QualityLabel = "medium (fallback)"
            Write-Host "[$Count/$Total] $($File.Name)" -NoNewline
            Write-Host " - unknown bitrate → CRF $CRF (fallback)" -ForegroundColor DarkGray
        }
    } else {
        $CRF = $QualityMap[$Quality]
        $QualityLabel = $Quality
        Write-Host "[$Count/$Total] Processing: $($File.Name)" -ForegroundColor Cyan
        Write-Host "  Quality: $Quality (CRF $CRF) | Preset: $Preset" -ForegroundColor DarkGray
    }
    
    # ============================================
    #  BUILD FFMPEG COMMAND
    # ============================================
    # For replace mode, use temp file
    if ($Replace) {
        $TempFile = "$($File.FullName).tmp"
    } else {
        $TempFile = $OutputFile
    }
    
    $FFmpegArgs = @(
        "-i", "`"$($File.FullName)`"",
        "-c:v", "libx265",
        "-crf", $CRF,
        "-preset", $Preset,
        "-c:a", "aac",
        "-b:a", "128k",
        "-movflags", "+faststart",
        "-y",
        "`"$TempFile`""
    )
    
    try {
        # Run FFmpeg
        $Process = Start-Process -FilePath "ffmpeg" -ArgumentList $FFmpegArgs -Wait -PassThru -NoNewWindow
        
        if ($Process.ExitCode -eq 0 -and (Test-Path $TempFile)) {
            $OriginalSize = [math]::Round($File.Length / 1MB, 2)
            $CompressedSize = [math]::Round((Get-Item $TempFile).Length / 1MB, 2)
            $Ratio = [math]::Round((1 - $CompressedSize / $OriginalSize) * 100, 1)
            
            if ($Replace) {
                # Replace mode: swap temp with original
                Remove-Item $File.FullName -Force
                Rename-Item $TempFile $File.FullName
                Write-Host "  ✅ REPLACED: $OriginalSize MB -> $CompressedSize MB (Saved $Ratio%)" -ForegroundColor Green
            } else {
                Write-Host "  ✅ DONE: $OriginalSize MB -> $CompressedSize MB (Saved $Ratio%)" -ForegroundColor Green
            }
            $Processed++
        } else {
            Write-Host "  ❌ FAILED: FFmpeg error" -ForegroundColor Red
            if (Test-Path $TempFile) { Remove-Item $TempFile -Force }
        }
    } catch {
        Write-Host "  ❌ ERROR: $_" -ForegroundColor Red
        if (Test-Path $TempFile) { Remove-Item $TempFile -Force }
    }
    
    Write-Host ""
}

# ============================================
#  SUMMARY
# ============================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "COMPLETE!" -ForegroundColor Green
Write-Host "  Files scanned:  $Total" -ForegroundColor White
Write-Host "  Processed:      $Processed" -ForegroundColor Green
Write-Host "  Skipped:        $Skipped" -ForegroundColor Gray
if ($Recurse) { Write-Host "  Mode: Subfolders included" -ForegroundColor DarkGray }
if ($Replace) { Write-Host "  Mode: REPLACED originals" -ForegroundColor Red }
Write-Host "========================================" -ForegroundColor Cyan