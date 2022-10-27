#!/bin/bash

docker ps -a > .find_addresses.log;
docker network ls >> .find_addresses.log;
ZDM_HOST_IP="`ip addr | grep docker0: -A 2 | grep inet | awk '{print $2}' | awk -F/ '{print $1}'`"
CASSANDRA_SEED_IP="`docker inspect cassandra-origin-1 | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'`"

CASSANDRA_NODE1_IP="${CASSANDRA_SEED_IP}"
CASSANDRA_NODE2_IP="`docker inspect cassandra-origin-2 | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'`"
CASSANDRA_NODE3_IP="`docker inspect cassandra-origin-3 | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'`"

echo "ZDM_HOST_IP = ${ZDM_HOST_IP} ; CASSANDRA_SEED_IP = ${CASSANDRA_SEED_IP}"
echo "CASSANDRA_NODE1_IP = ${CASSANDRA_NODE1_IP} ; CASSANDRA_NODE2_IP = ${CASSANDRA_NODE2_IP} ; CASSANDRA_NODE3_IP = ${CASSANDRA_NODE3_IP}"
