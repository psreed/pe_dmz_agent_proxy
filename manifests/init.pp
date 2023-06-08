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
# @param enable_firewall_config
# - Enable configuration requirements for firewalld based firewall
#
class pe_dmz_agent_proxy (
  String $upstream_puppet_server  = 'pe.example.com',
  String $upstream_comply_server  = 'comply.example.com',
  Boolean $enable_puppet          = true,
  Boolean $enable_pxp             = true,
  Boolean $enable_comply          = false,
  Boolean $enable_selinux_config  = true,
  Boolean $enable_firewall_config = true,
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

  # Firewalld configuration
  if $enable_firewall_config {
    Firewall {
      proto    => 'tcp',
      action   => 'accept',
      provider => 'ip6tables',
      before   => Class['nginx'],
    }
    if $enable_puppet {
      firewall { 'Allow Puppet Agent TCP 8140 Inbound': dport => 8140, }
    }
    if $enable_pxp {
      firewall { 'Allow Puppet Orchestrator Agent TCP 8142 Inbound': dport => 8142, }
    }
    if $enable_comply {
      firewall { 'Allow Puppet Comply TCP 30303 Inbound': dport => 30303, }
    }
  }

  # SELinux configuration
  if $enable_selinux_config {
    selboolean { ['httpd_setrlimit','nis_enabled','httpd_can_network_connect']:
      persistent => true,
      value      => on,
      before     => Class['nginx'],
    }

    if $enable_puppet {
      selinux::port { 'tcp_socket_8140':
        ensure   => present,
        port     => 8140,
        seltype  => 'puppet_port_t',
        protocol => 'tcp',
        before   => Class['nginx'],
      }
    }
    if $enable_pxp {
      selinux::port { 'tcp_socket_8142':
        ensure   => present,
        port     => 8142,
        seltype  => 'puppet_port_t',
        protocol => 'tcp',
        before   => Class['nginx'],
      }
    }
    if $enable_comply {
      selinux::port { 'tcp_socket_30303':
        ensure   => present,
        port     => 30303,
        seltype  => 'puppet_port_t',
        protocol => 'tcp',
        before   => Class['nginx'],
      }
    }
  }
}
