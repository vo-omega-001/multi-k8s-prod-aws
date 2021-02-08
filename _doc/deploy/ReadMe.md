# DEPLOYMENT TARGET:
  ```diff
  @@Deployment of the Complex application based on k8s on an AWS EC2 "t2.medium" virtual machine which consumes EKS Service and Block Stores.
  "t2.medium" instance is not included in the AWS Free Tier.
  The minimun usable instance type for k8s deployment is the "t2.small" type allowing 11 PODs.@@
  ```



# SET ENVIRONMENT VARIABLES:  
  #### Windows
  ```
  SET WORK_DIR=%CD%\_config
  SET AWS_USER_DIR=%HOMEDRIVE%%HOMEPATH%\.aws
  ```
  #### Linux
  ```
  export WORK_DIR=$(eval pwd)/_config
  export AWS_USER_DIR=$(eval echo ~$USER)/.aws
  ```


# BUILD AND RUN THE DEPLOYER DOCKER CONTENER:  
  #### Windows
  ```
  docker build –f %WORK_DIR%\ci\Dockerfile %WORK_DIR%\ci
  ```
  ###### -> return the contener id
  ```
  docker run  -it  -v %AWS_USER_DIR%:/root/.aws  -v %WORK_DIR%:/work  -w /work  --entrypoint /bin/sh ```CONTENER_ID```
  ```
  #### Linux
  ```
  docker build –f ${WORK_DIR}/ci/Dockerfile ${WORK_DIR}/ci
  ```
  ###### -> return the contener id
  ```
  docker run  -it  -v ${AWS_USER_DIR}:/root/.aws  -v ${WORK_DIR}:/work  -w /work  --entrypoint /bin/sh ```CONTENER_ID```
  ```
  


# DEPLOY THE COMPLEX APP FROM THE DEPLOYER DOCKER CONTENER SHELL: 

## Create a SSH key for Node access with eksctl (if it is required).
  ```
  PASSPHRASE="strong_password"
  EMAIL=deployer_email@domain.com
  ssh-keygen -t rsa -b 4096 -N "${PASSPHRASE}" -C "${EMAIL}" -q -f  ~/.ssh/id_rsa  
  chmod 400 ~/.ssh/id_rsa*
  ```


## Create the aws-cli config and credentials files if a volume is not mounted on AWS_USER_DIR.  
  ###### -> enter aws access key id: ????
  ###### -> enter aws secret access key: ????
  ###### -> enter aws region name: eu-west-3
  ###### -> enter aws default output format: json
  ```
  aws configure
  ```
  

## Create a role for EKS Cluster management.
  ```
  CLUSTER_ROLE_ARN=$(aws iam create-role --role-name multi-k8s-eks-cluster-role --assume-role-policy-document file://aws/role-policies/assume-eks-policy.json | jq .Role.Arn | sed s/\"//g)
  echo ${CLUSTER_ROLE_ARN}
  ```
  #### Atttach the Cluster policy.
  ```
  aws iam attach-role-policy --role-name multi-k8s-eks-cluster-role --policy-arn  arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
  ```


## Create a Contener Strorage Interface Policy for Elastic Block Store.
  ```
  EBS_CSI_POLICY=$(aws iam create-policy --policy-name Amazon_EBS_CSI_Driver \--policy-document file://aws/role-policies/assume-volume-policy.json --output text)
  ```
  #### if it exists.
  ```
  EBS_CI_POLICY=$(aws iam list-policies --query 'Policies[?PolicyName==`Amazon_EBS_CSI_Driver`].Arn' --output text)
  ```


## Create a role for EKS nodes management.
  ```
  NODEGROUP_ROLE_ARN==$(aws iam create-role --role-name multi-k8s-eks-nodegroup-role --assume-role-policy-document file://aws/role-policies/assume-node-policy.json | jq .Role.Arn | sed s/\"//g)
  echo ${NODEGROUP_ROLE_ARN}
  ```
  #### Atttach the policies for Security, Networking and ImageRegistry (optional).
  ```
  aws iam attach-role-policy --role-name multi-k8s-eks-nodegroup-role --policy-arn  ${EBS_CSI_POLICY}
  aws iam attach-role-policy --role-name multi-k8s-eks-nodegroup-role --policy-arn  arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
  aws iam attach-role-policy --role-name multi-k8s-eks-nodegroup-role --policy-arn  arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
  aws iam attach-role-policy --role-name multi-k8s-eks-nodegroup-role --policy-arn  arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
  ```


## Download the vpc template, modify the region (eu-west-3) and create the cluster VPC.
  ```
  curl https://amazon-eks.s3.us-west-2.amazonaws.com/cloudformation/2020-05-08/amazon-eks-vpc-sample.yaml -o aws/vpc/vpc.yaml
  aws cloudformation deploy --template-file aws/vpc/vpc.yaml --stack-name multi-k8s-eks-vpc
  ```
  #### Grab your stack details.
  ```
  aws cloudformation list-stack-resources --stack-name multi-k8s-eks-vpc > aws/tmp/stack.json
  ```


## Create a cluster with role_arn previously created and subnet and secutity group ids from the stack.json file.
   ```
   role_arn=${CLUSTER_ROLE_ARN}
   
   aws eks create-cluster \
   --name multi-k8s-eks-cluster \
   --role-arn $role_arn \
   --resources-vpc-config subnetIds=subnet-02bf59abcde0111dc,subnet-028025ceb27ef81ac,securityGroupIds=sg-09a1769915b592229,endpointPublicAccess=true,endpointPrivateAccess=false
  ```
  #### Grab the cluster description.
  ```
  aws eks list-clusters
  aws eks describe-cluster --name multi-k8s-eks-cluster > aws/tmp/cluster.json
  kubectl get clusters
  ```


## Get a kubeconfig for the created cluster.
  ```
  rm -f /root/.kube/*
  
  aws eks update-kubeconfig --name multi-k8s-eks-cluster --region eu-west-3
  cp /root/.kube/config  ./tmp
  ```


## Create a Node Group with t2.medium VM (17 possible PODs but is not included in the AWS Free Tier) with 200Go and linked to subnet-01.
   Get the subnet-01 from aws/tmp/cluster.json file.
   NB: A single Node in the group initially, but can be increased to 2 Nodes max
  ```   
  role_arn=${NODEGROUP_ROLE_ARN}
  
  aws eks create-nodegroup \
  --cluster-name multi-k8s-eks-cluster \
  --nodegroup-name multi-k8s-eks-nodegroup \
  --node-role $role_arn \
  --subnets subnet-02bf59abcde0111dc \
  --disk-size 200 \
  --scaling-config minSize=1,maxSize=2,desiredSize=1 \
  --instance-types t2.medium
  ```
  #### Grab the node group description.
  ```
  aws eks list-nodegroups --cluster-name multi-k8s-eks-cluster
  aws eks describe-nodegroup --cluster-name multi-k8s-eks-cluster  --nodegroup-name multi-k8s-eks-nodegroup > aws/tmp/node-group.json
  kubectl get nodes
  ```


## Install a Contener Strorage Interface Driver.
  ```
  kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
  ```

  #### Create a name space and deploy the Workload.
  ```
  kubectl create ns multi-k8s
  kubectl create secret generic pgpassword --from-literal PGPASSWORD=azerty -n multi-k8s
  #kubectl apply -n multi-k8s -f k8s-prod/common
  #kubectl apply -n multi-k8s -f k8s-prod/app
  kubectl apply -f k8s-prod/common
  kubectl apply -f k8s-prod/app
  kubectl get pods -n multi-k8s
  kubectl get services
  kubectl get secrets
  kubectl get vpc
  kubectl get vp
  ```


## Cleanup all resources on AWS Cloud.
  ```diff
  - A cleanup is required to not pay more when the app is not required anymore.
  ```

  #### Delete the node group.
  ```
  aws eks delete-nodegroup --cluster-name multi-k8s-eks-cluster --nodegroup-name multi-k8s-eks-nodegroup
  ```
  #### Delete the cluster.
  ```
  aws eks delete-cluster --name multi-k8s-eks-cluster
  ```
  #### Delete the vpc.
  ```
  aws cloudformation delete-stack --stack-name multi-k8s-eks-vpc
  ```
  #### Detach the policies and delete the Node Group role.
  ```
  aws iam detach-role-policy --role-name multi-k8s-eks-nodegroup-role --policy-arn  ${EBS_CSI_POLICY}
  aws iam detach-role-policy --role-name multi-k8s-eks-nodegroup-role --policy-arn  arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
  aws iam detach-role-policy --role-name multi-k8s-eks-nodegroup-role --policy-arn  arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
  aws iam detach-role-policy --role-name multi-k8s-eks-nodegroup-role --policy-arn  arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
  aws iam delete-policy --policy-name Amazon_EBS_CSI_Driver
  aws iam delete-role --role-name multi-k8s-eks-nodegroup-role
  ```
  #### Detach the policies and delete the Node Group role.
  ```
  aws iam detach-role-policy --role-name multi-k8s-eks-cluster-role --policy-arn  arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
  aws iam delete-role --role-name multi-k8s-eks-cluster-role
  ```

 
 