#!/bin/bash
# Default values
OBSERVE_COLLECTION_ENDPOINT=""
OBSERVE_TOKEN=""
BRANCH="main"
UNINSTALL=""

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
      shift 2
      ;;
    *)
      echo "Unknown parameter: $1" >&2
      exit 1
      ;;
  esac
done

# Check if --host and --token are provided
if [ -z "$OBSERVE_COLLECTION_ENDPOINT" ] || [ -z "$OBSERVE_TOKEN" ]; then
  echo "Usage: $0 --observe_collection_endpoint OBSERVE_COLLECTION_ENDPOINT --observe_token OBSERVE_TOKEN"
  exit 1
fi

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
    wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.90.1/otelcol-contrib_0.90.1_linux_amd64.deb
    sudo dpkg -i otelcol-contrib_0.90.1_linux_amd64.deb
}

# create a configuration file with vars
# https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/examples/fault-tolerant-logs-collection/otel-col-config.yaml
# https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/extension/storage/filestorage
# https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/receiver/hostmetricsreceiver/README.md
# https://github.com/open-telemetry/opentelemetry-collector-contrib/blob/main/processor/attributesprocessor/README.md
create_config(){
    sudo mkdir -p /var/lib/otelcol/file_storage/receiver
    #sudo mkdir -p /var/lib/otelcol/file_storage/output
    sudo chown otelcol-contrib /var/lib/otelcol/file_storage/receiver 
    #sudo chmod u+rw /var/lib/otelcol/file_storage/output

    sudo mv "$config_file" "$config_file.ORIG"
    sudo tee "$config_file" > /dev/null << EOT
extensions:
  health_check:
  file_storage:
    directory: /var/lib/otelcol/file_storage/receiver
connectors:
  count:
receivers:
  otlp:  # Define the "otlp" receiver
    protocols:
      http:
        max_request_body_size: 10485760

  filestats:
    include: /etc/otelcol-contrib/config.yaml
    collection_interval: 240m
    initial_delay: 60s

  filelog/config:
    include: [ /etc/otelcol-contrib/config.yaml ]
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
          system.cpu.frequency:
            enabled: true
          system.cpu.logical.count:
            enabled: true
          system.cpu.physical.count:
            enabled: true
      load:
      memory:
        metrics:
          system.memory.utilization:
            enabled: true
          system.linux.memory.available:
            enabled: true
          system.memory.limit:
            enabled: true
      disk:
      filesystem:
        metrics:
          system.filesystem.utilization:
            enabled: true
      network:
        metrics:
          system.network.conntrack.count:
            enabled: true
          system.network.conntrack.max:
            enabled: true
      paging:
        metrics:
          system.paging.utilization:
            enabled: true
      processes:
      process:
        metrics:
          process.context_switches:
            enabled: true
          process.cpu.utilization
          process.disk.operations
          process.handles
          process.memory.utilization
          process.open_file_descriptors
          process.paging.faults
          process.signals_pending
          process.threads

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

  journald:
    units:
      - cron
      - ssh
      - systemd-networkd
      - systemd-resolved
      - systemd-login
      - multipathd
      - systemd-user-sessions
      - ufw

    priority: info

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
      hostname_sources:
      resource_attributes:
        host.id:
          enabled: false
        os.type:
           enabled: true       
        host.arch:
          enabled: true
        host.name:
          enabled: true
        host.ip:
          enabled: true
        host.mac:
          enabled: true
        host.cpu.vendor.id:
          enabled: true
        host.cpu.family:
          enabled: true
        host.cpu.model.id:
          enabled: true
        host.cpu.model.name:
          enabled: true
        host.cpu.stepping:
          enabled: true
        host.cpu.cache.l2.size:
          enabled: true
        os.description:
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
          enabled: false

exporters:
  logging:
    # loglevel: "DEBUG"
  otlphttp:
    endpoint: "${OBSERVE_COLLECTION_ENDPOINT}/v2/otel"
    headers:
      authorization: "Bearer ${OBSERVE_TOKEN}"
  otlp/custom:
    endpoint: "${OBSERVE_COLLECTION_ENDPOINT}:443/v2/otel"
    headers:
      authorization: "Bearer ${OBSERVE_TOKEN}"
    sending_queue:
      storage: file_storage/otlpoutput

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

    logs/journal:
      receivers: [otlp, journald]
      processors: [memory_limiter, transform/truncate, resourcedetection, resourcedetection/cloud, batch]
      exporters: [logging, otlphttp]

  extensions: [health_check, file_storage]

EOT

}

# uninstall debian
uninstall_apt(){
    sudo systemctl stop otelcol-contrib
    sudo rm -rf "$destination_dir"
    sudo dpkg --purge otelcol-contrib

}

# install rhel
install_yum(){
    sudo yum -y install wget systemctl
    wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.90.1/otelcol-contrib_0.90.1_linux_amd64.rpm
    sudo rpm -ivh otelcol-contrib_0.90.1_linux_amd64.rpm
}

# uninstall rhel
uninstall_yum(){
    sudo systemctl stop otelcol-contrib
    sudo rm -rf "$destination_dir"
    sudo yum remove otelcol-contrib -y
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
        destination_dir="/etc/otelcol-contrib"
        config_file="${destination_dir}/config.yaml"

        if [ "$UNINSTALL" = "true" ]; then
          uninstall_apt
          sudo apt -y remove acl
        else
          
          install_apt
          
          sudo apt-get install acl -y
          
          create_config

          sudo adduser otelcol-contrib systemd-journal
          # sudo su -s /bin/bash -c 'journalctl --lines 5' otelcol-contrib
          sudo systemctl enable otelcol-contrib
          sudo systemctl restart otelcol-contrib
          #journalctl -u otelcol-contrib -f


          sudo setfacl -Rm u:otelcol-contrib:rX /var/log
        fi
    ;;
esac




