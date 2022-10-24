# ZDM Scenario

The following is a fully Dockerized ZDM scenario,
designed to later run as interactive batteries-included scenario.

In its current status, there are

- "behind-the-scenes" instructions (initial setup and a few steps along the way), later meant to be hidden away from the user;
- actual steps meant to be exposed for the user/learner.

> The former will be marked like this and the associated code blocks are commented with `#HIDDEN`.

The latter will be in simple text with ordinary code blocks.

### Outline

Here we try to reproduce the full migration process, start-to-end, so that the scenario learner
will experience it "as in real life". But we want to package everything as Docker containers, so as to
be able to run the whole thing within a Gitpod (and later Katapod) environment.
This, under the tenet "the user shall not notice the difference with the real thing",
entails a few challenges, such as:

- the need for Docker images behaving as close as possible to actual Ubuntu boxes;
- the need for most containers to speak to each other (including containers created by the automation);
- the need for a sufficiently isolated docker-in-docker (mimicking what in real life would be docker in a separate physical machine).

![Scenario architecture](images/zdm-scenario-architecture.png)

The "base machine" (the only physical machine in the scenario) runs Docker for use by non-superuser.
At this layer a sample API runs, connected alternatively to Origin/Target/Proxy and probed by simple `curl`.
Prior to the user intervention, 6 containers are created and started: a 3-node Cassandra cluster (Origin)
and three Ubuntu boxes, which will act as the proxy hosts: these run modified DinD images, providing
a docker-in-docker (as well as ssh access and all that is needed).
Running `zdm-util` on the base machine creates the `zdm-ansible-container` container, in which
the Ansible playbook will run to create the proxy containers in the three "Ubuntu" boxes.
_Note_: the monitoring stack is left out of this picture for clarity.

## Steps

### (HIDDEN) Initial setup, network+origin

> Create password-enabled Cassandra for Origin:

```
# HIDDEN
cd image_origin
docker build . -t cassandra-auth:4.1
cd ..
```

> Create network and start first node in it

```
# HIDDEN
docker network create zdm_network
docker run --name cassandra-origin-1 --network zdm_network -d cassandra-auth:4.1
```

> Wait 60-90 seconds, until this command works: `docker exec -it cassandra-origin-1 nodetool status`.
> Then:

```
# HIDDEN
docker run --name cassandra-origin-2 -d --network zdm_network -e CASSANDRA_SEEDS=cassandra-origin-1 cassandra-auth:4.1
```

> When the `nodetool` above gives two `UN`s, proceed:

```
docker run --name cassandra-origin-3 -d --network zdm_network -e CASSANDRA_SEEDS=cassandra-origin-1 cassandra-auth:4.1
```

> All good when the `nodetool` gives a triple `UN`.

### (HIDDEN) Initial setup, dependencies for client application

```
# HIDDEN
pip install -r client_application/requirements.txt
```

> _Note_: in local machine, please do use a virtualenv for this.

### (HIDDEN) Initial setup, data in Origin

> Copy the init scripts to origin node 1 and execute:

```
docker cp origin_prepare/origin_schema.cql cassandra-origin-1:/
docker cp origin_prepare/origin_populate.cql cassandra-origin-1:/
docker exec -it cassandra-origin-1 cqlsh -u cassandra -p cassandra -f /origin_schema.cql
docker exec -it cassandra-origin-1 cqlsh -u cassandra -p cassandra -f /origin_populate.cql
```

> Check with

```
docker exec -it cassandra-origin-1 cqlsh -u cassandra -p cassandra -e "select * from my_application_ks.user_status where user='eva';"
```

### Get your Astra DB ready

- Create Astra DB (with `my_application_ks` keyspace)
- Retrieve Secure Connect Bundle
- Retrieve a token with "R/W User" role
- Create Schema within keyspace (see below)

**TODO**. **Warning**: with the "R/W User" token, you cannot create the schema in any other
way than on the CQL Web Console. For the time being, we stick to it, so:
Go to CQL Console and copy-paste the contents of `target/prepare/target_schema.cql`

### Have a client application running

On the base machine, run an API which connects to the DB (for now, Origin, but easy
to switch). The API will be able to read and write, reachable with simple `curl` commands.

Get the IP of the origin-1 machine,

```
CASSANDRA_CONTACT_POINT=`docker inspect cassandra-origin-1 | jq -r '.[].NetworkSettings.Networks.zdm_network.IPAddress'`
echo ${CASSANDRA_CONTACT_POINT}
cd client_application
```

Prepare `.env` by copying `cp .env.sample .env` and editing it:
`CASSANDRA_SEED`, `ASTRA_DB_SECURE_BUNDLE_PATH`, `ASTRA_DB_CLIENT_ID`, `ASTRA_DB_CLIENT_SECRET`.
The `ZDM_PROXY_SEED` will come later, leave as it is for now.

To run the API with connection to Origin, start as:

```
CLIENT_CONNECTION_MODE=CASSANDRA uvicorn api:app
```

This console will keep running the API. Experiment in another console with `curl`
and optionally read the table itself as a further check:

```
curl -s localhost:8000/status/eva | jq
curl -s -XPOST localhost:8000/status/eva/New | jq
curl -s -XPOST localhost:8000/status/eva/ItIs_`date +'%H-%M-%S'` | jq
```

**TODO** Make these curl into a bash loop-with-sleep?

**TODO** Different keyspace names, possible? We sure don't do that here, we could have a global keyspace name in `.env` for that matter.

**TODO** Confirm that to connect to ZDM a single seed is OK and the rest is discovered?

### Set up the ZDM Automation

_start from here_