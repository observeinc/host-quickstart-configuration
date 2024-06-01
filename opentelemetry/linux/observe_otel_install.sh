#!/bin/bash
# Default values
OBSERVE_COLLECTION_ENDPOINT=""
OBSERVE_TOKEN=""
BRANCH="main"
UNINSTALL=""

apt_filelog_dir="/var/lib/otelcol-contrib/file_storage/receiver"
apt_destination_dir="/etc/otelcol-contrib"
apt_config_file="${apt_destination_dir}/config.yaml"
service="otelcol-contrib"; 
otel_version="0.90.1"
package="${service}_${otel_version}_linux_amd64.deb"
version_string="v${otel_version}/${package}"
spacer="################################################################"

# parse input flags
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --observe_collection_endpoint)
      OBSERVE_COLLECTION_ENDPOINT="$2"
      OBSERVE_COLLECTION_ENDPOINT=$(echo "$OBSERVE_COLLECTION_ENDPOINT" | sed 's/\/\?$//')
      shift 2
      ;;
    --observe_token)
      OBSERVE_TOKEN="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$3"
      shift 2
      ;;
    --uninstall)
      UNINSTALL="true"
      break
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      exit 1
      ;;
  esac
done

check_host_token(){
  # Check if --host and --token are provided
  if [ -z "$OBSERVE_COLLECTION_ENDPOINT" ] || [ -z "$OBSERVE_TOKEN" ]; then
    echo "Usage: $0 --observe_collection_endpoint OBSERVE_COLLECTION_ENDPOINT --observe_token OBSERVE_TOKEN"
    exit 1
  fi
}

# what os are we on
get_os(){
    if [ -f /etc/os-release ]; then
        . /etc/os-release

        OS=$( echo "${ID}" | tr '[:upper:]' '[:lower:]')
        CODENAME=$( echo "${VERSION_CODENAME}" | tr '[:upper:]' '[:lower:]')
    elif lsb_release &>/dev/null; then
        OS=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
        CODENAME=$(lsb_release -cs)
    else
        OS=$(uname -s)
    fi

    echo $OS
}

# debian install
install_apt(){
    sudo apt-get -y install wget systemctl acl
    wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/$version_string
    sudo dpkg -i $package
}

# create a configuration file with vars
create_config(){
    # Important - file_storage extension needs directory created
    sudo mkdir -p "${apt_filelog_dir}"

    sudo chown $service "${apt_filelog_dir}"

    sudo adduser $service systemd-journal
    sudo setcap 'cap_dac_read_search=ep' /usr/bin/$service

    sudo mv "$apt_config_file" "$apt_config_file.ORIG"
    sudo tee "$apt_config_file" > /dev/null << EOT
extensions:
  health_check:
  file_storage:
    directory: ${apt_filelog_dir}
connectors:
  count:
receivers:
  otlp:  # Define the "otlp" receiver
    protocols:
      http:
        max_request_body_size: 10485760

  filestats:
    include: /etc/${service}/config.yaml
    collection_interval: 240m
    initial_delay: 60s

  filelog/config:
    include: [ /etc/${service}/config.yaml ]
    start_at: beginning
    poll_interval: 5m
    multiline:
      line_end_pattern: ENDOFLINEPATTERN

  prometheus/internal:
    config:
      scrape_configs:
        - job_name: 'otel-collector'
          scrape_interval: 5s
          static_configs:
            - targets: ['0.0.0.0:8888']

  hostmetrics:
    collection_interval: 60s
    scrapers:
      cpu:
        metrics:
          system.cpu.utilization:
            enabled: true
      load:
      memory:
        metrics:
          system.memory.utilization:
            enabled: true
      disk:
      filesystem:
        metrics:
          system.filesystem.utilization:
            enabled: true
      network:
      paging:
        metrics:
          system.paging.utilization:
            enabled: true

  filelog:
    include: [/var/log/**/*.log, /var/log/syslog]
    include_file_path: true
    storage: file_storage
    retry_on_failure:
      enabled: true
    max_log_size: 4MiB
    operators:
      - type: filter
        expr: 'body matches "otel-contrib"'

processors:
  
  transform/truncate:
    log_statements:
      - context: log
        statements:
          - truncate_all(attributes, 2047)
          - truncate_all(resource.attributes, 2047)

  memory_limiter:
    check_interval: 1s
    limit_percentage: 20
    spike_limit_percentage: 5
  
  batch:
  
  resourcedetection:
    detectors: [env, system]
    system:
      hostname_sources: ["os"]
      resource_attributes:
        host.id:
          enabled: true
  
  resourcedetection/cloud:
    detectors: ["gcp", "ec2", "azure"]
    timeout: 2s
    override: false

  resourcedetection/barebones:
    detectors: [env, system]
    system:
      hostname_sources: ["os"]
      resource_attributes:
        host.id:
          enabled: true
        host.name:
          enabled: false
        os.type:
          enabled: true

exporters:
  logging:
    # loglevel: "DEBUG"
  otlphttp:
    endpoint: "${OBSERVE_COLLECTION_ENDPOINT}/v2/otel"
    headers:
      authorization: "Bearer ${OBSERVE_TOKEN}"

service:
  pipelines:
    
    metrics:
      receivers: [hostmetrics, prometheus/internal,count]
      processors: [memory_limiter, resourcedetection, resourcedetection/cloud, batch]
      exporters: [logging, otlphttp]

    metrics/filestats:
       receivers: [filestats]
       processors: [resourcedetection, resourcedetection/cloud]
       exporters: [logging, otlphttp]
       
    logs/config:
       receivers: [filelog/config]
       processors: [memory_limiter, transform/truncate, resourcedetection, resourcedetection/cloud, batch]
       exporters: [logging, otlphttp]
       
    logs:
      receivers: [otlp, filelog]
      processors: [memory_limiter, transform/truncate, resourcedetection, resourcedetection/cloud, batch]
      exporters: [logging, otlphttp, count]

  extensions: [health_check, file_storage]

EOT

}

# uninstall debian
uninstall_apt(){
  
      printf "\n %s \n uninstalling....\n" $spacer
      sudo systemctl stop $service
      sudo systemctl disable $service

      sudo rm -rf "$apt_destination_dir"
      sudo dpkg --purge $service
      sudo rm -rf "$apt_filelog_dir"
      
      #sudo rm /etc/systemd/system/$service
      sudo systemctl daemon-reload 
      sudo systemctl reset-failed

      sudo deluser $service systemd-journal
      sudo setcap -r 'cap_dac_read_search=ep' /usr/bin/$service
      printf "\n uninstall complete \n %s \n" $spacer

}

# install rhel
install_yum(){
    sudo yum -y install wget systemctl
    wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.90.1/otelcol-contrib_0.90.1_linux_amd64.rpm
    sudo rpm -ivh otelcol-contrib_0.90.1_linux_amd64.rpm
}

# uninstall rhel
uninstall_yum(){
    sudo systemctl stop $service
    sudo rm -rf "$destination_dir"
    sudo yum remove $service -y
}

OS=$(get_os)

# do install / uninstall
case ${OS} in
    amzn|amazonlinux|rhel|centos)
        destination_dir="/etc/otelcol-contrib"
        config_file="${destination_dir}/config.yaml"

        if [ "$UNINSTALL" = "true" ]; then
          uninstall_yum
          sudo yum remove acl -y
        else
          install_yum
          sudo yum install acl -y
          create_config
        fi
    ;;
    ubuntu|debian)
        printf "Uninstall = %s" "$UNINSTALL"
        if [[ "$UNINSTALL" == "true" ]]; then
          uninstall_apt
          sudo apt -y remove acl

        else
          check_host_token

          install_apt
          
          sudo apt-get install acl -y
          
          create_config

          sudo systemctl enable $service
          sudo systemctl restart $service

          sudo setfacl -Rm u:$service:rX /var/log
        fi
    ;;
esac




