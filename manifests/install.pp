# @api private
# This class handles the installation. Avoid modifying private classes.
# This will also stop and disable the default redis instance
class redis::install inherits redis {
  if $redis::package_ensure != 'absent' {
    package { $redis::package_name:
      ensure => $redis::package_ensure
    }
    service {'redis':
      ensure => 'stopped',
      enable => false
    }
  } else {
    package { $redis::package_name:
      ensure => 'absent'
    }
  }
}