#!/bin/bash

usage() {
    echo "Usage: $0 <version> [helm options]"
    echo "Where version is:"
    echo  "    x.y.z      => version on cilium helm repo"
    echo  "    x.y        => latest x.y version according to cilium's README.md"
    echo  "    master     => latest helm chart from cilium master, and docker.io/cilium/cilium-dev:latest image"
    echo  "    master:xxx => latest helm chart from cilium master, and xxxx image"
}

if [ -z "$1" ]; then
    usage
    exit 1
fi
version=$1
shift

README="https://raw.githubusercontent.com/cilium/cilium/master/README.rst"
# x.y
if echo $version | grep -Eq '^v?[0-9]\.[0-9]$'; then
		case "$version" in
			v1.9|1.9) helm_ver=$(curl -s $README | sed -ne 's/^| `v1\.9.*docker.io\/cilium\/cilium:v\([^`]\+\).*$/\1/p')
                ;;
			v1.8|1.8) helm_ver=$(curl -s $README | sed -ne 's/^| `v1\.8.*docker.io\/cilium\/cilium:v\([^`]\+\).*$/\1/p')
				;;
			v1.7|1.7) helm_ver=$(curl -s $README | sed -ne 's/^| `v1\.7.*docker.io\/cilium\/cilium:v\([^`]\+\).*$/\1/p')
				;;
			v1.6|1.6) helm_ver=$(curl -s $README | sed -ne 's/^| `v1\.6.*docker.io\/cilium\/cilium:v\([^`]\+\).*$/\1/p')
                ;;
            *)
                echo >2 "Unknown version: $version"
                usage
                exit 1
                ;;
        esac
elif echo $version | grep -Eq '^v?[0-9]\.[0-9]\.[0-9]$'; then
    helm_ver=$version
elif [ "$version" == "master" ]; then
    git_ver="master"
    cilium_image="docker.io/cilium/cilium-dev:latest"
elif echo $version | grep -Eq '^master:.*$'; then
    git_ver="master"
    cilium_image=$(echo $version | sed -e 's/^master://')
else
    echo >2 "Unknown version: $version"
    usage
    exit 1
fi

yaml_file=$(pwd)/cilium-install.yaml
if [ -n "$helm_ver" ]; then
    echo "helm_ver:  $helm_ver"
    echo "helm_opts: $@"
    helm repo update
    helm template cilium cilium/cilium --version $helm_ver "$@" > $yaml_file
else
    echo "git_ver:$git_ver cilium_image:$cilium_image"
    curl -s -LO https://github.com/cilium/cilium/archive/$git_ver.tar.gz
    tar zxf $git_ver.tar.gz
    pushd cilium-$git_ver/install/kubernetes
    helm template cilium ./cilium "$@" > $yaml_file
    popd
fi

if [ -n "$cilium_image" ]; then
    echo $cilium_image
    sed -i.orig "s^docker.io/cilium/cilium:latest^$cilium_image^g" $yaml_file
fi

kubectl apply -f $yaml_file
