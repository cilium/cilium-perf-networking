# Introduction 

https://docs.cilium.io/en/latest/operations/performance/

# Additional Details

## Installing Cilium

[This playbook](playbooks/install-k8s-cilium.yaml) installs cilium using
`kubadm` and `helm`.

### Which cilium versions are supported?

We use [cilium-install-with-helm.sh](scripts/cilium-install-with-helm.sh) script
to install cilium. You can pass a version available in the cilium helm
repo (e.g., ``1.8.3``). You can also pass a version such as ``1.8`` and the script
will try and pick the latest one. Finally, you can also use custom docker images
as the example below:

```
make dev-docker-image
docker image tag cilium/cilium-dev:latest kkourt/cilium-dev:bestciliumever
docker push  kkourt/cilium-dev:bestciliumever
```

And then:
```
ansible-playbook -e mode=directrouting -i packet-hosts.ini playbooks/install-k8s-cilium.yaml -e cilium_version=master:docker.io/kkourt/cilium-dev:bestciliumever
```

Have a look at
[cilium-install-with-helm.sh](scripts/cilium-install-with-helm.sh) for more
details.


## Tuning

Example

```
ANSIBLE_STDOUT_CALLBACK=yaml ansible-playbook -e tuned_profile=network-latency  -i packet-hosts.ini playbooks/tune.yaml
```
