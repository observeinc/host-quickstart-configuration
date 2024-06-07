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

Configure the Observe Agent with the following command. Replace OBSERVE_TOKEN and OBSERVE_COLLECTION_ENDPOINT with the appropriate values and run on each host.
```markdown
sudo observe-agent init-config --token ${OBSERVE_TOKEN?} --observe_url ${OBSERVE_COLLECTION_ENDPOINT?}
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

### RedHat-based Distributions
If your host is running a RedHat based distribution (Amazon Linux, CentOS, RedHat) you can install the Observe Agent. 

**Install the Observe Agent**

Install the `observe-agent` package. You’ll need to first add the Observe yum repository to your trusted repositories in your `yum.repos.d` folder.

```markdown
echo '[fury]
name=Gemfury Private Repo
baseurl=https://yum.fury.io/observeinc/
enabled=1
gpgcheck=0' | sudo tee /etc/yum.repos.d/fury.repo

sudo yum install observe-agent
```

To validate that the agent is installed correctly, you can run the `version` command. 

```markdown
observe-agent version
```

**Configure the Observe Agent**

Configure the Observe Agent with the following command. Replace OBSERVE_TOKEN and OBSERVE_COLLECTION_ENDPOINT with the appropriate values and run on each host.
```markdown
sudo observe-agent init-config --token ${OBSERVE_TOKEN?} --observe_url ${OBSERVE_COLLECTION_ENDPOINT?}
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
sudo yum erase observe-agent -y
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
