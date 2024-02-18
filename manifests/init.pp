# pe_dmz_agent_proxy
#
# @summary 
# - Create a Proxy for Puppet Agents to connect to an upstream LB or Puppet Server
#
# @param upstream_puppet_server 
# - Server or Load Balancer serving Puppet Agent and PXP requests
#
# @param upstream_comply_server 
# - Server or Load Balancer serving Puppet Comply dashboard
#
# @param enable_puppet 
# - Enable proxy for Puppet Agent connections
#
# @param enable_pxp 
# - Enable proxy for PXP/PCP (Orchestrator) Agent connections
#
# @param enable_comply
# - Enable proxy for Comply CISCAT download and report submission
#
# @param enable_selinux_config
# - Enable configuration requirements for SELinux 
#
# @param enable_iptables_config
# - Enable configuration for IPTables based firewalls. Typically for RHEL 7 and variants.
#
# @param enable_firewalld_config
# - Enable configuration requirements for firewalld based firewalls. Typically for RHEL 8+ and variants.
# 
# @param enable_ufw_config
# - Enable configuration requirements for UFW based firewalls. Typically for Ubuntu and Debian system types.
#   Note: UFW support assumes using the forge module for UFW found at:
#   https://forge.puppet.com/modules/kogitoapp/ufw/readme
#   As of 2024-02-18: This module is not yet supported with Puppet 8, however it seems to work fine and no alternative is yet available.
#
class pe_dmz_agent_proxy (
  String $upstream_puppet_server   = 'pe.example.com',
  String $upstream_comply_server   = 'comply.example.com',
  Boolean $enable_puppet           = true,
  Boolean $enable_pxp              = true,
  Boolean $enable_comply           = false,
  Boolean $enable_selinux_config   = false,
  Boolean $enable_iptables_config  = false,
  Boolean $enable_firewalld_config = false,
  Boolean $enable_ufw_config       = false,

) {
  # NGINX Configuration
  class { 'nginx':
    stream                   => true,
    stream_log_format        => {
      'customproxy' => '$remote_addr [$time_local] $status $bytes_sent "$upstream_addr" "$upstream_bytes_sent" "$upstream_bytes_received" "$upstream_connect_time" ', #lint:ignore:140chars
    },
    stream_custom_format_log => 'customproxy',
  }

  # Proxy for Puppet Agent (TCP Port 8140)
  if $enable_puppet {
    nginx::resource::streamhost { 'proxy_stream_8140':
      listen_port => 8140,
      proxy       => "${upstream_puppet_server}:8140",
    }
  }

  # Proxy for Puppet Orchestrator PXP-Agent (TCP Port 8142)
  if $enable_pxp {
    nginx::resource::streamhost { 'proxy_stream_8142':
      listen_port => 8142,
      proxy       => "${upstream_puppet_server}:8142",
    }
  }

  # Proxy for Puppet Comply (TCP Port 30303)
  if $enable_comply {
    nginx::resource::streamhost { 'proxy_stream_30303':
      listen_port => 30303,
      proxy       => "${upstream_comply_server}:30303",
    }
  }

  # Firewall (iptables) configuration
  if $enable_iptables_config {
    Firewall {
      proto    => 'tcp',
      action   => 'accept',
      before   => Class['nginx'],
    }
    if $enable_puppet {
      firewall { '001 Allow Puppet Agent TCP 8140 Inbound': dport => 8140, }
    }
    if $enable_pxp {
      firewall { '001 Allow Puppet Orchestrator Agent TCP 8142 Inbound': dport => 8142, }
    }
    if $enable_comply {
      firewall { '001 Allow Puppet Comply TCP 30303 Inbound': dport => 30303, }
    }
  }

  # Firewalld configuration
  if $enable_firewalld_config {
    Firewalld_port {
      ensure   => present,
      protocol => 'tcp',
      zone     => 'public',
      before   => Class['nginx'],
    }
    if $enable_puppet {
      firewalld_port { 'Allow Puppet Agent TCP 8140 Inbound': port => 8140, }
    }
    if $enable_pxp {
      firewalld_port { 'Allow Puppet Orchestrator Agent TCP 8142 Inbound': port => 8142, }
    }
    if $enable_comply {
      firewalld_port { 'Allow Puppet Comply TCP 30303 Inbound': port => 30303, }
    }
  }

  # UFW configuration
  if $enable_ufw_config {
    Ufw_rule {
      ensure       => present,
      action       => 'allow',
      direction    => 'in',
      interface    => undef,
      proto        => 'tcp',
    }
    if $enable_puppet {
      ufw_rule { 'Allow Puppet Agent TCP 8140 Inbound': to_ports_app => 8140, }
    }
    if $enable_pxp {
      ufw_rule { 'Allow Puppet Orchestrator Agent TCP 8142 Inbound': to_ports_app => 8142, }
    }
    if $enable_comply {
      ufw_rule { 'Allow Puppet Comply TCP 30303 Inbound': to_ports_app => 30303, }
    }
  }

  # SELinux configuration
  if $enable_selinux_config {
    selboolean { ['httpd_setrlimit','nis_enabled','httpd_can_network_connect']:
      persistent => true,
      value      => on,
      before     => Class['nginx'],
    }

    Selinux::Port {
      ensure   => present,
      seltype  => 'puppet_port_t',
      protocol => 'tcp',
      before   => Class['nginx'],
    }

    if $enable_puppet {
      selinux::port { 'tcp_socket_8140': port => 8140, }
    }
    if $enable_pxp {
      selinux::port { 'tcp_socket_8142': port => 8142, }
    }
    if $enable_comply {
      selinux::port { 'tcp_socket_30303': port => 30303, }
    }
  }
}
