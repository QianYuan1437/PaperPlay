param([string]$Ffmpeg = 'ffmpeg')
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output = Join-Path $projectRoot 'artifacts'
New-Item -ItemType Directory -Force $output | Out-Null
$source = Join-Path $projectRoot 'docs/media/tide.mp4'
$large = Join-Path $output 'stress-large.mp4'
# Real MP4 packets at 200 Mbit/s (including H.264 CBR filler), not a sparse file
# or trailing padding. Exercises bounded reads and long-GOP seeks at large size.
& $Ffmpeg -hide_banner -loglevel error -stream_loop -1 -i $source -t 60 -vf scale=1920:1080 -r 30 -c:v libx264 -threads 2 -preset ultrafast -b:v 200M -minrate 200M -maxrate 200M -bufsize 200M -x264-params nal-hrd=cbr:filler=1 -c:a aac -y $large
if ($LASTEXITCODE -ne 0) { throw 'Large fixture generation failed' }
& $Ffmpeg -hide_banner -loglevel error -i $large -t 20 -c copy -y (Join-Path $output 'stress-500mb.mp4')
if ($LASTEXITCODE -ne 0) { throw '500 MB fixture generation failed' }
& $Ffmpeg -hide_banner -loglevel error -i $source -t 4 -vf scale=3840:2160 -r 30 -c:v libx264 -threads 2 -preset ultrafast -crf 35 -c:a copy -y (Join-Path $output 'stress-4k.mp4')
if ($LASTEXITCODE -ne 0) { throw '4K fixture generation failed' }
Write-Output 'Fixtures ready in artifacts/. They are synthetic and excluded from Git.'
