$ESUri = 'http://download.elastic.co/elasticsearch/elasticsearch/elasticsearch-1.7.1.zip'

$TempFolder = [System.Guid]::NewGuid().ToString()
$TempDir = Join-Path $env:TEMP $TempFolder
Write-Output ('Creating temp directory {0}' -f $TempDir)
if (-not (Test-Path $TempDir)) {$null = New-Item -Path $TempDir -ItemType Directory}

$ESZipFileName = Split-path $ESUri -Leaf
$OutFilePath = Join-Path $TempDir $ESZipFileName

Write-Output ('Downloading {0} to {1}' -f $ESUri,$OutFilePath)
Invoke-WebRequest -uri $ESUri -OutFile $OutFilePath

Expand-Archive -Path $OutFilePath -DestinationPath $TempDir

$ESTempPath = (Get-ChildItem -Path $TempDir -Directory).FullName

#$ESPath = Join-Path 'C:\' (Split-Path $ESTempPath -Leaf)
#If (-not (Test-Path $ESPath)) {$null = New-Item $ESPath -ItemType Directory}

Copy-Item $ESTempPath 'C:\' -Recurse
