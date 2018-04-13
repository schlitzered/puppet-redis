# @api private
# This class handles the configuration file. Avoid modifying private classes.
class redis::config inherits redis {
  if $redis::ensure == 'present' {
    $_dir_ensure = 'directory'
    $_file_ensure = 'file'
    $_link_ensure = 'link'
    $_purge = false
    $_recurse = false
  } else {
    $_dir_ensure = $redis::ensure
    $_file_ensure = $redis::ensure
    $_link_ensure = $redis::ensure
    $_purge = true
    $_recurse = true
  }

  file { '/etc/redis/':
    ensure => $_dir_ensure,
    group  => 'redis',
    owner  => 'redis',
  }
  file { '/etc/systemd/system/redis@.service':
    ensure => $_file_ensure,
    group  => 'redis',
    owner  => 'redis',
    source => 'puppet:///modules/redis/redis@.service',
    notify => Exec['redis_reload_systemd']
  }
  file { '/etc/systemd/system/redis_sentinel.service':
    ensure => $_file_ensure,
    group  => 'redis',
    owner  => 'redis',
    source => 'puppet:///modules/redis/redis_sentinel.service',
    notify => Exec['redis_reload_systemd']
  }
  exec { 'redis_reload_systemd':
    refreshonly => true,
    command     => '/bin/systemctl daemon-reload'
  }
  file { '/usr/bin/redis_config_set':
    ensure => $_file_ensure,
    group  => 'redis',
    owner  => 'redis',
    mode   => '0555',
    source => 'puppet:///modules/redis/redis_config_setter.py'
  }
  file { '/usr/bin/redis_sentinel':
    ensure => $_file_ensure,
    group  => 'redis',
    owner  => 'redis',
    mode   => '0555',
    source => 'puppet:///modules/redis/redis_sentinel.py'
  }
  file { '/usr/bin/redis_sentinel_cleanup':
    ensure => $_file_ensure,
    group  => 'redis',
    owner  => 'redis',
    mode   => '0555',
    source => 'puppet:///modules/redis/redis_sentinel_cleanup.py'
  }
  file { '/usr/lib/tmpfiles.d/redis.conf':
    ensure  => $_dir_ensure,
    source => 'puppet:///modules/redis/tmpfiles.d.redis.conf'
  }
  file { '/var/log/redis/':
    ensure => $_dir_ensure,
    group  => 'redis',
    owner  => 'redis',
  }
  file { '/var/run/redis/':
    ensure => $_dir_ensure,
    group  => 'redis',
    owner  => 'redis',
  }
}