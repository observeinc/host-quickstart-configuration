param (
    [Parameter(Mandatory)]
    $observe_collection_endpoint, 
    [Parameter(Mandatory)]
    $observe_token
)

$installer_url="https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.90.1/otelcol-contrib_0.90.1_windows_amd64.tar.gz"
$config_url="https://raw.githubusercontent.com/observeinc/host-config-scripts/main/opentelemetry/windows/config.yaml"
$local_installer="c:\temp\otelcol-contrib_0.90.1_windows_amd64.tar.gz"
$otel_install_dir="$env:ProgramFiles\OpenTelemetry Collector"
$otel_install_config="$otel_install_dir\config.yaml"
$temp_dir="c:\temp"

New-Item -ItemType Directory -Force -Path $temp_dir
New-Item -ItemType Directory -Force -Path $otel_install_dir 


Invoke-WebRequest -Uri $installer_url -OutFile $local_installer

if(-not (Test-Path "${otel_install_dir}\otelcol-contrib.exe")){
    try{
        tarp -xzf $local_installer -C $otel_install_dir
    }catch [System.Management.Automation.CommandNotFoundException] {
        Write-Host "tar not found, trying 7z"
        & "$env:ProgramFiles\7-zip\7z" x $local_installer -o"$temp_dir" -aoa
        & "$env:ProgramFiles\7-zip\7z" x $local_installer.Replace(".gz", "") -o"$otel_install_dir" -aoa
    }    
}else{
    Write-Host "Found existing otel installation, skipping installation and moving on to configuration."
}
Invoke-WebRequest -Uri $config_url -OutFile $otel_install_config


# Read the content of the config.yaml file
$configContent = Get-Content -Path $otel_install_config -Raw

# Replace ${myhost} with the actual value
$configContent = $configContent -replace '\${OBSERVE_COLLECTION_ENDPOINT}', $observe_collection_endpoint
$configContent = $configContent -replace '\${OBSERVE_TOKEN}', $observe_token

# Write the modified content back to the config.yaml file
$configContent | Set-Content -Path $otel_install_config

if(-not (Get-Service OpenTelemetry -ErrorAction SilentlyContinue)){
    New-Service -Name "OpenTelemetry" -BinaryPathName "`"${otel_install_dir}\otelcol-contrib.exe`" --config `"${otel_install_dir}\config.yaml`""
    Start-Service OpenTelemetry
    }
else{
    Stop-Service OpenTelemetry
    Start-Service OpenTelemetry
}
