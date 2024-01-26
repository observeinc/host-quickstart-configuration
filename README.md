# Host Quickstart
To quickly test how the app works with a vm run the following script to install the Open Telemetry Collector on your vm:

### Linux Install
```
curl https://raw.githubusercontent.com/observeinc/host-quickstart-configuration/main/opentelemetry/linux/observe_otel_install.sh | bash -s -- --observe_collection_endpoint "${OBSERVE_COLLECTION_ENDPOINT}" --observe_token "${OBSERVE_TOKEN}"
```

#### Check Status
```
journalctl -u otelcol-contrib -f
```

#### Linux Un-Install
```
curl https://raw.githubusercontent.com/observeinc/host-quickstart-configuration/main/opentelemetry/linux/observe_otel_install.sh | bash -s -- --observe_collection_endpoint "${OBSERVE_COLLECTION_ENDPOINT}" --observe_token "${OBSERVE_TOKEN}" --uninstall
```

### Windows Install
This script assumes that 7zip is installed.  To install please refer to 7zip documentation - https://www.7-zip.org/download.html.

```
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"; Invoke-WebRequest -UseBasicParsing "https://github.com/observeinc/host-quickstart-configuration/blob/main/opentelemetry/windows/observe_otel_install.ps1" -outfile .\agents.ps1; .\agents.ps1 -observe_token "${OBSERVE_TOKEN}" -OBSERVE_COLLECTION_ENDPOINT  "${OBSERVE_COLLECTION_ENDPOINT}"

```

### Mac

Monitoring of a desktop environment is easiest to achieve using a precompiled binary.

#### Create a new directory and download configuration file
```
mkdir mac_monitor

curl -O https://raw.githubusercontent.com/observeinc/host-quickstart-configuration/main/opentelemetry/mac/config.yaml
```

### Create a new directory, download binary and move into /usr/local/bin:
#### M1
```
mkdir binary_download

cd binary_download

curl --proto '=https' --tlsv1.2 -fOL https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.92.0/otelcol-contrib_0.92.0_darwin_arm64.tar.gz

tar -xvf otelcol-contrib_0.92.0_darwin_arm64.tar.gz

sudo mv otelcol-contrib /usr/local/bin/

```

### Set relevant environment variables and run binary:

```
export OBSERVE_COLLECTION_ENDPOINT="${OBSERVE_COLLECTION_ENDPOINT?}"; 
export OBSERVE_TOKEN="${OBSERVE_TOKEN?}"; 
export CONFIG_PATH=[THE_FULL_PATH_TO_config.yaml]; 
otelcol-contrib --config $CONFIG_PATH
```

## Uninstall:

```
sudo rm /usr/local/bin/otelcol-contrib
```

References:

https://opentelemetry.io/docs/collector/configuration/#environment-variables

https://opentelemetry.io/docs/collector/installation/#macos

https://github.com/open-telemetry/opentelemetry-collector-releases/releases