# @api private
# This define manages redis instances. This should always be created thru hiera.
# Parameters corespond to the respective redis parameters
# some of them are implemented via "file_line", changing them will restart the redis instance,
# all other parameters use a python helper script, to adjust the parameters on the fly.
define redis::instance (
  Integer $port,
  String $requirepass,
  Enum['absent', 'present'] $ensure = 'present',
  String $bind = $facts['networking']['ip'],
  Enum['no', 'yes'] $protected_mode = 'yes',
  Integer $tcp_backlog = 511,
  Integer $tcp_keepalive = 300,
  Integer $timeout = 0,
  Enum['debug', 'verbose', 'notice', 'warning'] $log_level = 'notice',
  Enum['no', 'yes'] $syslog_enabled = 'no',
  String $syslog_ident = 'redis',
  String $syslog_facility = 'local0',
  Integer $databases = 16,
  String $save = '900 1 300 10 60 10000',
  Enum['no', 'yes'] $stop_writes_on_bgsave_error = 'yes',
  Enum['no', 'yes'] $rdbcompression = 'yes',
  Enum['no', 'yes'] $rdbchecksum = 'yes',
  String $dbfilename = 'dump.rdb',
  Enum['no', 'yes'] $slave_serve_stale_data = 'yes',
  Enum['no', 'yes'] $slave_read_only = 'yes',
  Enum['no', 'yes'] $repl_diskless_sync = 'no',
  Integer $repl_diskless_sync_delay = 5,
  Integer $repl_ping_slave_period = 10,
  Integer $repl_timeout = 60,
  Enum['no', 'yes'] $repl_disable_tcp_nodelay = 'no',
  String $repl_backlog_size = '1mb',
  Integer $repl_backlog_ttl = 3600,
  Integer $slave_priority = 100,
  Integer $min_slaves_to_write = 0,
  Integer $min_slaves_max_lag = 10,
  String $slave_announce_ip = '',
  Integer $slave_announce_port = 0,
  String $masterauth = $requirepass,
  Integer $maxclients = 1024,
  String $maxmemory = '64mb',
  Enum[
    'volatile-lru',
    'allkeys-lru',
    'volatile-random',
    'allkeys-random',
    'volatile-ttl',
    'noeviction'
  ]$maxmemory_policy = 'noeviction',
  Integer $maxmemory_samples = 5,
  Enum['no', 'yes'] $appendonly = 'no',
  String $appendfilename = 'appendonly.aof',
  Enum['always', 'everysec', 'no'] $appendfsync = 'everysec',
  Enum['no', 'yes'] $no_appendfsync_on_rewrite = 'no',
  Integer $auto_aof_rewrite_percentage = 100,
  String $auto_aof_rewrite_min_size = '64mb',
  Enum['no', 'yes'] $aof_load_truncated = 'yes',
  Integer $lua_time_limit = 5000,
  Enum['no', 'yes'] $cluster_enabled = no,
  String $cluster_config_file = "redis_${title}_cluster.conf",
  Integer $cluster_node_timeout = 15000,
  Integer $cluster_slave_validity_factor = 10,
  Integer $cluster_migration_barrier = 1,
  Enum['no', 'yes'] $cluster_require_full_coverage = 'yes',
  Integer $slowlog_log_slower_than = 10000,
  Integer $slowlog_max_len = 128,
  Integer $latency_monitor_threshold = 0,
  String $notify_keyspace_events = '',
  Integer $hash_max_ziplist_entries = 512,
  Integer $hash_max_ziplist_value = 64,
  Integer $list_max_ziplist_size = -2,
  Integer $list_compress_depth = 0,
  Integer $set_max_intset_entries = 512,
  Integer $zset_max_ziplist_entries = 128,
  Integer $zset_max_ziplist_value = 64,
  Integer $hll_sparse_max_bytes = 3000,
  Enum['no', 'yes'] $activerehashing = 'yes',
  String $client_output_buffer_limit = 'normal 0 0 0 slave 268435456 67108864 60 pubsub 33554432 8388608 60',
  Integer $hz = 10,
  Enum['no', 'yes'] $aof_rewrite_incremental_fsync = 'yes',
  String $unixsocket = "/var/run/redis/redis_${title}.socket",
  String $unixsocketperm = '777'
) {

  if $ensure == 'present' {
    $_dir_ensure = 'directory'
    $_file_ensure = 'file'
    $_link_ensure = 'link'
    $_purge = false
    $_recurse = false
  } else {
    $_dir_ensure = $ensure
    $_file_ensure = $ensure
    $_link_ensure = $ensure
    $_purge = true
    $_recurse = true
  }

  file { "/var/lib/redis/redis_${title}":
    ensure  => $_dir_ensure,
    group   => 'redis',
    owner   => 'redis',
    purge   => $_purge,
    recurse => $_recurse
  }

  file { "/etc/redis/redis_${title}.conf":
    ensure  => $_file_ensure,
    group   => 'redis',
    owner   => 'redis',
    content => template('redis/redis.conf.erb'),
    replace => 'no'
  }

  if $ensure == 'present' {
    file_line { "redis_${title}_bind":
      line     => "bind ${bind} 127.0.0.1",
      match    => '^bind.*',
      path     => "/etc/redis/redis_${title}.conf",
      multiple => true,
      notify   => Service["redis@${title}"]
    }
    file_line { "redis_${title}_masterauth":
      line     => "masterauth \"${masterauth}\"",
      match    => '^masterauth.*',
      path     => "/etc/redis/redis_${title}.conf",
      multiple => true,
      notify   => Service["redis@${title}"]
    }
    file_line { "redis_${title}_port":
      line     => "port ${port}",
      match    => '^port.*',
      path     => "/etc/redis/redis_${title}.conf",
      multiple => true,
      notify   => Service["redis@${title}"]
    }
    file_line { "redis_${title}_requirepass":
      line     => "requirepass \"${requirepass}\"",
      match    => '^requirepass.*',
      path     => "/etc/redis/redis_${title}.conf",
      multiple => true,
      notify   => Service["redis@${title}"]
    }
    file_line { "redis_${title}_tcp_backlog":
      line     => "tcp-backlog ${tcp_backlog}",
      match    => '^tcp-backlog.*',
      path     => "/etc/redis/redis_${title}.conf",
      multiple => true,
      notify   => Service["redis@${title}"]
    }
    if $syslog_enabled == 'yes' {
      file_line { "redis_${title}_syslog_enabled":
        line     => "syslog-enabled ${syslog_enabled}",
        match    => '^syslog-enabled.*',
        path     => "/etc/redis/redis_${title}.conf",
        multiple => true,
        notify   => Service["redis@${title}"]
      }
      file_line { "redis_${title}_syslog_ident":
        line     => "syslog-ident ${syslog_ident}",
        match    => '^syslog-ident.*',
        path     => "/etc/redis/redis_${title}.conf",
        multiple => true,
        notify   => Service["redis@${title}"]
      }
      file_line { "redis_${title}_syslog_facility":
        line     => "syslog-facility ${syslog_facility}",
        match    => '^syslog-facility.*',
        path     => "/etc/redis/redis_${title}.conf",
        multiple => true,
        notify   => Service["redis@${title}"]
      }
    }
    file_line { "redis_${title}_databases":
      line     => "databases ${databases}",
      match    => '^databases.*',
      path     => "/etc/redis/redis_${title}.conf",
      multiple => true,
      notify   => Service["redis@${title}"]
    }
    if $cluster_enabled == 'yes' {
      file_line { "redis_${title}_cluster_enabled":
        line     => "cluster-enabled ${cluster_enabled}",
        match    => '^cluster-enabled.*',
        path     => "/etc/redis/redis_${title}.conf",
        multiple => true,
        notify   => Service["redis@${title}"]
      }
      file_line { "redis_${title}_cluster_config_file":
        line     => "cluster-config-file ${cluster_config_file}",
        match    => '^cluster-config-file.*',
        path     => "/etc/redis/redis_${title}.conf",
        multiple => true,
        notify   => Service["redis@${title}"]
      }
    }
    file_line { "redis_${title}_unixsocket":
      line     => "unixsocket \"${unixsocket}\"",
      match    => '^unixsocket .*',
      path     => "/etc/redis/redis_${title}.conf",
      multiple => true,
      notify   => Service["redis@${title}"]
    }
    file_line { "redis_${title}_unixsocketperm":
      line     => "unixsocketperm ${unixsocketperm}",
      match    => '^unixsocketperm .*',
      path     => "/etc/redis/redis_${title}.conf",
      multiple => true,
      notify   => Service["redis@${title}"]
    }
    redis::option { "redis_${title}_tcp_keepalive":
      option  => 'tcp-keepalive',
      value   => $tcp_keepalive,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_timeout":
      option  => 'timeout',
      value   => $timeout,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_loglevel":
      option  => 'loglevel',
      value   => $log_level,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_save":
      option  => 'save',
      value   => $save,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_stop_writes_on_bgsave_error":
      option  => 'stop-writes-on-bgsave-error',
      value   => $stop_writes_on_bgsave_error,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_rdbcompression":
      option  => 'rdbcompression',
      value   => $rdbcompression,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_rdbchecksum":
      option  => 'rdbchecksum',
      value   => $rdbchecksum,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_dbfilename":
      option  => 'dbfilename',
      value   => $dbfilename,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_slave_serve_stale_data":
      option  => 'slave-serve-stale-data',
      value   => $slave_serve_stale_data,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_slave_read_only":
      option  => 'slave-read-only',
      value   => $slave_read_only,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_repl_diskless_sync":
      option  => 'repl-diskless-sync',
      value   => $repl_diskless_sync,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_repl_diskless_sync_delay":
      option  => 'repl-diskless-sync-delay',
      value   => $repl_diskless_sync_delay,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_repl_ping_slave_period":
      option  => 'repl-ping-slave-period',
      value   => $repl_ping_slave_period,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_repl_timeout":
      option  => 'repl-timeout',
      value   => $repl_timeout,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_repl_disable_tcp_nodelay":
      option  => 'repl-disable-tcp-nodelay',
      value   => $repl_disable_tcp_nodelay,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_repl_backlog_size":
      option  => 'repl-backlog-size',
      value   => $repl_backlog_size,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_repl_backlog_ttl":
      option  => 'repl-backlog-ttl',
      value   => $repl_backlog_ttl,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_slave_priority":
      option  => 'slave-priority',
      value   => $slave_priority,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_min_slaves_to_wrtie":
      option  => 'min-slaves-to-write',
      value   => $min_slaves_to_write,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_min_slaves_max_lag":
      option  => 'min-slaves-max-lag',
      value   => $min_slaves_max_lag,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_slave_announce_ip":
      option  => 'slave-announce-ip',
      value   => $slave_announce_ip,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_slave_announce_port":
      option  => 'slave-announce-port',
      value   => $slave_announce_port,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_maxclients":
      option  => 'maxclients',
      value   => $maxclients,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_maxmemory":
      option  => 'maxmemory',
      value   => $maxmemory,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_maxmemory_policy":
      option  => 'maxmemory-policy',
      value   => $maxmemory_policy,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_maxmemory_samples":
      option  => 'maxmemory-samples',
      value   => $maxmemory_samples,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_appendonly":
      option  => 'appendonly',
      value   => $appendonly,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    if $appendonly == 'yes' {
      redis::option { "redis_${title}_appendfilename":
        option  => 'appendfilename',
        value   => $appendfilename,
        auth    => $requirepass,
        port    => $port,
        require => Service["redis@${title}"],
      }
    }
    redis::option { "redis_${title}_appendfsync":
      option  => 'appendfsync',
      value   => $appendfsync,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_no_appendfsync_on_rewrite":
      option  => 'no-appendfsync-on-rewrite',
      value   => $no_appendfsync_on_rewrite,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_auto_aof_rewrite_percentage":
      option  => 'auto-aof-rewrite-percentage',
      value   => $auto_aof_rewrite_percentage,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_auto_aof_rewrite_min_size":
      option  => 'auto-aof-rewrite-min-size',
      value   => $auto_aof_rewrite_min_size,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_aof_load_truncated":
      option  => 'aof-load-truncated',
      value   => $aof_load_truncated,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_lua_time_limit":
      option  => 'lua-time-limit',
      value   => $lua_time_limit,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_cluster_node_timeout":
      option  => 'cluster-node-timeout',
      value   => $cluster_node_timeout,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_cluster_slave_validity_factor":
      option  => 'cluster-slave-validity-factor',
      value   => $cluster_slave_validity_factor,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_cluster_migration_barrier":
      option  => 'cluster-migration-barrier',
      value   => $cluster_migration_barrier,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_cluster_require_full_coverage":
      option  => 'cluster-require-full-coverage',
      value   => $cluster_require_full_coverage,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_slowlog_log_slower_than":
      option  => 'slowlog-log-slower-than',
      value   => $slowlog_log_slower_than,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_slowlog_max_len":
      option  => 'slowlog-max-len',
      value   => $slowlog_max_len,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_latency_monitor_threshold":
      option  => 'latency-monitor-threshold',
      value   => $latency_monitor_threshold,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_notify_keyspace_events":
      option  => 'notify-keyspace-events',
      value   => $notify_keyspace_events,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_hash_max_ziplist_entries":
      option  => 'hash-max-ziplist-entries',
      value   => $hash_max_ziplist_entries,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_hash_max_ziplist_value":
      option  => 'hash-max-ziplist-value',
      value   => $hash_max_ziplist_value,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_list_max_ziplist_size":
      option  => 'list-max-ziplist-size',
      value   => $list_max_ziplist_size,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_list_compress_depth":
      option  => 'list-compress-depth',
      value   => $list_compress_depth,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_set_max_intset_entries":
      option  => 'set-max-intset-entries',
      value   => $set_max_intset_entries,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_zset_max_ziplist_entries":
      option  => 'zset-max-ziplist-entries',
      value   => $zset_max_ziplist_entries,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_zset_max_ziplist_value":
      option  => 'zset-max-ziplist-value',
      value   => $zset_max_ziplist_value,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_hll_sparse_max_bytes":
      option  => 'hll-sparse-max-bytes',
      value   => $hll_sparse_max_bytes,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_activerehashing":
      option  => 'activerehashing',
      value   => $activerehashing,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_hz":
      option  => 'hz',
      value   => $hz,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_aof_rewrite_incremental_fsync":
      option  => 'aof-rewrite-incremental-fsync',
      value   => $aof_rewrite_incremental_fsync,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    redis::option { "redis_${title}_client_output_buffer_limit":
      option  => 'client-output-buffer-limit',
      value   => $client_output_buffer_limit,
      auth    => $requirepass,
      port    => $port,
      require => Service["redis@${title}"],
    }
    service { "redis@${title}":
      ensure    => running,
      enable    => true,
      subscribe => [
        File[
          "/etc/redis/redis_${title}.conf",
          "/var/lib/redis/redis_${title}"
        ]
      ],
    }
  } else {
    service { "redis@${title}":
      ensure => stopped,
      enable => false,
      before => [
        File[
          "/etc/redis/redis_${title}.conf",
          "/var/lib/redis/redis_${title}"
        ]
      ]
    }
  }
}