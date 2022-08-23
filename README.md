# oaic w/ Docker and kind

### Requirements:
- [Go](https://go.dev/doc/install) (can be installed with `sudo apt install golang-go` or through website)
- [Docker](https://docs.docker.com/engine/install/) (both Engine and Desktop versions will work)
- kubectl (Install with `sudo apt install kubectl`)

### Installing kind:

On new versions of Go, use this command to install kind:
`go install sigs.k8s.io/kind@v0.14.0`

If you installed Go using apt and/or are using an older version, run this command to install kind:
`GO111MODULE=on go get sigs.k8s.io/kind@v0.14.0`

### Deploying kind

To deploy kind, simply run `./deploy_kind.sh` or `deploy_kind.bat` depending on your operating system.

It will run the following commands:
- Starting the cluster: `kind create cluster --image=kindest/node:v1.16.15 --config=$SCRIPT_DIR/config.yaml`
- Copying the kind configuration to the current folder: `cp ~/.kube/config config`

### Preparation

Next, you will have to change the config to work in Docker instead. There should be a new `config` file in the directory which you can edit: `nano config`

Open the config. You should see a line with text similar to this: `server: https://127.0.0.1:41559`. Change `127.0.0.1` to `host.docker.internal` so that it reads like this: `server: https://host.docker.internal:41559`
Note that you will almost certainly not have the same 41559 port, so do not change the number that is in your config file.

Save the config changes (if using nano, CTRL+X then Y then ENTER).

If you remove the kind container and have to redeploy it again, the above steps need to be done again.

### Building OAIC registry and modified E2 Docker image

From the `oaic` repository, follow these steps:
```bash
sudo docker run -d -p 5001:5000 --restart=always --name ric registry:2
cd ric-plt-e2
cd RIC-E2-TERMINATION
sudo docker build -f Dockerfile -t localhost:5001/ric-plt-e2:5.5.0 .
sudo docker push localhost:5001/ric-plt-e2:5.5.0
cd ../../
```

The Docker registry needs to be running before configuring the kind container below, or else the RIC platform will not deploy.

### Configuring kind with Docker

We will build a Dockerfile which configures the kind container and installs the near-RT RIC to it.

On Windows:
`docker build -t oaic .`

On Linux:
`docker build -t oaic . --network=host`

This will take a while, but when finished, the near-RT RIC should be running.
To confirm this, on the host computer or inside the `kind-control-plane` container, run `kubectl get pods -A`

```
~/oaicinstaller$ sudo kubectl get pods -A
NAMESPACE            NAME                                                         READY   STATUS      RESTARTS   AGE
kube-system          coredns-5644d7b6d9-d6bbp                                     1/1     Running     2          8d
kube-system          coredns-5644d7b6d9-rl5ld                                     1/1     Running     2          8d
kube-system          etcd-kind-control-plane                                      1/1     Running     2          8d
kube-system          kindnet-svzch                                                1/1     Running     2          8d
kube-system          kube-apiserver-kind-control-plane                            1/1     Running     2          8d
kube-system          kube-controller-manager-kind-control-plane                   1/1     Running     2          8d
kube-system          kube-flannel-ds-zp5pt                                        1/1     Running     2          8d
kube-system          kube-proxy-p77w2                                             1/1     Running     2          8d
kube-system          kube-scheduler-kind-control-plane                            1/1     Running     2          8d
kube-system          tiller-deploy-7d7bc87bb-fc2vf                                1/1     Running     2          8d
local-path-storage   local-path-provisioner-69f585cbc-rw9kb                       1/1     Running     2          8d
ricinfra             deployment-tiller-ricxapp-557dbcf8b-vsgqx                    1/1     Running     1          8d
ricinfra             nfs-release-1-nfs-server-provisioner-0                       1/1     Running     2          8d
ricinfra             tiller-secret-generator-pqk5m                                0/1     Completed   0          8d
ricplt               deployment-ricplt-a1mediator-6ccd8896d7-lh4g9                1/1     Running     3          8d
ricplt               deployment-ricplt-alarmmanager-56d79dc55-bg89x               1/1     Running     1          8d
ricplt               deployment-ricplt-appmgr-8f7467877-xbqgh                     1/1     Running     2          8d
ricplt               deployment-ricplt-e2mgr-66cdc4d6b6-k9k9k                     1/1     Running     4          8d
ricplt               deployment-ricplt-e2term-alpha-84d4db76d6-xrm6s              0/1     Running     2          8d
ricplt               deployment-ricplt-jaegeradapter-76ddbf9c9-qntqr              1/1     Running     1          8d
ricplt               deployment-ricplt-o1mediator-677ff764d7-mc97v                1/1     Running     1          8d
ricplt               deployment-ricplt-rtmgr-578c64f5cf-447pr                     1/1     Running     9          8d
ricplt               deployment-ricplt-submgr-7f6499555d-v6b5q                    1/1     Running     3          8d
ricplt               deployment-ricplt-vespamgr-84f7d87dfb-567nv                  1/1     Running     2          8d
ricplt               r4-infrastructure-kong-646b68bd88-ctjkf                      2/2     Running     61         8d
ricplt               r4-infrastructure-prometheus-alertmanager-75dff54776-5klsf   2/2     Running     4          8d
ricplt               r4-infrastructure-prometheus-server-5fd7695-p29z8            1/1     Running     2          8d
ricplt               statefulset-ricplt-dbaas-server-0                            1/1     Running     2          8d
```

If some pods are experiencing CrashLoopBackOff or other errors, you may need to restart Docker (`sudo systemctl restart docker`) or restart your computer.

srsRAN with E2 Agent should be able to communicate with the near-RT RIC and xApps should be deployable. You can also try building srsRAN in Docker using `docker build -t oaic_srsran . -f Dockerfile_srsran`.
