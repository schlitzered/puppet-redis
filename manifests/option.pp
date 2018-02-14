# @api private
# This class handles the configuration file. Avoid modifying private classes.
define redis::option (
  String $option,
  $value,
  $port,
  $auth = '',
) {
  if $auth == '' {
    $command = "/usr/bin/redis_config_set --port ${port}"
  } else {
    $command = "/usr/bin/redis_config_set --auth ${auth} --port ${port}"
  }

  exec {"redis_config_set${title}":
    command => "${command} set --option ${option} --value '${value}'",
    unless  => "${command} check --option ${option} --value '${value}'"
  }
}