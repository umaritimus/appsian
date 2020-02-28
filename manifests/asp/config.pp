# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include appsian::asp::config
class appsian::asp::config (
  String $domain = lookup('pia_domain_name'),
  String $ps_config_home = lookup('ps_config_home'),
  String $ps_home = lookup('ps_home_location'),
  Optional[Variant[Enum['active', 'inactive'], String[1]]] $status = 'inactive',
) {

  file { [
    "${ps_config_home}/webserv/${domain}/servers/PIA/greyheller",
    "${ps_config_home}/webserv/${domain}/servers/PIA/greyheller/fw",
    "${ps_config_home}/webserv/${domain}/servers/PIA/greyheller/fw/state"
    ] :
    ensure  => directory,
  }

  case $status {
    'inactive' : {
      file { "${ps_config_home}/webserv/${domain}/servers/PIA/greyheller/fw/state/inactive.txt" :
        ensure  => 'file',
        require => [ File["${ps_config_home}/webserv/${domain}/servers/PIA/greyheller/fw/state"] ],
      }
    }
    default : {
      file { "${ps_config_home}/webserv/${domain}/servers/PIA/greyheller/fw/state/inactive.txt" :
        ensure  => 'absent',
        require => [ File["${ps_config_home}/webserv/${domain}/servers/PIA/greyheller/fw/state"] ],
      }
    }
  }
}
