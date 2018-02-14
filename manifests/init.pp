# Redis
#
# Main Class, the only class that needs to be defined
#
# @param _ensure [String] Whether to install the Redis package(s)
# @param package_ensure [String] Whether to install the Redis package(s)
# @param package_name [String, Array] Sting or Array with the package name to install
# @param lookuo_prefix [String] Prefix is optionally prepended to "redis::instances" and "redis::sentinel::pools"
#     for looking up redis or sentinel pool instance definitions in hiera
class redis (
  Enum['absent', 'present'] $ensure = 'present',
  String $package_ensure = 'latest',
  Variant[String, Array] $package_name = redis,
  String $lookup_prefix = '',
) {
  contain redis::config
  contain redis::install
  contain redis::sentinel

  Class['::redis::install']
  -> Class['::redis::config']
  -> Class['::redis::sentinel']

  if $ensure == 'present' {
    $instances = lookup("${lookup_prefix}redis::instances", { merge => deep, default_value => {} })
    create_resources(redis::instance, $instances)
  }

}
