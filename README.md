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

