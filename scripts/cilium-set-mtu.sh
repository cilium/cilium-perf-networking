if [ -z $1 ]; then
    echo 2> "Usage: $0 <mtu>"
fi

kubectl patch  -n kube-system configmap cilium-config --type="merge" --patch="{\"data\": {\"mtu\": \"$1\"}}"
