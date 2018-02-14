#!/usr/bin/env python3
import argparse
import configparser
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description="Redis Sentinel & Replication Helper")

    subparsers = parser.add_subparsers(help='commands', dest='method')
    subparsers.required = True

    parser.add_argument("--port", dest="port", action="store", default=26379)
    parser.add_argument("--host", dest="host", action="store", default='127.0.0.1')
    parser.add_argument("--cfg", dest="cfg", action="store", default='/etc/redis/sentinel_pools.conf')
    parser.add_argument("--pool", dest="pool", action="store", required=True, help="name of the pool")

    chk_parser = subparsers.add_parser('check', help='check if pool is correctly configured')
    chk_parser.set_defaults(method=False)

    adjust_parser = subparsers.add_parser('adjust', help='adjust pool config to match desired state')
    adjust_parser.set_defaults(method=True)

    parsed_args = parser.parse_args()

    helper = SentinelHelper(
        host=parsed_args.host,
        port=parsed_args.port,
        cfg=parsed_args.cfg,
        pool=parsed_args.pool,
        fix=parsed_args.method,
    )

    helper.run()


class SentinelHelper(object):
    def __init__(self, host, port, cfg, pool, fix):
        self._host = host
        self._port = port
        try:
            self._cfg = configparser.ConfigParser()
            with open(cfg, 'r') as f:
                self._cfg.read_file(f)
        except (
            configparser.DuplicateOptionError,
            configparser.DuplicateSectionError,
            OSError
        ) as err:
            print("could not read config: {0}".format(err))
            sys.exit(255)
        self._pool = pool
        self._fix = fix
        
    @property
    def first_sentinel(self):
        sentinels = self.cfg.get('main', 'sentinel').split(',')[0]
        return sentinels == "{0}:{1}".format(self.host, self.port)

    @property
    def fix(self):
        return self._fix

    @property
    def host(self):
        return self._host

    @property
    def port(self):
        return str(self._port)

    @property
    def cfg(self):
        return self._cfg

    @property
    def pool(self):
        return self._pool

    def _add_pool(self):
        quorum = self.cfg.get('{0}:pool'.format(self.pool), 'quorum')
        if self.first_sentinel:
            first_member = self.cfg.get('{0}:pool'.format(self.pool), 'members').split(',')[0]
            ip, port = first_member.split(':')
        else:
            ip, port = self._get_master()
        if self._check_redis(ip, port):
            output = subprocess.check_output(
                [
                    '/bin/redis-cli', '-p', self.port, '-h', self.host,
                    'sentinel', 'monitor', self.pool, ip, port, quorum
                ]
            )
            if b'OK' not in output:
                print("adding pool {0} failed: {1}".format(self.pool, output))
                sys.exit(1)
        else:
            print("could not connect to master {0}:{1}".format(ip, port))
            sys.exit(1)

    def _add_slave(self, ip, port):
        auth = self.cfg.get('{0}:pool'.format(self.pool), 'auth_pass')
        _ip, _port = self._get_master()
        if auth:
            cmd = ['/bin/redis-cli', '-a', auth, '-p', port, '-h', ip, 'slaveof', _ip, _port]
        else:
            cmd = ['/bin/redis-cli', '-p', port, '-h', ip, 'slaveof', _ip, _port]
        try:
            output = subprocess.check_output(
                cmd
            )
            if b'OK' not in output:
                print("adding slave {0} to pool {1} failed: {2}".format(ip+':'+port, self.pool, output))
                sys.exit(1)
        except subprocess.CalledProcessError:
            pass

    def _check_pool(self):
        info = self._get_pool()
        if not info:
            if self.fix:
                self._add_pool()
            else:
                print("pool {0} is missing".format(self.pool))
                sys.exit(1)

    def _check_pool_option(self, opts, option):
        should = self.cfg.get('{0}:pool'.format(self.pool), option)
        try:
            current = opts[opts.index(option.replace('_', '-').encode())+1].decode()
            if should != current:
                if self.fix:
                    self._set_pool_option(option)
                else:
                    print("option {0} is has wrong value {1}".format(option, current))
                    sys.exit(1)
        except ValueError:
            if not should:
                return

    def _check_pool_options(self):
        opts = self._get_pool()
        for option in [
            'quorum',
            'down_after_milliseconds',
            'parallel_syncs',
            'failover_timeout',
            'notification_script',
            'client_reconfig_script',
        ]:
            self._check_pool_option(opts, option)
        self._set_pool_option('auth_pass')

    def _check_redis(self, ip, port):
        auth = self.cfg.get('{0}:pool'.format(self.pool), 'auth_pass')
        if auth:
            cmd = ['/bin/redis-cli', '-a', auth, '-p', port, '-h', ip, 'ping']
        else:
            cmd = ['/bin/redis-cli', '-p', port, '-h', ip, 'ping']
        try:
            output = subprocess.check_output(
                cmd
            )
            return b'PONG' in output
        except subprocess.CalledProcessError:
            pass

    def _check_slaves(self):
        members = self.cfg.get('{0}:pool'.format(self.pool), 'members').split(',')
        master = '{0}:{1}'.format(*self._get_master())
        slaves = self._get_slaves()

        for member in members:
            if member not in slaves:
                if member != master:
                    if self.fix:
                        ip, port = member.split(':')
                        self._add_slave(ip, port)
                    else:
                        print("{0} not configured as slave".format(member))
                        sys.exit(1)

    def _get_master(self):
        _host, _port = self.cfg.get('main', 'sentinel').split(',')[0].split(':')
        try:
            output = subprocess.check_output(
                [
                    '/bin/redis-cli', '-p', _port, '-h', _host,
                    'sentinel', 'master', self.pool
                ]
            )
            if b'ERR No such master with that name' not in output:
                output = output.splitlines()
                ip = output[output.index(b'ip')+1]
                port = output[output.index(b'port')+1]
                return ip.decode(), port.decode()
            else:
                print("could not get master from first sentinel")
                sys.exit(1)
        except subprocess.CalledProcessError:
            print("could not reach out to first sentinel")
            sys.exit(1)

    def _get_slaves(self):
        output = subprocess.check_output(
            [
                '/bin/redis-cli', '-p', self.port, '-h', self.host,
                'sentinel', 'slaves', self.pool
            ]
        )
        output = output.splitlines()
        indices = [i for i, x in enumerate(output) if x == b"name"]
        slaves = []
        for index in indices:
            slaves.append(output[index+1].decode())
        return slaves

    def _get_pool(self):
        output = subprocess.check_output(
            [
                '/bin/redis-cli', '-p', self.port, '-h', self.host,
                'sentinel', 'master', self.pool
            ]
        )
        if b'ERR No such master with that name' not in output:
            return output.splitlines()

    def _set_pool_option(self, option):
        value = self.cfg.get('{0}:pool'.format(self.pool), option)
        option = option.replace('_', '-')
        output = subprocess.check_output(
            [
                '/bin/redis-cli', '-p', self.port, '-h', self.host,
                'sentinel', 'set', self.pool, option, value
            ]
        )
        if b'OK' not in output:
            print("failed setting {0}".format(option))
            sys.exit(1)

    def run(self):
        self._check_pool()
        self._check_pool_options()
        if self.first_sentinel:
            self._check_slaves()


if __name__ == '__main__':
    main()
