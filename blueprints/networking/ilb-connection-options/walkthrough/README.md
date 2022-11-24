# ILB features walkthrough

- [L4 ILB, NLB Options for Connection Tracking User Guide](https://docs.google.com/document/d/1LhE5rBUBHnfFxRrmD7TOmje_45RBlXTNTAUkFOYrzgc/edit)

Create a `terraform.tfvars` file with your specific configuration.

```bash
cat <<END >terraform.tfvars
project_id = "<your project id>"
subnet     = "<your vpc subnet self link>"
vpc        = "<your vpc self link>"
END
```

Bring up the infrastructure

```bash
terraform init
terraform apply
```

Then export the ILB address as a variable.

```bash
eval `tf output -raw env_vars`
```

## Stable state with all healthy backends

![](both%20backends%20healthy.png)

Test that both backends are serving with a client cycling requests.

```bash
watch -n1 "date |nc -N $ILB 7"
```

Connect a second client with a persistent connection.

```bash
nc $ILB 7
# type something to check which host is serving
```

Monitor backend state.

```bash
watch -n1 "\
  gcloud compute backend-services get-health test-default \
   --format 'value(status.healthStatus.healthState)'\
"
```

## Default behaviour: Connection persisting on unhealthy backend

![](persisted%20connection%20to%20unhealthy%20backend.png)

Stop the health service on the backend serving the persistent connection.

```bash
gcloud compute ssh test-0 -- \
  sudo systemctl stop echo-health
```

Wait for it to become unhealthy, then verify the client using a persistent connection is still using the backend.

## Detour: Session affinity and Connection Tracking

> *Packets belonging to the same connection are directed to the same service endpoint*, so that the system is resilient to changes and unexpected failures. This is provided by a *combination of Consistent Hashing and Connection Tracking* support.
>
> Once a packet is matched to the load balancer’s Forwarding Rule, the packet’s connection information is first looked up in a local Connection Tracking table. If the connection information is not already there, the load balancer will select a backend for the connection using a Consistent Hashing algorithm, and record that in the Connection Tracking table.

What are the defaults used when no Session Affinity is specified?

| Packet’s Protocol | Connection Tracking | Connection Key | Persist Connections On Unhealthy Backends |
| ----------------- | ------------------- | -------------- | ----------------------------------------- |
| TCP               | ON                  | 5-tuple        | TRUE                                      |
| UDP               | ON                  | 5-tuple        | FALSE                                     |
| other             | ON                  | 3-tuple        | FALSE                                     |

You can influence Connection Tracking behaviour by defining a Tracking Policy for the regional backend service. The policy supports three settings:

- Tracking Mode<br>
  *only if Session Affinity is != from NONE or CLIENT_IP_PORT_PROTO*<br>
  `PER_CONNECTION`: use 5-tuple key for tracking with more coarse grained Session Affinity<br>
  `PER_SESSION`: use same key for tracking as configured Session Affinity
- Connection Persistence On Unhealthy Backends<br>
  `DEFAULT_FOR_PROTOCOL`: persist for connection-oriented protocols<br>
  `NEVER_PERSIST`: divert connections on unhealthy backend<br>
  `ALWAYS_PERSIST`: always persist regardless of protocol, if tracking mode is not per session
- Idle Timeout<br>
  how long to keep a Connection Tracking entry if Session Affinity < 5-tuple and Tracking Mode is per session, otherwise default to 10m

*using per connection tracking with coarser session affinity might change the selected backend for a new connection when backends are added or removed*

## Disabling connection persistence

![](persisted%20connection%20disabled.png)

Let's try changing the default behaviour on unhealthy backend.

```bash
gcloud compute ssh test-0 -- \
  sudo systemctl start echo-health
gcloud compute backend-services update test-default \
  --connection-persistence-on-unhealthy-backends NEVER_PERSIST
```

Re-establish a persistent connection then bring down the health service on the relevant backend.

```bash
nc $ILB 7
gcloud compute ssh test-0 -- \
  sudo systemctl start echo-health
```

The connection is now closed as soon as the backend is marked as unhealthy.

## Connection tracking mode

Let's see how Session Affinity and Connectiom Tracking mode interact.

If you don't have it running already, launch a client doing repeated connections, which will cycle through both active backends.

```bash
watch -n1 "date |nc -N $ILB 7"
```

Change Session Affinity to be less granular so that client will stick to one backend.

```bash
gcloud compute backend-services update test-default \
  --session-affinity CLIENT_IP
```

Now bring down the backend used by the client so that it switches to the other backend.

```bash
gcloud compute ssh test-1 -- \
  sudo systemctl stop echo-health
```

Once you re-enable the backend connections will switch there overriding session affinity.

```bash
gcloud compute ssh test-1 -- \
  sudo systemctl start echo-health
```

> The key for connection tracking (e.g. 5-tuple for TCP packets) can be more specific than the configured Session Affinity setting (say 3-tuple for TCP packets). As a result, the session affinity may be split if the set of backends or their health changes. That is, if a session is already made sticky to a backend, new connections for that session may select a different backend. In certain scenarios, this might be desirable; for example, to achieve better load balancing after an auto-scaler adds more backends (though it splits some affinities).

You can repat the test after switching the connection tracking mode to per session to prevent this from happening.

```bash
gcloud compute ssh test-1 -- \
  sudo systemctl stop echo-health
gcloud compute backend-services update test-default \
  --tracking-mode PER_SESSION
gcloud compute ssh test-1 -- \
  sudo systemctl start echo-health
```

## Default behaviour: distribute connections on unhealthy backends

![](distribute%20connections%20on%20unhealthy.png)

Stop the health service on both instances the second instances then verify the client cycling connections is connecting to both backends.

```bash
gcloud compute ssh test-0 -- \
  sudo systemctl stop echo-health
gcloud compute ssh test-1 -- \
  sudo systemctl stop echo-health
```

## Configuring failover policy to drop connections

![](drop%20connections%20on%20unhealthy.png)

Connections can be dropped if all backends are unhealthy by configuring a Failover Policy, which requires an extra backend marked as failover. The failover backend needs at least one instance.

```bash
terraform apply -var enable_failover=true
```
