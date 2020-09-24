#!/bin/bash

set -x

for podname in $(kubectl get pod -n kube-system -l k8s-app=cilium -o custom-columns=NAME:.metadata.name --no-headers)
do
    echo "****** $podname"
    kubectl exec -n kube-system $podname -- cilium version
    kubectl exec -n kube-system $podname -- cilium status
done

kubectl get configmap -n kube-system cilium-config -o json

kubectl get pods
