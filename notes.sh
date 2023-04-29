# https://github.com/mmumshad/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md

# Copying vagrant machines private_keys into wsl2
 # (in the directory you ran the vagrant up command from) at the below path for each VM
for i in $(ls -1 vagrant/.vagrant/machines/); do cp vagrant/.vagrant/machines/$i/virtualbox/private_key ~/.ssh/k8s-hard-way-$i-private-key; done

# Updated /etc/ssh/ssh_config in wsl2 
sudo vim /etc/ssh/ssh_config
...
Host master-1
  HostName grizzly.local
  User vagrant
  Port 2711
  IdentityFile ~/.ssh/k8s-hard-way-master-1-private-key
Host master-2
  HostName grizzly.local
  User vagrant
  Port 2712
  IdentityFile ~/.ssh/k8s-hard-way-master-2-private-key
Host worker-1
  HostName grizzly.local
  User vagrant
  Port 2721
  IdentityFile ~/.ssh/k8s-hard-way-worker-1-private-key
Host worker-2
  HostName grizzly.local
  User vagrant
  Port 2722
  IdentityFile ~/.ssh/k8s-hard-way-worker-2-private-key
Host lb
  HostName grizzly.local
  User vagrant
  Port 2730
  IdentityFile ~/.ssh/k8s-hard-way-loadbalancer-private-key

# On master generate the key and copy public across all nodes in the cluster
ssh-keygen

# copy master-1 public key across all nodes
cat >> ~/.ssh/authorized_keys <<EOF
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDmhV8hnPNIxrIkQ9L3e7pzygEYJ8I42vTR0eMk4wUvVXBFSgVEkYKeHL1EB+1ybGs0jXAQeLr1sNB1Q7lcfpraW+FSfyFkiENqsagY8z78xQdnmBCxELcpqof9W24Hv517a3ugeoM92BjmTMHbFqqVZBX/9j2X9clUVtT6Zoq30dzbXytuvi4dl2bGKlv8F4dNsNQ5Hl9FKLMFIS/9Y/jjQxpw39AXINr/QEE7fmOCDFsezlJpZl4ghyTevUU55/LVF41OhyjwjgAh04xu1szHQWrY1ntD1ALsPPsoc33r60VONMbTdI0+LwWIiBu41RXz75aac8w1OJ5mkseKhjMJisfRrSd563ES8h7WZvgPa6XRaR8jQ3a92f9Pk8aO5Q66Kmz3p4W3RuXz4FmCNG8L6AsN/SmTey6XNBKvZzQN4z/bkpn77EUkerXvT3/oQHNj0hOVA+tP9b8AqWKZ4Het1/4VOhHNa+ZfUnB0+1f22uQ1ypePPPXS2uIPCCLzUZ8= vagrant@master-1
EOF

# ssh-copy-id -i ~/.ssh/id_rsa.pub vagrant@master-1
# for i in loadbalancer master-1 master-2 worker-1 worker-2; do echo ssh-copy-id -i ~/.ssh/id_rsa.pub vagrant@$i; done
# didn't found the way how to update authorized_keys file to replace new pub key, did it manually

# install kubectl
wget https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/linux/amd64/kubectl

chmod +x kubectl

sudo mv kubectl /usr/local/bin/

### CA ###
# In this lab you will provision a PKI Infrastructure using the popular openssl tool, then use it to bootstrap a Certificate Authority, and generate TLS certificates for 
# the following components: etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, and kube-proxy.

## Certificate Authority ##

# Create private key for CA
openssl genrsa -out ca.key 2048
#openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA" -out ca.csr
openssl req -new -key ca.key -subj "/CN=KUBERNETES-CA/O=Kubernetes" -out ca.csr
openssl x509 -req -in ca.csr -signkey ca.key -CAcreateserial  -out ca.crt -days 1000


# Result
ca.key # ca.crt is the Kubernetes Certificate Authority certificate
ca.crt # ca.key is the Kubernetes Certificate Authority private key

### Client and Server Certificates ###
# In this section you will generate client and server certificates 
# for each Kubernetes component and a client certificate for the Kubernetes admin user.

## The Admin Client Certificate ###

openssl genrsa -out admin.key 2048
openssl req -new -key admin.key -subj "/CN=admin/O=system:masters" -out admin.csr
openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out admin.crt -days 1000

## Note that the admin user is part of the system:masters group. This is how we are able to perform ##
## any administrative operations on Kubernetes cluster using kubectl utility. ##

# Results:
admin.key
admin.crt
# The admin.crt and admin.key file gives you administrative access. We will configure these to be used with the kubectl tool to perform administrative functions on kubernetes.

## The Kubelet Client Certificates ##
# We are going to skip certificate configuration for Worker Nodes for now. We will deal with them when we configure the workers. For now let's just focus on the control plane components.

## The Controller Manager Client Certificate ##
# Generate the kube-controller-manager client certificate and private key:
openssl genrsa -out kube-controller-manager.key 2048
openssl req -new -key kube-controller-manager.key -subj "/CN=system:kube-controller-manager/O=system:kube-controller-manager" -out kube-controller-manager.csr
openssl x509 -req -in kube-controller-manager.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out kube-controller-manager.crt -days 1000
# Results 
kube-controller-manager.key
kube-controller-manager.crt

## The Kube Proxy Client Certificate ##
# Generate the kube-proxy client certificate and private key:
openssl genrsa -out kube-proxy.key 2048
openssl req -new -key kube-proxy.key -subj "/CN=system:kube-proxy/O=system:node-proxier" -out kube-proxy.csr
openssl x509 -req -in kube-proxy.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out kube-proxy.crt -days 1000
# Results:
kube-proxy.key
kube-proxy.crt

## The Scheduler Client Certificate
# Generate the kube-scheduler client certificate and private key:
openssl genrsa -out kube-scheduler.key 2048
openssl req -new -key kube-scheduler.key -subj "/CN=system:kube-scheduler/O=system:kube-scheduler" -out kube-scheduler.csr
openssl x509 -req -in kube-scheduler.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out kube-scheduler.crt -days 1000
# Results:
kube-scheduler.key
kube-scheduler.crt

## The Kubernetes API Server Certificate
# The kube-apiserver certificate requires all names that various components may reach it to be part of the alternate names. 
# These include the different DNS names, and IP addresses such as the master servers IP address, the load balancers IP address, 
# the kube-api service IP address etc.

# The openssl command cannot take alternate names as command line parameter. So we must create a conf file for it:
cat > openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 10.96.0.1
IP.2 = 192.168.56.11
IP.3 = 192.168.56.12
IP.4 = 192.168.56.30
IP.5 = 127.0.0.1
EOF

# Generates certs for kube-apiserver
openssl genrsa -out kube-apiserver.key 2048
openssl req -new -key kube-apiserver.key -subj "/CN=kube-apiserver/O=Kubernetes" -out kube-apiserver.csr -config openssl.cnf
openssl x509 -req -in kube-apiserver.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out kube-apiserver.crt -extensions v3_req -extfile openssl.cnf -days 1000
# Results:
kube-apiserver.crt
kube-apiserver.key

# The Kubelet Client Certificate
# This certificate is for the api server to authenticate with the kubelets when it requests information from them

cat > openssl-kubelet.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[v3_req]
basicConstraints = critical, CA:FALSE
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
EOF

openssl genrsa -out apiserver-kubelet-client.key 2048
openssl req -new -key apiserver-kubelet-client.key -subj "/CN=kube-apiserver-kubelet-client/O=system:masters" -out apiserver-kubelet-client.csr -config openssl-kubelet.cnf
openssl x509 -req -in apiserver-kubelet-client.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out apiserver-kubelet-client.crt -extensions v3_req -extfile openssl-kubelet.cnf -days 1000

# Results:
apiserver-kubelet-client.crt
apiserver-kubelet-client.key

## The ETCD Server Certificate
# Similarly ETCD server certificate must have addresses of all the servers part of the ETCD cluster
# The openssl command cannot take alternate names as command line parameter. So we must create a conf file for it:

cat > openssl-etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = 192.168.56.11
IP.2 = 192.168.56.12
IP.3 = 127.0.0.1
EOF

#Generates certs for ETCD
openssl genrsa -out etcd-server.key 2048
openssl req -new -key etcd-server.key -subj "/CN=etcd-server/O=Kubernetes" -out etcd-server.csr -config openssl-etcd.cnf
openssl x509 -req -in etcd-server.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out etcd-server.crt -extensions v3_req -extfile openssl-etcd.cnf -days 1000
# Results:
etcd-server.key
etcd-server.crt

## The Service Account Key Pair
# The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as describe in the managing service accounts documentation.

# Generate the service-account certificate and private key:

openssl genrsa -out service-account.key 2048
openssl req -new -key service-account.key -subj "/CN=service-accounts/O=Kubernetes" -out service-account.csr
openssl x509 -req -in service-account.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out service-account.crt -days 1000

# Results:
service-account.key
service-account.crt

# Check
./cert_verify.sh

## Distribute the Certificates
# Copy the appropriate certificates and private keys to each controller instance:

for instance in master-1 master-2; do
  scp ca.crt ca.key kube-apiserver.key kube-apiserver.crt \
    apiserver-kubelet-client.crt apiserver-kubelet-client.key \
    service-account.key service-account.crt \
    etcd-server.key etcd-server.crt \
    kube-controller-manager.key kube-controller-manager.crt \
    kube-scheduler.key kube-scheduler.crt \
    ${instance}:~/
done

for instance in worker-1 worker-2 ; do
  scp ca.crt kube-proxy.crt kube-proxy.key ${instance}:~/
done



### Client Authentication Configs

# In this section you will generate kubeconfig files for the controller manager, kube-proxy, scheduler clients and the admin user.

# The kube-proxy Kubernetes Configuration File

LOADBALANCER=$(dig +short loadbalancer)

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://${LOADBALANCER}:6443 \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-credentials system:kube-proxy \
  --client-certificate=/var/lib/kubernetes/pki/kube-proxy.crt \
  --client-key=/var/lib/kubernetes/pki/kube-proxy.key \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

# The kube-controller-manager Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way \
 --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
 --server=https://127.0.0.1:6443 \
 --kubeconfig=kube-controller-manager.kubeconfig
kubectl config set-credentials system:kube-controller-manager \
 --client-certificate=/var/lib/kubernetes/pki/kube-controller-manager.crt \
 --client-key=/var/lib/kubernetes/pki/kube-controller-manager.key \
 --kubeconfig=kube-controller-manager.kubeconfig
kubectl config set-context default \
 --cluster=kubernetes-the-hard-way \
 --user=system:kube-controller-manager \
 --kubeconfig=kube-controller-manager.kubeconfig
kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

# The kube-scheduler Kubernetes Configuration File

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=/var/lib/kubernetes/pki/ca.crt \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-credentials system:kube-scheduler \
  --client-certificate=/var/lib/kubernetes/pki/kube-scheduler.crt \
  --client-key=/var/lib/kubernetes/pki/kube-scheduler.key \
  --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig
kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

# The admin Kubernetes Configuration File
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig
kubectl config set-credentials admin \
  --client-certificate=admin.crt \
  --client-key=admin.key \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig
kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig
kubectl config use-context default --kubeconfig=admin.kubeconfig

# Copy the appropriate kube-proxy kubeconfig files to each worker instance
for instance in worker-1 worker-2; do
  scp kube-proxy.kubeconfig ${instance}:~/
done

# Copy the appropriate admin.kubeconfig, kube-controller-manager and kube-scheduler kubeconfig files to each controller instance
for instance in master-1 master-2; do
  scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:~/
done

# Optional - Check kubeconfigs
./cert_verify.sh

### Generating the Data Encryption Config and Key

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

# The Encryption Config File
cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

# Copy the encryption-config.yaml encryption config file to each controller instance:
for instance in master-1 master-2; do
  scp encryption-config.yaml ${instance}:~/
done

# Move encryption-config.yaml encryption config file to appropriate directory.
for instance in master-1 master-2; do
  ssh ${instance} sudo mkdir -p /var/lib/kubernetes/
  ssh ${instance} sudo mv encryption-config.yaml /var/lib/kubernetes/
done


### Bootstrapping the etcd Cluster

wget -q --show-progress --https-only --timestamping "https://github.com/coreos/etcd/releases/download/v3.5.3/etcd-v3.5.3-linux-amd64.tar.gz"
tar -xvf etcd-v3.5.3-linux-amd64.tar.gz
sudo mv etcd-v3.5.3-linux-amd64/etcd* /usr/local/bin/

# Configure the etcd Server
# Copy and secure certificates. Note that we place ca.crt in our main PKI directory and link it from etcd to not have multiple copies of the cert lying around.

sudo mkdir -p /etc/etcd /var/lib/etcd /var/lib/kubernetes/pki
sudo cp etcd-server.key etcd-server.crt /etc/etcd/
sudo cp ca.crt /var/lib/kubernetes/pki/
sudo chown root:root /etc/etcd/*
sudo chmod 600 /etc/etcd/*
sudo chown root:root /var/lib/kubernetes/pki/*
sudo chmod 600 /var/lib/kubernetes/pki/*
sudo ln -s /var/lib/kubernetes/pki/ca.crt /etc/etcd/ca.crt

# The instance internal IP address will be used to serve client requests and communicate with etcd cluster peers.
# Retrieve the internal IP address of the master(etcd) nodes, and also that of master-1 and master-2 for the etcd cluster member list

INTERNAL_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f 1)
MASTER_1=$(dig +short master-1)
MASTER_2=$(dig +short master-2)

# Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname of the current compute instance:
ETCD_NAME=$(hostname -s)

# Create the etcd.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/etcd-server.crt \\
  --key-file=/etc/etcd/etcd-server.key \\
  --peer-cert-file=/etc/etcd/etcd-server.crt \\
  --peer-key-file=/etc/etcd/etcd-server.key \\
  --trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster master-1=https://${
    MASTER_1}:2380,master-2=https://${MASTER_2}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd

# Verification
# List the etcd cluster members:

sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/etcd-server.crt \
  --key=/etc/etcd/etcd-server.key


### Bootstrapping the Kubernetes Control Plane

## Provision the Kubernetes Control Plane

# Download and Install the Kubernetes Controller Binaries

wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.24.3/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.24.3/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.24.3/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.24.3/bin/linux/amd64/kubectl"

chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/

# Configure the Kubernetes API Server
sudo mkdir -p /var/lib/kubernetes/pki
# Only copy CA keys as we'll need them again for workers.
sudo cp ca.crt ca.key /var/lib/kubernetes/pki

for c in kube-apiserver service-account apiserver-kubelet-client etcd-server kube-scheduler kube-controller-manager

do
  sudo mv "$c.crt" "$c.key" /var/lib/kubernetes/pki/
done

sudo chown root:root /var/lib/kubernetes/pki/*
sudo chmod 600 /var/lib/kubernetes/pki/*

INTERNAL_IP=$(ip addr show enp0s8 | grep "inet " | awk '{print $2}' | cut -d / -f 1)
LOADBALANCER=$(dig +short loadbalancer)
MASTER_1=$(dig +short master-1)
MASTER_2=$(dig +short master-2)

# CIDR ranges used within the cluster
POD_CIDR=10.244.0.0/16
SERVICE_CIDR=10.96.0.0/16

# Create the kube-apiserver.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=2 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/pki/ca.crt \\
  --enable-admission-plugins=NodeRestriction,ServiceAccount \\
  --enable-bootstrap-token-auth=true \\
  --etcd-cafile=/var/lib/kubernetes/pki/ca.crt \\
  --etcd-certfile=/var/lib/kubernetes/pki/etcd-server.crt \\
  --etcd-keyfile=/var/lib/kubernetes/pki/etcd-server.key \\
  --etcd-servers=https://${MASTER_1}:2379,https://${MASTER_2}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/pki/ca.crt \\
  --kubelet-client-certificate=/var/lib/kubernetes/pki/apiserver-kubelet-client.crt \\
  --kubelet-client-key=/var/lib/kubernetes/pki/apiserver-kubelet-client.key \\
  --runtime-config=api/all=true \\
  --service-account-key-file=/var/lib/kubernetes/pki/service-account.crt \\
  --service-account-signing-key-file=/var/lib/kubernetes/pki/service-account.key \\
  --service-account-issuer=https://${LOADBALANCER}:6443 \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/pki/kube-apiserver.crt \\
  --tls-private-key-file=/var/lib/kubernetes/pki/kube-apiserver.key \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubernetes Controller Manager

sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/

# Create the kube-controller-manager.service systemd unit file:
cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --authentication-kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --authorization-kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --bind-address=127.0.0.1 \\
  --client-ca-file=/var/lib/kubernetes/pki/ca.crt \\
  --cluster-cidr=${POD_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/pki/ca.crt \\
  --cluster-signing-key-file=/var/lib/kubernetes/pki/ca.key \\
  --controllers=*,bootstrapsigner,tokencleaner \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --node-cidr-mask-size=24 \\
  --requestheader-client-ca-file=/var/lib/kubernetes/pki/ca.crt \\
  --root-ca-file=/var/lib/kubernetes/pki/ca.crt \\
  --service-account-private-key-file=/var/lib/kubernetes/pki/service-account.key \\
  --service-cluster-ip-range=${SERVICE_CIDR} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Configure the Kubernetes Scheduler
sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --kubeconfig=/var/lib/kubernetes/kube-scheduler.kubeconfig \\
  --leader-elect=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Secure kubeconfigs
sudo chmod 600 /var/lib/kubernetes/*.kubeconfig

# Start the Controller Services

sudo systemctl daemon-reload
sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler

# Verification
kubectl get componentstatuses --kubeconfig admin.kubeconfig

### The Kubernetes Frontend Load Balancer
# In this section you will provision an external load balancer to front the Kubernetes API Servers. The kubernetes-the-hard-way static IP address will be attached to the resulting load balancer.

## Provision a Network Load Balancer
# A NLB operates at layer 4 (TCP) meaning it passes the traffic straight through to the back end servers unfettered and does not interfere with the TLS process, leaving this to the Kube API servers.

sudo apt-get update && sudo apt-get install -y haproxy

# Read IP addresses of master nodes and this host to shell variables
MASTER_1=$(dig +short master-1)
MASTER_2=$(dig +short master-2)
LOADBALANCER=$(dig +short loadbalancer)

cat <<EOF | sudo tee /etc/haproxy/haproxy.cfg
frontend kubernetes
    bind ${LOADBALANCER}:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes

backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
    server master-1 ${MASTER_1}:6443 check fall 3 rise 2
    server master-2 ${MASTER_2}:6443 check fall 3 rise 2
EOF

sudo systemctl restart haproxy

# Verification
curl  https://${LOADBALANCER}:6443/version -k

### Installing CRI on the Kubernetes Worker Nodes
CONTAINERD_VERSION=1.5.9
CNI_VERSION=0.8.6
RUNC_VERSION=1.1.1
wget -q --show-progress --https-only --timestamping \
  https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz \
  https://github.com/containernetworking/plugins/releases/download/v${CNI_VERSION}/cni-plugins-linux-amd64-v${CNI_VERSION}.tgz \
  https://github.com/opencontainers/runc/releases/download/v${RUNC_VERSION}/runc.amd64
sudo mkdir -p /opt/cni/bin
sudo chmod +x runc.amd64
sudo mv runc.amd64 /usr/local/bin/runc
sudo tar -xzvf containerd-${CONTAINERD_VERSION}-linux-amd64.tar.gz -C /usr/local
sudo tar -xzvf cni-plugins-linux-amd64-v${CNI_VERSION}.tgz -C /opt/cni/bin

#  create the containerd service unit

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable containerd
sudo systemctl start containerd


### Bootstrapping the Kubernetes Worker Nodes

## Provisioning Kubelet Client Certificates

# Generate a certificate and private key for one worker node
# On master-1
WORKER_1=$(dig +short worker-1)

cat > openssl-worker-1.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = worker-1
IP.1 = ${WORKER_1}
EOF

openssl genrsa -out worker-1.key 2048
openssl req -new -key worker-1.key -subj "/CN=system:node:worker-1/O=system:nodes" -out worker-1.csr -config openssl-worker-1.cnf
openssl x509 -req -in worker-1.csr -CA ca.crt -CAkey ca.key -CAcreateserial  -out worker-1.crt -extensions v3_req -extfile openssl-worker-1.cnf -days 1000






