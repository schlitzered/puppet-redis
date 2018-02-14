#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with redis](#setup)
    * [What redis affects](#what-redis-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with redis](#beginning-with-redis)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Reference - An under-the-hood peek at what the module is doing and how](#reference)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Description

This module is capable of managing multiple Redis instances, as well as Redis Sentinel.

Managing Redis though puppet is pretty hard since Redis, especially if managed via Sentinel, 
tends to rewrite is configuration, whenever a change in the cluster happens.

These changes then may get overwritten by Puppet in the next run, rendering the Redis cluster broken.

This module takes a different approach in how the config is managed.

Redis has two types of configs options, the first one require a service restart, like changing the port.
The other options are changeable via runtime, the the redis protocol.

The "restart required" options are implemented via the file_line resource, and are executed before
the redis instance starts, or will trigger are redis restart.

The "changeable at runtime" commands are implemented via a python3 cli tool, making use of the redis-cli command line tool.
These options are applied, as soon as the redis instance is running.

This module also supports running Redis Sentinel. Only one instance per node is supported,
but one instance can manage multiple redis replica sets.

At least 3 nodes should run Redis Sentinel.

In this module, the first redis Sentinel, will be responsible to bootstrap the cluster.

The first Sentinel will make the first redis instance the master, and make all other instances slaves of the first one.
All other Redis Sentinel instances will ask the first Sentinel for the current master.

After the bootstrapping is done, the sentinels will take care of the replica set.

## Setup

### What redis affects
The module brings it own SystemD unit files for both redis and redis sentinel.
The normal redis instances will be switched of and disabled.

### Setup Requirements 

The module has been Tested with Redis 3.2 on Centos 7, but all SystemD based Linux systems should be supported.


### Beginning with redis

Creating 2 redis cluster (dummy and dummyy), managed by sentinel.

The following assumes you have 3 hosts. 
- 192.168.33.41
- 192.168.33.42
- 192.168.33.43

with eth0 being the primary interface

somewhere in your manifests do:
```
include ::redis
```

the rest is done through hiera.

```
# if you are using the roles & profiles pattern
#classes: 
#  - roles::redis

redis::sentinel::ensure: present
redis::sentinel::bind: "%{facts.networking.interfaces.eth0.ip}"
redis::sentinel::sentinels:
  - 192.168.33.41:26379 # this is the first sentinel, that will bootstrap the cluster
  - 192.168.33.42:26379
  - 192.168.33.43:26379
# this will setup the sentinel pools/replica sets sentinel should manage
redis::sentinel::pools:
  dummy:
    members:
      - 192.168.33.41:10101 # the first redis instance of the dummy cluster, will become the initial master
      - 192.168.33.42:10101
      - 192.168.33.43:10101
    auth_pass: some_nice_password
  dummyy:
    members:
      - 192.168.33.41:10102 # the first redis instance of the dummyy cluster, will become the initial master
      - 192.168.33.42:10102
      - 192.168.33.43:10102
    auth_pass: some_nice_password
# this will actually create the redis instances
redis::instances:
  dummy:
    bind: "%{facts.networking.interfaces.eth0.ip}"
    port: 10101
    requirepass: some_nice_password
  dummyy:
    bind: "%{facts.networking.interfaces.eth0.ip}"
    port: 10102
    requirepass: some_nice_password

```

It is expected that you may need multiple puppet runs for the cluster to be correctly be setup.
Since puppet will reports errors if remote redis instances are not yet ready.

## Usage

The module has been build to be completely managed via hiera. 
You only need to include the main redis class somewhere.

## Reference

### Classes

#### Public Classes
* redis: Main class, includes all other classes

#### Private Classes
* redis::config: handles base config files and directories, unit files, and helper scripts
* redis::install: handles redis package installation, as well as stopping the default redis instance
* redis::sentinel: Handles redis sentinel configuration

### Defines

#### Private Defines
* redis::instances: handles the livecycle of a instance
* redis::option: handles a "change at runtime" config option of a redis instance
* redis::sentinel::pool: handles redis sentinel pool livecycle

## Limitations

* The module requires a Linux System with Systemd
* The module is not able to bootstrap a redis cluster, but this might change at some point
* The module is not able to remove a pool/replica set member, this has to be done manually
* no Unit tests :-/
