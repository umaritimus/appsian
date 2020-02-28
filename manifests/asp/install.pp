# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include appsian::asp::install
class appsian::asp::install (
  String $domain = lookup('pia_domain_name'),
  String $ps_config_home = lookup('ps_config_home'),
  String $ps_home = lookup('ps_home_location'),
  String $java_home = lookup('jdk_location'),
  Optional[Variant[Enum['present', 'absent'], String[1]]] $ensure = $appsian::asp::ensure,
  Optional[String[1]] $package = $appsian::asp::package
) {

  if ($ensure in [ 'present']) {

    $temp = regsubst("${::env_temp}/appsian", '(/|\\\\)', '\\', 'G')

    file { $temp :
      ensure => directory,
    }

    exec { "Expand ${package}" :
      command  => Sensitive("Expand-Archive -Path \"${package}\" -DestinationPath \"${temp}\" -Force"),
      provider => powershell,
      require  => [ File[$temp] ],
    }

    exec { 'Deploy Application server ASP components' :
      command   => Sensitive("
        Get-Service PsftApp* | Stop-Service -Force | Out-Null;
        & \"${temp}/ERP_Firewall/AppServer/Windows/setup.exe\" `
          /log=\"${temp}/appserver-installation.log\" `
          /verysilent `
          /suppressmsgboxes `
          /pshome=\"${ps_config_home}\";

        Start-Sleep -Seconds 30

        If ( $( Try { Test-Path \"${temp}/appserver-installation.log\" -ErrorAction Stop } Catch { \${False} } ) ) {
          \${successcount} = (
            (Select-String -Path \"${temp}/appserver-installation.log\" -Pattern \"Installation\\sprocess\\ssucceeded\\.\").Matches.Count
          )
          If (\${successcount} -eq 0) { 
            Exit 1
          }
        } Else {
          Exit 2
        }

        If ( $( Try { Test-Path \"${ps_config_home}/appserv/${domain}/CACHE\" -ErrorAction Stop } Catch { \${False} } ) ) {
          Get-ChildItem -Path \"${ps_config_home}/appserv/${domain}/CACHE\" -Recurse -ErrorAction SilentlyContinue | 
          Remove-Item -Recurse -Force -ErrorAction SilentlyContinue ;
        }
        "),
      provider  => powershell,
      logoutput => true,
      require   => [ Exec["Expand ${package}"] ],
    }

    exec { 'Deploy Web server ASP components' :
      environment => [ "PATH=${regsubst("${java_home}/bin" ,'/', '\\\\', 'G')};\${Env:PATH}" ],
      command     => Sensitive("
        Get-Service PsftPIA* | Stop-Service -Force | Out-Null;

        If (-not \$( Try { 
            Test-Path `
              -Path \"${ps_config_home}/webserv/${domain}/applications/peoplesoft/PORTAL.war/WEB-INF/lib/psjoa.jar\" `
              -ErrorAction SilentlyContinue 
            } Catch { \${False} } ) 
        ) {
          Copy-Item `
            -Path \"${ps_home}/class/psjoa.jar\" `
            -Destination \"${ps_config_home}/webserv/${domain}/applications/peoplesoft/PORTAL.war/WEB-INF/lib\" `
            -Force
        }
                  
        & \"${temp}/ERP_Firewall/WebServer/Windows/gh_firewall_web.exe\" `
          /log=\"${temp}/webserver-installation.log\" `
          /verysilent `
          /suppressmsgboxes `
          /pshome=\"${ps_config_home}\" `
          /piadomain=\"${domain}\"

        Start-Sleep -Seconds 30

        If ( \$( Try { Test-Path \"${temp}/webserver-installation.log\" -ErrorAction Stop } Catch { \${False} } ) ) {
          \${successcount} = (
            (Select-String -Path \"${temp}/webserver-installation.log\" -Pattern \"Installation\\sprocess\\ssucceeded\\.\").Matches.Count
          )
          If (\${successcount} -eq 0) { 
            Exit 1
          }
        } Else {
          Exit 2
        }

        If ( \$( Try { 
              Test-Path \"${ps_config_home}/webserv/${domain}/applications/peoplesoft/PORTAL.war/${domain}/cache\" `
              -ErrorAction SilentlyContinue 
            } Catch { \${False} } ) 
        ) {
          Get-ChildItem `
            -Path \"${ps_config_home}/webserv/${domain}/applications/peoplesoft/PORTAL.war/${domain}/cache\" `
            -Recurse `
            -ErrorAction SilentlyContinue | 
          Remove-Item -Recurse -Force -ErrorAction SilentlyContinue ;
        }

        "),
      provider    => powershell,
      require     => [ Exec["Expand ${package}"], Exec['Deploy Application server ASP components'] ],
    }

    exec { "Delete ${temp} Directory" :
      command   =>  Sensitive(@("EOT")),
          New-Item -Path ${regsubst("\'${::env_temp}/empty\'", '(/|\\\\)', '\\', 'G')} -Type Directory -Force

          Start-Process `
            -FilePath "C:\\windows\\system32\\Robocopy.exe" `
            -ArgumentList @( `
              ${regsubst("\'${::env_temp}/empty\'", '(/|\\\\)', '\\', 'G')}, `
              ${regsubst("\'${temp}\'" ,'/', '\\\\', 'G')}, `
              "/E /PURGE /NOCOPY /MOVE /NFL /NDL /NJH /NJS > nul" `
            ) `
            -Wait `
            -NoNewWindow | Out-Null

          Get-Item -Path ${regsubst("\'${temp}\'" ,'/', '\\\\', 'G')} -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse
        |-EOT
      provider  => powershell,
      logoutput => true,
      require  => [ Exec['Deploy Application server ASP components'], Exec['Deploy Web server ASP components'] ],
    }

  }

}
