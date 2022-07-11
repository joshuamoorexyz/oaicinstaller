FROM ubuntu:20.04

#install dependencies
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata
RUN apt-get install -y git ca-certificates curl nfs-common wget

RUN curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
RUN echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

RUN apt-get update
RUN apt-get install -y kubectl

ENV HELMV="2.17.0"
ENV HELMVERSION=${HELMV}

WORKDIR /root
RUN if [ ! -e helm-v${HELMVERSION}-linux-amd64.tar.gz ]; then wget https://get.helm.sh/helm-v${HELMVERSION}-linux-amd64.tar.gz; fi

RUN rm -rf Helm && mkdir Helm
WORKDIR /root/Helm
RUN tar -xvf ../helm-v${HELMVERSION}-linux-amd64.tar.gz
RUN mv linux-amd64/helm /usr/local/bin/helm

WORKDIR /
#clone oaic repo and pull submodules
RUN git clone https://github.com/openaicellular/oaic.git
#RUN git clone https://github.com/joshuamoorexyz/oaic-testing oaic

WORKDIR /oaic
RUN git submodule update --init --recursive

# RUN kubectl config set-credentials kind-kind/kind-kind --username=kind-kind --password=kubepassword
# RUN kubectl config set-cluster kind-kind --insecure-skip-tls-verify=true --server=https://localhost:60086
# RUN kubectl config set-context kind-kind --user=kind-kind/kind-kind --namespace=default --cluster=kind-kind
# RUN kubectl config use-context kind-kind
COPY config /root/.kube/config

# RUN curl https://host.docker.internal:60086/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
# RUN curl https://127.0.0.1:60086/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

#influxdb setup
RUN if [kubectl get ns ricinfra]; then kubectl create ns ricinfra; fi;
RUN helm install stable/nfs-server-provisioner --namespace ricinfra --name nfs-release-1
RUN kubectl patch storageclass nfs -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
# RUN apt install nfs-common

WORKDIR /root

# RUN rm -rf .kube
# RUN mkdir -p .kube
# RUN cp -i /etc/kubernetes/admin.conf /root/.kube/config
# RUN chown root:root /root/.kube/config
# ENV KUBECONFIG=/root/.kube/config
# RUN echo "KUBECONFIG=${KUBECONFIG}" >> /etc/environment

RUN kubectl --insecure-skip-tls-verify get pods --all-namespaces

RUN kubectl --insecure-skip-tls-verify apply -f "https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml"

RUN CMD="kubectl get pods --all-namespaces " && \
  if [ "kube-system" != "all-namespaces" ]; then \
    CMD="kubectl get pods -n 8 "; \
  fi && \
  KEYWORD="Running" && \
  if [ "$#" == "3" ]; then \
    KEYWORD="${3}.*Running"; \
  fi && \
  CMD2="$CMD | grep \"$KEYWORD\" | wc -l" && \
  NUMPODS=$(eval "$CMD2") && \
  echo "waiting for $NUMPODS/8 pods running in namespace [$NS] with keyword [$KEYWORD]" && \
  while [  $NUMPODS -lt $1 ]; do \
    sleep 5; \
    NUMPODS=$(eval "$CMD2"); \
    echo "> waiting for $NUMPODS/8 pods running in namespace [$NS] with keyword [$KEYWORD]"; \
  done 

RUN kubectl taint nodes --all node-role.kubernetes.io/master-

# ENV HELMV="2.17.0"
# ENV HELMVERSION=${HELMV}

# RUN if [ ! -e helm-v${HELMVERSION}-linux-amd64.tar.gz ]; then wget https://get.helm.sh/helm-v${HELMVERSION}-linux-amd64.tar.gz fi

# WORKDIR /root
# RUN rm -rf Helm && mkdir Helm
# WORKDIR /root/Helm
# RUN tar -xvf ../helm-v${HELMVERSION}-linux-amd64.tar.gz
# RUN mv linux-amd64/helm /usr/local/bin/helm

# WORKDIR /root

COPY rbac-config.yaml /root/rbac-config.yaml
RUN kubectl create -f rbac-config.yaml

# RUN rm -rf /root/.helm

RUN helm init --service-account tiller --override spec.selector.matchLabels.'name'='tiller',spec.selector.matchLabels.'app'='helm' --output yaml > /tmp/helm-init.yaml
RUN sed 's@apiVersion: extensions/v1beta1@apiVersion: apps/v1@' /tmp/helm-init.yaml > /tmp/helm-init-patched.yaml
RUN kubectl apply -f /tmp/helm-init-patched.yaml

RUN helm init -c
ENV HELM_HOME="/root/.helm"

RUN while ! helm version; do echo "Waiting for Helm to be ready" && sleep 15 done

RUN echo "Preparing a master node (lowser ID) for using local FS for PV"
RUN kubectl label --overwrite nodes $(kubectl get nodes |grep master | cut -f1 -d' ' | sort | head -1) local-storage=enable

RUN echo "Done with master node setup"

# RUN cp /etc/docker/ca.crt /etc/docker/certs.d/:/ca.crt
# RUN service docker restart
# RUN systemctl enable docker.service
RUN docker login -u  -p  :
RUN docker pull :/whoami:0.0.1

#modified E2 docker image
RUN docker run -d -p 5001:5000 --restart=always --name ric registry:2
WORKDIR /oaic/ric-plt-e2/RIC-E2-TERMINATION
RUN docker build -f Dockerfile -t localhost:5001/ric-plt-e2:5.5.0 .
RUN docker push localhost:5001/ric-plt-e2:5.5.0

#Near real time ric
WORKDIR /oaic/RIC-Deployment/bin
RUN ./deploy-ric-platform -f ../RECIPE_EXAMPLE/PLATFORM/example_recipe_oran_e_release_modified_e2.yaml