# Host Quickstart
To quickly test how the app works with a vm run the following script to install the Open Telemetry Collector on your vm:

## Linux Install

### Debian-based Distributions
If your host is running a Debian based distribution (Ubuntu, Debian, Mint) you can install the Observe Agent. 

**Install the Observe Agent**

Install the `observe-agent` package. You’ll need to first add the Observe debian repository to your trusted depositories in your `sources.list.d` file.

```markdown
echo 'deb [trusted=yes] https://repo.observeinc.com/apt/ /' | sudo tee /etc/apt/sources.list.d/observeinc.list
sudo apt update
sudo apt install observe-agent
```

To validate that the agent is installed correctly, you can run the `version` command. 

```markdown
observe-agent version
```

**Configure the Observe Agent**

Open the agent config file `/etc/observe-agent/observe-agent.yaml` with superuser permissions which will allow you to edit and save changes to the file.

```yaml
sudo vim /etc/observe-agent/observe-agent.yaml
```

Add your Observe token and collection url to the config below and save the file. 

```markdown
# Observe data token
token: "${OBSERVE_TOKEN?}"

# Target Observe collection url
observe_url: "https://${OBSERVE_CUSTOMER?}.collect.observeinc.com"

host_monitoring:
  enabled: true
  logs: 
    enabled: true
  metrics:
    enabled: true

# otel_config_overrides:
#   exporters:
#     debug:
#       verbosity: detailed
#       sampling_initial: 5
#       sampling_thereafter: 200
#   service:
#     pipelines:
#       # This will override the existing metrics/host_monitoring pipeline and output to stdout debug instead
#       metrics/host_monitoring:
#         receivers: [hostmetrics/host-monitoring]
#         processors: [memory_limiter]
#         exporters: [debug]
```

**Start the Observe Agent**

Now that the configuration is in place, you can start the agent with the following command

```markdown
sudo systemctl enable --now observe-agent
```

#### Check Status
```markdown
observe-agent status
```

#### Uninstall
```markdown
sudo systemctl stop observe-agent
sudo apt-get purge observe-agent
```

### Non-Debian Distribution
For any other distributions, run the following command.

```
curl https://raw.githubusercontent.com/observeinc/host-quickstart-configuration/main/opentelemetry/linux/observe_otel_install.sh | bash -s -- --observe_collection_endpoint "${OBSERVE_COLLECTION_ENDPOINT}" --observe_token "${OBSERVE_TOKEN}"
```

#### Check Status
```
journalctl -u otelcol-contrib -f
```

#### Uninstall
```
curl https://raw.githubusercontent.com/observeinc/host-quickstart-configuration/main/opentelemetry/linux/observe_otel_install.sh | bash -s -- --observe_collection_endpoint "${OBSERVE_COLLECTION_ENDPOINT}" --observe_token "${OBSERVE_TOKEN}" --uninstall
```

## Windows Install
This script assumes that you are executing the script with admin privileges, and that tar is installed and accessible from powershell

```
[Net.ServicePointManager]::SecurityProtocol = "Tls, Tls11, Tls12, Ssl3"; Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/observeinc/host-quickstart-configuration/main/opentelemetry/windows/observe_otel_install.ps1" -outfile .\agents.ps1; .\agents.ps1 -observe_token "${OBSERVE_TOKEN}" -OBSERVE_COLLECTION_ENDPOINT  "${OBSERVE_COLLECTION_ENDPOINT}"

```

**Check Status**
```
Get-Service OpenTelemetry
```

## Mac

Monitoring of a desktop environment is easiest to achieve using a precompiled binary.

**Create a new directory and download configuration file**
```
mkdir mac_monitor

curl -O https://raw.githubusercontent.com/observeinc/host-quickstart-configuration/main/opentelemetry/mac/config.yaml
```

**Create a new directory, download binary and move into /usr/local/bin:**
**M1**
```
mkdir binary_download

cd binary_download

curl --proto '=https' --tlsv1.2 -fOL https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.92.0/otelcol-contrib_0.92.0_darwin_arm64.tar.gz

tar -xvf otelcol-contrib_0.92.0_darwin_arm64.tar.gz

sudo mv otelcol-contrib /usr/local/bin/

```

**Set relevant environment variables and run binary:**

```
export OBSERVE_COLLECTION_ENDPOINT="${OBSERVE_COLLECTION_ENDPOINT?}"; 
export OBSERVE_TOKEN="${OBSERVE_TOKEN?}"; 
export CONFIG_PATH=[THE_FULL_PATH_TO_config.yaml]; 
otelcol-contrib --config $CONFIG_PATH
```

**Uninstall:**

```
sudo rm /usr/local/bin/otelcol-contrib
```

References:

https://opentelemetry.io/docs/collector/configuration/#environment-variables

https://opentelemetry.io/docs/collector/installation/#macos

https://github.com/open-telemetry/opentelemetry-collector-releases/releases
