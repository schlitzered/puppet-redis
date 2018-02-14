#!/usr/bin/env python3
import argparse
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description="Redis Config Setter & Validator")

    subparsers = parser.add_subparsers(help='commands', dest='method')
    subparsers.required = True

    parser.add_argument("--port", dest="port", action="store", default=6379)
    parser.add_argument("--host", dest="host", action="store", default='127.0.0.1')
    parser.add_argument("--auth", dest="auth", action="store", default='')

    chk_parser = subparsers.add_parser('check', help='check if config value is correctly set')
    chk_parser.set_defaults(method='chk')
    chk_parser.add_argument(
        "--option", dest="option", action="store", required=True,
        help="name of the option that should be checked"
    )
    chk_parser.add_argument(
        "--value", dest="value", action="store", required=True,
        help="value to be checked"
    )

    set_parser = subparsers.add_parser('set', help='set config value')
    set_parser.set_defaults(method='set')
    set_parser.add_argument(
        "--option", dest="option", action="store", required=True,
        help="name of the option that should be set"
    )
    set_parser.add_argument(
        "--value", dest="value", action="store", required=True,
        help="value to be set"
    )

    parsed_args = parser.parse_args()

    configsetter = ConfigSetter(
        auth=parsed_args.auth,
        host=parsed_args.host,
        port=parsed_args.port,
        option=parsed_args.option,
        value=parsed_args.value
    )

    if parsed_args.method == 'chk':
        configsetter.check()
    else:
        configsetter.set()


class ConfigSetter(object):
    def __init__(self, auth, host, port, option, value):
        self._auth = auth
        self._host = host
        self._port = port
        self._option = option
        self._value = value
        self.simple_kv = [
            'activerehashing',
            'appendfilename',
            'appendfsync',
            'appendonly',
            'aof-rewrite-incremental-fsync',
            'aof-load-truncated',
            'auto-aof-rewrite-percentage',
            'client-output-buffer-limit',
            'cluster-migration-barrier',
            'cluster-node-timeout',
            'cluster-require-full-coverage',
            'cluster-slave-validity-factor',
            'dbfilename',
            'hash-max-ziplist-entries',
            'hash-max-ziplist-value',
            'hll-sparse-max-bytes',
            'hz',
            'latency-monitor-threshold',
            'list-compress-depth',
            'list-max-ziplist-size',
            'loglevel',
            'lua-time-limit',
            'masterauth',
            'maxclients',
            'maxmemory-policy',
            'maxmemory-samples',
            'min-slaves-max-lag',
            'min-slaves-to-write',
            'notify-keyspace-events',
            'no-appendfsync-on-rewrite',
            'rdbcompression',
            'rdbchecksum',
            'repl-diskless-sync',
            'repl-diskless-sync-delay',
            'repl-ping-slave-period',
            'repl-timeout',
            'repl-disable-tcp-nodelay',
            'repl-backlog-ttl',
            'requirepass',
            'save',
            'set-max-intset-entries',
            'slave-announce-ip',
            'slave-announce-port',
            'slave-serve-stale-data',
            'slave-read-only',
            'slave-priority',
            'slowlog-log-slower-than',
            'slowlog-max-len',
            'stop-writes-on-bgsave-error',
            'timeout',
            'tcp-keepalive',
            'zset-max-ziplist-entries',
            'zset-max-ziplist-value',
        ]
        self.units_kv = [
            'auto-aof-rewrite-min-size',
            'maxmemory',
            'repl-backlog-size'
        ]

    @property
    def auth(self):
        return self._auth

    @property
    def host(self):
        return self._host

    @property
    def port(self):
        return self._port

    @property
    def option(self):
        return self._option

    @property
    def value(self):
        return self._value.encode()

    @property
    def value_unit(self):
        value = self._value.lower()
        if self._value.endswith('k'):
            return str(int(value[:-1])*1000).encode()
        elif self._value.endswith('kb'):
            return str(int(value[:-2])*1024).encode()
        elif self._value.endswith('m'):
            return str(int(value[:-1])*1000*1000).encode()
        elif self._value.endswith('mb'):
            return str(int(value[:-2])*1024*1024).encode()
        elif self._value.endswith('g'):
            return str(int(value[:-1])*1000*1000*1000).encode()
        elif self._value.endswith('gb'):
            return str(int(value[:-2])*1024*1024*1024).encode()
        else:
            value.decode()

        return self._value.encode()

    def check(self):
        if self.option in self.simple_kv:
            self.check_kv(self.value)
        elif self.option in self.units_kv:
            self.check_kv(self.value_unit)
        else:
            print('error: unsupported option {0}'.format(self.option))
            sys.exit(2)

    def check_kv(self, value):
        if self.auth:
            cmd = ['/bin/redis-cli', '-a', self.auth, '-p', self.port, '-h', self.host, 'config', 'get', self.option]
        else:
            cmd = ['/bin/redis-cli', '-p', self.port, '-h', self.host, 'config', 'get', self.option]
        output = subprocess.check_output(
            cmd
        )
        output = output.splitlines()
        if value != output[1]:
            exit(1)

    def save(self):
        if self.auth:
            cmd = ['/bin/redis-cli', '-a', self.auth, '-p', self.port, '-h', self.host, 'config', 'rewrite']
        else:
            cmd = ['/bin/redis-cli', '-p', self.port, '-h', self.host, 'config', 'rewrite']
        subprocess.check_output(
            cmd
        )

    def set(self):
        if self.option in self.simple_kv:
            self.set_kv(self.value)
        elif self.option in self.units_kv:
            self.set_kv(self.value_unit)
        else:
            print('error: unsupported option {0}'.format(self.option))
            sys.exit(2)

    def set_kv(self, value):
        if self.auth:
            cmd = ['/bin/redis-cli', '-a', self.auth, '-p', self.port, '-h', self.host, 'config', 'set', self.option, value]
        else:
            cmd = ['/bin/redis-cli', '-p', self.port, '-h', self.host, 'config', 'set', self.option, value]
        subprocess.check_output(
            cmd
        )
        self.save()


if __name__ == '__main__':
    main()
