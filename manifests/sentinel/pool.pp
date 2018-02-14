# @api private
# This define creates sentinel pool configurations. This should always be created thru hiera.
# @param members [Array] list of redis pool members, the first one will be used to initialize the redis replication, if not already done.
# for all other parameters lookup the redis sentinel documentation.
define redis::sentinel::pool (
  Array $members,
  String $auth_pass,
  Integer $quorum = 1,
  Integer $down_after_milliseconds = 30000,
  Integer $parallel_syncs = 1,
  Integer $failover_timeout = 180000,
  String $notification_script = '',
  String $client_reconfig_script = '',
) {
  concat::fragment { "redis_sentinel_pool_${title}":
    target  => '/etc/redis/sentinel_pools.conf',
    content => template('redis/sentinel_pool.erb'),
    order   => "10-${title}"
  }
  $command = "/usr/bin/redis_sentinel --pool ${title} --port ${redis::sentinel::port} --host ${redis::sentinel::bind}"
  exec {"redis_sentinel_pool_${title}":
    command => "${command} adjust",
    unless  => "${command} check",
    require => Concat['/etc/redis/sentinel_pools.conf']
  }
}