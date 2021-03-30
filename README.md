# WIPP-HPC-demo

## Vagrant

```bash
cd vagrant
vagrant up && vagrant ssh k8s-master
```
_NOTE_: `vagrant up` may take about 15 minutes to start as k8s cluster will be installed from scratch.

Vagrant will spin up two VMs: a k8s master running containerd and a k8s worker node running Singularity-CRI with Slurm installed.

Once the virtual `slurm-node-1-debug` node is up, you can add the `wlm.sylabs.io/containers: singularity` label to them: 
`kubectl label nodes slurm-node-1-debug wlm.sylabs.io/containers=singularity`

Then test the `cow.yaml` example:
`kubectl apply -f wlm-operator/examples/cow.yaml`

Check result:
`kubectl logs cow-job`