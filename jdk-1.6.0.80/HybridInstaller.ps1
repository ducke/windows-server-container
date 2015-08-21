Param (
  [Parameter(ParameterSetName='ContainerNative')]
  [Switch]$RunNative,
  [Parameter(ParameterSetName='ContainerPowerShell')]
  [Switch]$CreateContainerImageUsingPowerShell,
  [Parameter(ParameterSetName='ContainerPowerShell')]
  [string]$InternetVirtualSwitchName = 'Virtual Switch'
)

$containerImageName = 'jdk'
$containerImagePublisher = $env:Username
$containerImageVersion = '1.8.0.60'

$containerScript = {
  $7ZipDownloadUri = 'http://www.7-zip.org/a/7za920.zip'

  $TempFolder = [System.Guid]::NewGuid().ToString()
  $TempDir = Join-Path $env:TEMP $TempFolder
  Write-Output ('Creating temp directory {0}' -f $TempDir)
  if (-not (Test-Path $TempDir)) {$null = New-Item -Path $TempDir -ItemType Directory}

  $7ZipFileName = Split-path $7ZipDownloadUri -Leaf
  $OutFilePath = Join-Path $TempDir $7ZipFileName

  Write-Output ('Downloading {0} to {1}' -f $7ZipDownloadUri,$OutFilePath)
  Invoke-WebRequest -uri $7ZipDownloadUri -OutFile $OutFilePath

  Expand-Archive -Path $OutFilePath -DestinationPath $TempDir
  Remove-Item -Path $TempDir -Exclude '*.exe' -Force -Recurse

  $7ZipBinDir = (Get-ChildItem -Path $TempDir).FullName

  $package = 'jdk8'
  $build = '27'
  $jdk_version = '8u60'
  $arch = 'x64'
  $JavaVersion = 'jdk1.8.0_60'

  #$url = 'http://download.oracle.com/otn-pub/java/jdk/8u60-b27/jdk-8u60-windows-x64.exe'
  #http://download.oracle.com/otn-pub/java/jdk/8u60-b27/server-jre-8u60-windows-x64.tar.gz
  $JavaFileName = "server-jre-$jdk_version-windows-$arch.tar.gz"

  $JavaFullName = Join-Path $TempDir $JavaFileName
  $JavaDownloadUri = "http://download.oracle.com/otn-pub/java/jdk/$jdk_version-b$build/$JavaFileName"
  [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }
  $client = New-Object Net.WebClient
  $client.Proxy = [System.Net.WebRequest]::DefaultWebProxy
  $client.Headers.Add('Cookie', 'gpw_e24=http://www.oracle.com; oraclelicense=accept-securebackup-cookie')
  Write-Output ('Downloading {0} to {1}' -f $JavaDownloadUrl,$JavaFullName)
  $client.DownloadFile($JavaDownloadUri, $JavaFullName)

  $7ZipArg = 'x -o"{0}" -y "{1}"' -f $TempDir,$JavaFullName
  Write-Output ('Starting 7za with args {0}' -f $7ZipArg)
  Start-Process $7ZipBinDir -ArgumentList $7ZipArg -Wait
  $7ZipArg2 = 'x -o"{0}" -y "{1}"' -f $TempDir,((Get-ChildItem $TempDir -Include '*.tar' -Recurse).FullName)
  Write-Output ('Starting 7za with args {0}' -f $7ZipArg2)
  Start-Process $7ZipBinDir -ArgumentList $7ZipArg2 -Wait

  Write-Output 'Copy Java Directory to ProgramFiles'
  $JavaRoot = Join-Path $env:ProgramFiles 'Java'
  if (-not (Test-Path $JavaRoot)) {$null = New-Item -Path $JavaRoot -ItemType Directory}
  Copy-Item -Path (Get-ChildItem $TempDir -Directory).FullName -Destination $JavaRoot -Recurse
  
  $JavaHome = Join-Path $JavaRoot $JavaVersion
  #http://download.oracle.com/otn-pub/java/jdk/8u60-b27/server-jre-8u60-windows-x64.tar.gz
  $JavaBin = Join-Path $JavaHome 'bin'
  [Environment]::SetEnvironmentVariable('Path',$Env:Path + (';{0}' -f $JavaBin), 'Machine')
  [Environment]::SetEnvironmentVariable('CLASSPATH','.;', 'Machine')
  [Environment]::SetEnvironmentVariable('JAVA_HOME',$JavaHome, 'Machine')

}
If ($RunNative)
{
  Write-Output 'Running natively (or inside a Container) - simply executing the script block'
  Invoke-Command -ScriptBlock $containerScript
}
ElseIf ($CreateContainerImageUsingPowerShell)
{
  Write-Output 'Creating new Container using PowerShell'
  $c1 = New-Container "$containerImageName BuildContainer" -ContainerImageName 'WindowsServerCore' -Switch $internetVirtualSwitchName

  Write-Output "Starting $($c1.Name)"
  Start-Container $c1

  Write-Output 'Running Script Block inside Container'
  Invoke-Command -ContainerId $c1.Id -RunAsAdministrator -ScriptBlock $containerScript -ErrorAction Stop

  Write-Output "Stopping $($c1.Name)"
  Stop-Container $c1

  Write-Output "Creating new image $containerImageName from $($c1.Name)"
  Do {New-ContainerImage -Container $c1 -Publisher $containerImagePublisher -Name $containerImageName -Version $containerImageVersion -EA 0} Until ($?)

  Write-Output "Removing Container $($c1.Name)"
  Remove-Container $c1 -Force
  }
Else
{
    Write-Output 'Please specify either -RunNative or -CreateContainerImageUsingPowerShell'
}