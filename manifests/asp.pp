# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include appsian::asp
class appsian::asp (
  Optional[String[1]] $package = undef,
  Optional[Variant[Enum['present', 'absent'], String[1]]] $ensure = 'absent'
) {
  contain ::appsian::asp::install
  contain ::appsian::asp::config

  Class['::appsian::asp::install']
  -> Class['::appsian::asp::config']
}
