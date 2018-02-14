# @api private
# This class manages redis sentinel, and the redis pools monitored by sentinel. This should always be created thru hiera.
# Parameters corespond to the respective redis sentinel parameters
# Changing sentinal base parameters always requires a sentinel restart.
# Adding, modifing or removing pools can be done on the fly.
#
# @param sentinels [Array] list of redis sentinel members, the first sentinel will be used to initialize the redis
#     replication, if not already done. all other sentinels will try to query the first sentinel to get the current
#     master & initialize there pool
class redis::sentinel (
  Enum['present', 'absent'] $ensure = 'absent',
  String $bind = '*',
  String $dir = '/tmp',
  String $logfile = '/var/log/redis/sentinel.log',
  Hash $pools = {},
  Integer $port = 26379,
  Enum['no', 'yes'] $protected_mode = 'no',
  String $announce_ip = '',
  Integer $announce_port = $redis::sentinel::port,
  Array $sentinels = ["${facts['networking']['ip']}:${redis::sentinel::port}"],
) inherits redis {

  if $ensure == 'present' {
    $_file_ensure = 'file'
    $_dir_ensure = 'directory'
  } else {
    $_file_ensure = $ensure
    $_dir_ensure = $ensure
  }

  file { '/etc/redis/sentinel.conf':
    ensure  => $_file_ensure,
    group   => 'redis',
    owner   => 'redis',
    replace => 'no'
  }

  concat { '/etc/redis/sentinel_pools.conf':
    ensure => $ensure,
    group  => 'redis',
    owner  => 'redis',
  }

  concat::fragment { 'redis_sentinel_main':
    target  => '/etc/redis/sentinel_pools.conf',
    content => template('redis/sentinel.erb'),
    order   => '00'
  }

  if $ensure == 'present' {

    $_pools = lookup("${::redis::lookup_prefix}redis::sentinel::pools", {merge => deep, default_value => {}})
    create_resources(redis::sentinel::pool, $_pools)

    if $announce_ip != '' {
      file_line { '$redis/sentinel_announce_ip':
        line     => "sentinel announce-ip \"${announce_ip}\"",
        match    => '^sentinel announce-ip.*',
        path     => '/etc/redis/sentinel.conf',
        multiple => true,
        notify   => Service['redis_sentinel']
      }
      file_line { '$redis/sentinel_announce_port':
        line     => "sentinel announce-port ${announce_port}",
        match    => '^sentinel announce-port.*',
        path     => '/etc/redis/sentinel.conf',
        multiple => true,
        notify   => Service['redis_sentinel']
      }
    }
    file_line { '$redis/sentinel_bind':
      line     => "bind ${bind} 127.0.0.1",
      match    => '^bind.*',
      path     => '/etc/redis/sentinel.conf',
      multiple => true,
      notify   => Service['redis_sentinel']
    }
    file_line { '$redis/sentinel_dir':
      line     => "dir \"${dir}\"",
      match    => '^dir.*',
      path     => '/etc/redis/sentinel.conf',
      multiple => true,
      notify   => Service['redis_sentinel']
    }
    file_line { '$redis/sentinel_logfile':
      line     => "logfile \"${logfile}\"",
      match    => '^logfile.*',
      path     => '/etc/redis/sentinel.conf',
      multiple => true,
      notify   => Service['redis_sentinel']
    }
    file_line { '$redis/sentinel_port':
      line     => "port ${port}",
      match    => '^port.*',
      path     => '/etc/redis/sentinel.conf',
      multiple => true,
      notify   => Service['redis_sentinel']
    }
    file_line { '$redis/sentinel_protected_mode':
      line     => "protected-mode ${protected_mode}",
      match    => '^protected-mode.*',
      path     => '/etc/redis/sentinel.conf',
      multiple => true,
      notify   => Service['redis_sentinel']
    }
    service { 'redis_sentinel':
      ensure    => running,
      enable    => true,
      subscribe => [
        File[
          '/etc/redis/sentinel.conf',
        ]
      ]
    }
  } else {
    service { 'redis_sentinel':
      ensure => stopped,
      enable => false,
      before => [
        File[
          '/etc/redis/sentinel.conf',
        ]
      ]
    }
  }
}