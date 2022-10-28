# ZDM Scenario

The following is a fully Dockerized ZDM scenario,
designed to later run as interactive batteries-included scenario.

In its current status, there are

- "behind-the-scenes" instructions (initial setup and a few steps along the way), later meant to be hidden away from the user;
- actual steps meant to be exposed for the user/learner.

> The former will be marked like this and the associated code blocks are commented with `#HIDDEN`.

The latter will be in simple text with ordinary code blocks.

**Table of Contents**

- [Outline](#outline)
- [HIDDEN Initial setup](#hidden-initial-setup)
- [Preliminary steps](#preliminary-steps)
- [Phase 1: Connect clients to ZDM Proxy](#phase-1-connect-clients-to-zdm-proxy)
- [Phase 2: Migrate and validate data](#phase-2-migrate-and-validate-data)
- [Phase 3: Enable asynchronous dual reads](#phase-3-enable-asynchronous-dual-reads)
- [Phase 4: Change read routing to Target](#phase-4-change-read-routing-to-target)
- [Phase 5: Connect your client applications directly to Target](#phase-5-connect-your-client-applications-directly-to-target)
- [Epilogue: cleanup](#epilogue-cleanup)

### Outline

Here we try to reproduce the full migration process, start-to-end, so that the scenario learner
will experience it "as in real life". But we want to package everything as Docker containers, so as to
be able to run the whole thing within a Gitpod (and later Katapod) environment.

The ideal rule is "the user shall not notice the difference with the real thing".
Unfortunately, due to the complications of having docker-in-docker situations
(which run fine locally but raise hard problems within Gitpod which adds a further
containerization layer beyond our jurisdiction), we had to find a compromise:
namely, _instead of three Ubuntu containers playing the role of ZDM host machines,_
_we will use the base machine itself as the one ZDM host._

![Scenario architecture](pictures/zdm-scenario-architecture-gitpod.png)

The "base machine" (the only physical machine in the scenario) runs Docker for use by non-superuser.
At this layer a sample API runs, connected alternatively to Origin/Target/Proxy and probed by simple `curl`.
Prior to the user intervention, 3 containers are created and started, with a Cassandra cluster (Origin).
Running the `zdm-util` on the base machine creates the `zdm-ansible-container` container, in which
the Ansible playbook will run: this, in turn, will reach _the base machine again_
("thinking it is the ZDM host machine") and deploy a single-instance ZDM proxy container in it.
To allow for connectivity (including back to the base machine),
the `host` Docker network will be used throughout.
_Note_: the monitoring stack is left out of this picture for clarity.

## (HIDDEN) Initial setup

### (HIDDEN) Initial setup, network+origin

> Create password-enabled Cassandra for Origin:

```
# HIDDEN
cd image_origin
docker build . -t cassandra-auth:4.1
cd ..
```

> Start first node

```
# HIDDEN
docker run --name cassandra-origin-1 -d cassandra-auth:4.1
```

> Wait 60-90 seconds, until this command works: `docker exec -it cassandra-origin-1 nodetool status`.
> Then:

```
# HIDDEN
docker run --name cassandra-origin-2 -d -e CASSANDRA_SEEDS=`docker inspect cassandra-origin-1 | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'` cassandra-auth:4.1
```

> When the `nodetool` above gives two `UN`s, proceed:

```
docker run --name cassandra-origin-3 -d -e CASSANDRA_SEEDS=`docker inspect cassandra-origin-1 | jq -r '.[].NetworkSettings.Networks.bridge.IPAddress'` cassandra-auth:4.1
```

> All good when the `nodetool` gives a triple `UN`.

**TODO** make this cluster creation as short as possible. Now it takes several minutes (which would be spent by the user reading an intro page or something)

**TODO** Also consider making it into a single-node cluster (?) for speed and load on gitpod.

### (HIDDEN) Initial setup, dependencies for client application

```
# HIDDEN
pip install -r client_application/requirements.txt
```

> _Note_: in local machine, please do use a virtualenv for this.

### (HIDDEN) Initial setup, data in Origin

> Copy the init scripts to origin node 1 and execute them on a cluster node:

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

### (HIDDEN) Initial setup, ensure base machine runs ssh server

**TODO** this is Gitpod-only

```
DEBIAN_FRONTEND=noninteractive TZ=Europe/London sudo apt install openssh-server -y
sudo sed 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config -i
sudo sed 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config -i
sudo sed 's/#ListenAddress/ListenAddress/' /etc/ssh/sshd_config -i
sudo sed 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config -i

sudo mkdir /root/.ssh
cat /workspace/zdm-scenario-draft/zdm_host_private_key/zdm_deploy_key.pub | sudo tee -a /root/.ssh/authorized_keys

mkdir /home/gitpod/.ssh
cat /workspace/zdm-scenario-draft/zdm_host_private_key/zdm_deploy_key.pub | tee -a /home/gitpod/.ssh/authorized_keys

sudo service ssh restart

chmod 400 zdm_host_private_key/zdm_deploy_key
```

Now you can `ssh -i zdm_host_private_key/zdm_deploy_key gitpod@172.17.0.1 -o StrictHostKeyChecking=no`.

**TODO** user there is `gitpod`, check later

**TODO** use the `. find_addresses.sh` script for IP addresses env var and output

### (HIDDEN) Initial setup, handle for monitoring stack

**TODO**: deal with the monitoring machine (an image with `systemd` is needed, no need for DinD there).

## Preliminary steps

**TODO** here describe the infrastructure to user and provide them with the
IP-addresses script and have them run it.

### Get your Astra DB ready

- Create Astra DB (with `my_application_ks` keyspace);
- Retrieve Secure Connect Bundle;
- Retrieve a token with "R/W User" role;
- Find the "Database ID" for your Astra DB instance;
- Create Schema within keyspace (see below).

**TODO**. **Warning**: with the "R/W User" token, you cannot create the schema in any other
way than on the CQL Web Console. For the time being, we stick to it, so:
Go to CQL Console and copy-paste the contents of `target/prepare/target_schema.cql`

### Have a client application running

On the base machine, run an API which connects to the DB (for now, Origin, but easy
to switch). The API will be able to read and write, reachable with simple `curl` commands.

Get the IP of the origin-1 machine, **TODO** this would be hidden and replaced by a simple script printing the IPs (no need for user to know the internals)

```
cd client_application
```

Prepare `.env` by copying `cp .env.sample .env` and editing it:

- insert the IPs of the Cassandra seed and the ZDM host, as read by `. ../find_addresses.sh`, in `CASSANDRA_SEED` and `ZDM_PROXY_SEED`;
- insert `ASTRA_DB_SECURE_BUNDLE_PATH`, `ASTRA_DB_CLIENT_ID`, `ASTRA_DB_CLIENT_SECRET` for your connection to Astra DB.

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

## Phase 1: Connect clients to ZDM Proxy

### Set up the ZDM Automation

> The base machine will be the jumphost, in whose Docker the automation creates
> the `zdm-ansible-container`. When this container runs, it will reach
> _the base machine itself (playing the role of the ZDM Host Ubuntu box)_
> and will deploy the ZDM host in its Docker, thus effectively
> alongside the pre-existing Cassandra cluster.

Time to download and run `zdm-util`, which creates the Ansible container which
will then deploy the ZDM proxies. On the base machine, from the repo's root:

```
cd running_zdm_util
wget https://github.com/datastax/zdm-proxy-automation/releases/download/v2.0.0/zdm-util-linux-amd64-v2.0.0.tgz
tar -xvf zdm-util-linux-amd64-v2.0.0.tgz
rm zdm-util-linux-amd64-v2.0.0.tgz 
```

You will have to provide the following answers:

- the private key location: `../zdm_host_private_key/zdm_deploy_key`;
- the network prefix for the ZDM host: **TODO** a script that outputs them to the user (no need for them to docker inspect, this would be behind-the-scenes);
- no, you don't have an inventory file yet;
- yes, this is for testing (so as to allow for a single ZDM host instead of the required three);
- enter the IP for the ZDM host (see **TODO** above);
- **TODO** the monitoring machine when it's there.

Now run:

```
./zdm-util-v2.0.0
```

A `zdm-ansible-container` container is created and started for you (on the base machine's Docker).

(HIDDEN) Tweak the playbook:

> We also need to comment out, behind-the-scenes, some tasks in the Ansible install playbook,
> which would install Docker. This should happen
> before the user launches the Ansible playbook. Namely, the tasks to comment from the Ansible
> container's `/home/ubuntu/zdm-proxy-automation/ansible/deploy_zdm_proxy.yml` are:
> (1) `- name: Add Docker GPG apt Key`, (2) `- name: Add Docker Repository`.
> (3) `- name: Update apt and install docker-ce` and (4) `- name: Uninstall incompatible Docker-py Module`.

```
# (HIDDEN)
docker exec -it zdm-ansible-container bash
# once in ...
nano /home/ubuntu/zdm-proxy-automation/ansible/deploy_zdm_proxy.yml
# (comment the tasks, save and exit)
exit # the container
```

(HIDDEN) Also we must change the non-root user in the "ZDM host" (actually the Gitpod instance)
to be `gitpod` and not `ubuntu`. This affects the inventory and the root-dir setting in the vars:

```
# (HIDDEN)
docker exec -it zdm-ansible-container bash
# once in ...
sed -i 's/ansible_user=ubuntu/ansible_user=gitpod/' /home/ubuntu/zdm-proxy-automation/ansible/zdm_ansible_inventory
sed 's/home\/ubuntu/home\/gitpod/' /home/ubuntu/zdm-proxy-automation/ansible/vars/zdm_playbook_internal_config.yml -i
exit # the container
```

(HIDDEN) More trouble with the network interfaces and ipv4 addresses. The default_ipv4 from the ansible templates
would use eth0 or something, hence 10.0.5.2 or something. Not the docker0 one (known to ansible in different ways).
So we also edit file `templates/zdm_proxy_immutable_config.j2`, replacing `hostvars[inventory_hostname]['ansible_default_ipv4']['address']` with `inventory_hostname` (3 locations).
Same for the rolling update and restart.
**TODO** check if this might suggest a generalization of the playbook useful beyond the scenario.

```
# (HIDDEN)
sed "s/hostvars\[inventory_hostname\]\['ansible_default_ipv4'\]\['address'\]/inventory_hostname/" /home/ubuntu/zdm-proxy-automation/ansible/templates/zdm_proxy_immutable_config.j2 -i
sed "s/hostvars\[inventory_hostname\]\['ansible_default_ipv4'\]\['address'\]/inventory_hostname/" /home/ubuntu/zdm-proxy-automation/ansible/rolling_update_zdm_proxy.yml -i
sed "s/hostvars\[inventory_hostname\]\['ansible_default_ipv4'\]\['address'\]/inventory_hostname/" /home/ubuntu/zdm-proxy-automation/ansible/rolling_restart_zdm_proxy.yml -i
```

### Configure, deploy and start ZDM proxy

Go to a shell on the `adm-ansible-container` with:

```
docker exec -it zdm-ansible-container bash
```

Once in the container, edit the proxy core configuration with:

```
cd zdm-proxy-automation/
nano ansible/vars/zdm_proxy_core_config.yml   # or use 'vi' if you prefer
```

Uncomment and edit the following entries:

- `origin_username` and `origin_password`: set both to "cassandra" (no quotes);
- `origin_contact_points`: set it to the IP of `cassandra-origin-1`. **TODO** that would be the output of `docker inspect cassandra-origin-1 | jq -r '.[].NetworkSettings.Networks.zdm_network.IPAddress'`, but we will provide it to the user - no need for them to see behind the scenes;
- `origin_port`: set to 9042;
- `target_username` and `target_password`: set to Client ID and Client Secret from your Astra DB "R/W User Token";
- `target_astra_db_id` is your Database ID from the Astra DB dashboard;
- `target_astra_token` is the "token" string in your Astra DB "R/W User Token" (the string starting with `AstraCs:...`).

You can now run the Ansible playbook that will provision and start the proxy containers in the three proxy hosts: still in the Ansible container, launch the command:

```
cd /home/ubuntu/zdm-proxy-automation/ansible
ansible-playbook deploy_zdm_proxy.yml -i zdm_ansible_inventory
```

and watch the show.

### Deploy the monitoring stack

**TODO** as soon as the `systemd` requirement is met in the Ubuntu box containers.

### Connect client applications to proxy

On the base machine, make sure that `client_application/.env` has the
`ZDM_PROXY_SEED` correctly set up with the IP of the first proxy host,
then Ctrl-C the API and restart as:

```
CLIENT_CONNECTION_MODE=ZDM_PROXY uvicorn api:app
```

You can issue some `curl` commands as above to check that both reads and writes
work. Note that you are still reading from Origin, but writing to both.

You can also go to the Astra UI (or cqlsh to it) to check that newly-inserted
rows (and only these for now) are present on Target, that is, Astra DB.

## Phase 2: Migrate and validate data

We will use DSBulk Migrator (in this demo there is a single simple table,
and the one-off migration is not the main focus of this exercise anyway).

On the base machine, clone and build the utility
(the migration will be performed from this machine):

```
cd /workspace/zdm-scenario-draft/one_off_migration
git clone https://github.com/datastax/dsbulk-migrator.git
cd dsbulk-migrator/
mvn clean package
```

After this finishes, you can start the migration, providing the necessary
connection and schema information (the "import cluster" will be Origin and
the "export cluster" will be Astra DB):

**TODO** remind user of the info-collecting script here, but have them fill
out the command below themselves, for better understanding:

```
java -jar target/dsbulk-migrator-1.0.0-SNAPSHOT-embedded-dsbulk.jar \
  migrate-live \
  -e \
  --keyspaces=my_application_ks \
  --export-host=IP_OF_CASSANDRA_ORIGIN_1_MACHINE \
  --export-username=cassandra \
  --export-password=cassandra \
  --import-username=ASTRA_DB_TOKEN_CLIENT_ID \
  --import-password=ASTRA_DB_TOKEN_CLIENT_SECRET \
  --import-bundle=/PATH/TO/SECURE-CONNECT-BUNDLE.ZIP
```

Once this command has executed, you will see that now _all_ rows are on Astra
DB as well, including those written prior to setting up the ZDM proxy.
From this point on, the data on Target will not diverge from Origin until
you decide to cut over and neglect Origin altogether.

## Phase 3: Enable asynchronous dual reads

**TODO**: to keep an eye on proxy restarts and everything,
it might be desirable to keep a view on `sudo docker logs -f ...`
commands on the ZDM Proxy containers.
To stick to real life, this is better achieved instructing the user
to ssh and then call `sudo docker logs` (as opposed to the shortcut):

```
# In a new console:
ssh -i zdm_host_private_key/zdm_deploy_key gitpod@$ZDM_HOST_IP -o StrictHostKeyChecking=no
# once there...
docker logs -f zdm-proxy-container
```

To enable read mirroring, open a shell in the `zdm-ansible-container` and edit
`zdm_proxy_core_config.yml`:

```
docker exec -it zdm-ansible-container bash
cd zdm-proxy-automation/
nano ansible/vars/zdm_proxy_core_config.yml   # or use 'vi' if you prefer
```

The `primary_cluster` should still be `ORIGIN` at this point. Change the
`read_mode` from `PRIMARY_ONLY` to `DUAL_ASYNC_ON_SECONDARY`.

> **TODO** this playbook does not install (the regular, undesired here) docker-ce,
> but it uninstalls a "python incompatible module", which we would like to remove here as well.
> This means we should comment task `- name: Uninstall incompatible Docker-py Module` from
> the `/home/ubuntu/zdm-proxy-automation/ansible/rolling_update_zdm_proxy.yml` playbook.

While still in the Ansible container, launch a rolling update of the ZDM containers with:

```
cd /home/ubuntu/zdm-proxy-automation/ansible
ansible-playbook rolling_update_zdm_proxy.yml -i zdm_ansible_inventory
```

The logs from the containers will stop one after the other: if you restart the
`sudo docker logs` commands, you will see a very long line being logged that starts
with something like

```
time="2022-10-21T22:43:15Z" level=info msg="Parsed configuration: {\"PrimaryCluster\":\"ORIGIN\",\"ReadMode\":\"DUAL_ASYNC_ON_SECONDARY\" [...]
```

To confirm that everything still works, send some `curl` requests to the
running API (reading and writing) if you want.

## Phase 4: Change read routing to Target

The migration is done and the dual reads confirm everything works and
there are no performance problems: let's start reading from Target already!

Go to the `zdm-ansible-container` again and edit
`zdm_proxy_core_config.yml` once more, this time changing `primary_cluster`
to `TARGET`; then launch another rolling update.

Again, you'll see the logs stopping - restart them if you want and look for
the new setting being logged. Also send some requests to your API as before.

Now, Target is the functioning primary, but origin is still being kept
completely up to date.

## Phase 5: Connect your client applications directly to Target

Until now we can bail out any time. After the following change we are effectively
committing to the migration, with the app directly writing to Astra DB and finally
skipping the ZDM (and Origin) altogether.

Go to the console, on the base machine, where the API is running, Ctrl-C
to stop it and restart it this time with: 

```
CLIENT_CONNECTION_MODE=ASTRA_DB uvicorn api:app
```

The API will still work and the migration is complete. You can destroy
the whole ZDM infrastructure at this point.

## Epilogue: cleanup

You can stop and remove the container running the `zdm-ansible-container`:
on the base machine, launch

```
docker rm -f zdm-ansible-container
```

In a real migration scenario, you would also decommission the machines running
the ZDM hosts and even the Origin Cassandra cluster. In this demo you can skip
these steps (they will be removed anyway when the exercise is over).

> In case cleanup is needed, six machines and one Docker network can be
> destroyed at this point:

```
# HIDDEN
docker rm -f zdm-proxy-container
docker rm -f cassandra-origin-1
docker rm -f cassandra-origin-2
docker rm -f cassandra-origin-3
```

Congratulations, you completed the ZDM Migration Scenario!
