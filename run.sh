#!/bin/bash

# Copyright 2014 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# MOD Version: Vinicio Valbuena <vinicio.valbuena89@gmail.com>

: ${TCP_BACKLOG:=511}
: ${MASTER_NAME:=mymaster}
: ${QUORUM:=2}
: ${DOWN_AFTER:=5000}
: ${FAILOVER_TIMEOUT:=60000}
: ${PARALLEL_SYNCS:=1}

function launchmaster() {
  exec redis-server /usr/local/etc/redis/redis.conf
}

function launchsentinel() {
  while true; do
    master=$(redis-cli -h ${REDIS_SENTINEL_SERVICE_HOST} -p ${REDIS_SENTINEL_SERVICE_PORT} --csv SENTINEL get-master-addr-by-name ${MASTER_NAME} | tr ',' ' ' | cut -d' ' -f1)
    if [[ -n ${master} ]]; then
      master="${master//\"}"
    else
      master=$(hostname -i)
    fi

    redis-cli -h ${master} INFO
    if [[ "$?" == "0" ]]; then
      break
    fi
    echo "Connecting to master failed.  Waiting..."
    sleep 10
  done

  sentinel_conf=sentinel.conf

  echo "sentinel monitor ${MASTER_NAME} ${master} 6379 ${QUORUM}" > ${sentinel_conf}
  echo "sentinel down-after-milliseconds ${MASTER_NAME} ${DOWN_AFTER}" >> ${sentinel_conf}
  echo "sentinel failover-timeout ${MASTER_NAME} ${FAILOVER_TIMEOUT}" >> ${sentinel_conf}
  echo "sentinel parallel-syncs ${MASTER_NAME} ${PARALLEL_SYNCS}" >> ${sentinel_conf}
  echo "bind 0.0.0.0" >> ${sentinel_conf}

  exec redis-sentinel ${sentinel_conf} --protected-mode no
}

function launchslave() {
  while true; do
    master=$(redis-cli -h ${REDIS_SENTINEL_SERVICE_HOST} -p ${REDIS_SENTINEL_SERVICE_PORT} --csv SENTINEL get-master-addr-by-name ${MASTER_NAME} | tr ',' ' ' | cut -d' ' -f1)
    if [[ -n ${master} ]]; then
      master="${master//\"}"
    else
      echo "Failed to find master."
      sleep 60
      exit 1
    fi
    redis-cli -h ${master} INFO
    if [[ "$?" == "0" ]]; then
      break
    fi
    echo "Connecting to master failed.  Waiting..."
    sleep 10
  done
  exec redis-server /usr/local/etc/redis/redis.conf --slaveof ${master} 6379
}

sed -i "s/%tcp-backlog%/${TCP_BACKLOG}/" /usr/local/etc/redis/redis.conf

if [[ "${MASTER}" == "true" ]]; then
  launchmaster
fi

if [[ "${SENTINEL}" == "true" ]]; then
  launchsentinel
fi

launchslave
