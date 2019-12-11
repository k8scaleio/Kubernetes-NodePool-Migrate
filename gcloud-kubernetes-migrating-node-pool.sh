#!/usr/bin/env bash


#########################
# The command line help #
#########################
USAGE="
Usage: 
    sh gcloud-kubernetes-migrating-node-pool.sh CLUSTER_NAME EXISTING_NODE_POOL NEW_NODE_POOL NEW_MACHINE_TYPE NUM_NODED


Example:
    sh gcloud-kubernetes-migrating-node-pool.sh interviewparrot-test-cluster default-pool larger-pool n1-highmem-2 3"
case $1 in
 -h) echo "$USAGE\n"; exit 0 ;;
  h) echo "$USAGE\n"; exit 0 ;;
  help) echo "$USAGE\n"; exit 0 ;;
esac

CLUSTER_NAME=$1
EXISTING_NODE_POOL=$2
NEW_NODE_POOL=$3
NEW_MACHINE_TYPE=$4
NUM_NODES=$5

echo "Cluster name=$CLUSTER_NAME\n"
echo "Existing NodePool=$EXISTING_NODE_POOL\n"
echo "New NodePool=$NEW_NODE_POOL\n"
echo "New machine=$NEW_MACHINE_TYPE\n"
echo "Number of Nodes=$NUM_NODES\n"
echo "\n"

echo -n "Is above information correct (y/n)? "
read answer
if [ "$answer" != "${answer#[Yy]}" ] ;then
    echo "Step 1: Create a node pool with given machine type\n"
    gcloud container node-pools create $NEW_NODE_POOL --cluster=$CLUSTER_NAME --machine-type=$NEW_MACHINE_TYPE --num-nodes=$NUM_NODES

    echo "Listing the node pools \n"
    gcloud container node-pools list --cluster iparrot-us-east1-cluster
    kubectl get nodes

    echo "Step 2: Migrate the workloads\n"
    kubectl get pods -o=wide

    echo "Get running nodes in a node pool \n"
    kubectl get nodes -l cloud.google.com/gke-nodepool=$EXISTING_NODE_POOL

    echo "Cordoning each node in existing poo\n"
    for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=$EXISTING_NODE_POOL -o=name); do
      kubectl cordon "$node";
    done

    echo "Now you should see that the $EXISTING_NODE_POOL nodes have SchedulingDisabled status in the node list:\n"
    kubectl get nodes

    echo "Next, drain Pods on each node gracefully\n"
    for node in $(kubectl get nodes -l cloud.google.com/gke-nodepool=prod-high-cpu-pool -o=name); do
      kubectl drain --force --ignore-daemonsets --delete-local-data --grace-period=10 "$node";
    done

    echo "Once this command completes, you should see that the Pods are now running on the $NEW_NODE_POOL nodes:\n"
    kubectl get pods -o=wide

    echo "Step 3: Delete the old node pool\n"
    gcloud container node-pools delete $EXISTING_NODE_POOL --cluster $CLUSTER_NAME
    
else
    echo "Exiting as above information is incorrect\n"
fi
