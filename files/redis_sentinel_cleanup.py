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

    chk_parser = subparsers.add_parser('check', help='check if sentinel contains now un manged pools')
    chk_parser.set_defaults(method=False)

    adjust_parser = subparsers.add_parser('adjust', help='wipe un managed pools')
    adjust_parser.set_defaults(method=True)

    parsed_args = parser.parse_args()

    helper = SentinelHelper(
        host=parsed_args.host,
        port=parsed_args.port,
        cfg=parsed_args.cfg,
        fix=parsed_args.method,
    )

    helper.run()


class SentinelHelper(object):
    def __init__(self, host, port, cfg, fix):
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
        self._fix = fix

    @property
    def fix(self):
        return self._fix

    @property
    def host(self):
        return self._host

    @property
    def cfg_pools(self):
        pools = list()
        for section in self.cfg.sections():
            if section.endswith(':pool'):
                pools.append(section[:-5])
        return set(pools)

    @property
    def sentinel_pools(self):
        pools = list()
        try:
            output = subprocess.check_output(
                [
                    '/bin/redis-cli', '-p', self.port, '-h', self.host,
                    'sentinel', 'masters'
                ]
            )
            output = output.splitlines()
            indices = [i for i, x in enumerate(output) if x == b"name"]
            for index in indices:
                pools.append(output[index+1].decode())
        except subprocess.CalledProcessError:
            print("could not reach out to sentinel")
            sys.exit(1)
        return set(pools)

    @property
    def port(self):
        return str(self._port)

    @property
    def cfg(self):
        return self._cfg

    def _remove_pool(self, pool):
        try:
            subprocess.check_output(
                [
                    '/bin/redis-cli', '-p', self.port, '-h', self.host,
                    'sentinel', 'remove', pool
                ]
            )
        except subprocess.CalledProcessError:
            print("could not reach out to sentinel")
            sys.exit(1)

    def _check_pools(self):
        remove = self.sentinel_pools - self.cfg_pools
        if remove:
            if self.fix:
                for pool in remove:
                    self._remove_pool(pool)
            else:
                print("the following pools need to be removed: {0}".format(remove))
                sys.exit(1)

    def run(self):
        self._check_pools()


if __name__ == '__main__':
    main()
