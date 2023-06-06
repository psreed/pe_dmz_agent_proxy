# pe_dmz_agent_proxy
#
# @summary 
# - Create a Proxy for Puppet Agents to connect to an upstream LB or Puppet Server
#
# @param upstream_puppet_server 
# - Server or Load Balancer serving Puppet Agent and PXP requests
#
# @param server_name
# - Name for the dmz proxy node
#
# @param enable_puppet 
# - Enable proxy for Puppet Agent connections
#
# @param enable_pxp 
# - Enable proxy for PXP/PCP (Orchestrator) Agent connections
#
class pe_dmz_agent_proxy (
  String $upstream_puppet_server  = 'pe.example.com',
  String $server_name             = 'dmz_proxy.example.com',
  Boolean $enable_puppet          = true,
  Boolean $enable_pxp             = true,
) {
  # Add nginx with proxy configuration
  include nginx

  if ($enable_puppet) {
    nginx::resource::upstream { "${upstream_puppet_server}_8140":
      members => {
        "${upstream_puppet_server}:8140" => {
          server => $upstream_puppet_server,
          port   => 8140,
          weight => 1,
        },
      },
    }
    nginx::resource::server { "${server_name}_8140":
      proxy => "${upstream_puppet_server}_8140",
    }
  }
  if ($enable_pxp) {
    nginx::resource::upstream { "${upstream_puppet_server}_8142":
      members => {
        "${upstream_puppet_server}:8142" => {
          server => $upstream_puppet_server,
          port   => 8142,
          weight => 1,
        },
      },
    }
    nginx::resource::server { "${server_name}_8142":
      proxy => "${upstream_puppet_server}_8142",
    }
  }
}
