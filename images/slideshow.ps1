# same size, eg auto screenshots
# no subfolders
# change duration: 1 means 1 second per image. (line 3)

$images = Get-ChildItem -Include *.jpg,*.jpeg,*.png,*.bmp,*.gif,*.tiff,*.webp,*.svg,*.heic,*.heif | Sort-Object Name
$tempFile = "filelist.txt"
$images | ForEach-Object { "file '$($_.Name)'`nduration 1" } | Out-File $tempFile -Encoding ASCII
ffmpeg -f concat -safe 0 -i $tempFile -vf "fps=30,format=yuv420p" -c:v libx264 -preset medium slideshow.mp4
Remove-Item $tempFile

