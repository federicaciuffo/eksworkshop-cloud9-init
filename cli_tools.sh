cd ~

#Install kubectl
sudo curl --silent --location -o /usr/local/bin/kubectl \
   https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl

#Update awscli
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

#Install jq, envsubst (from GNU gettext utilities) and bash-completion
sudo yum -y install jq gettext bash-completion moreutils

#Install yq for yaml processing
#echo 'yq() {
#  docker run --rm -i -v "${PWD}":/workdir mikefarah/yq "$@"
#}' | tee -a ~/.bashrc && source ~/.bashrc

#Verify the binaries are in the path and executable
for command in kubectl jq envsubst aws
  do
    which $command &>/dev/null && echo "$command in path" || echo "$command NOT FOUND"
  done

#Enable kubectl bash_completion
kubectl completion bash >>  ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion

#set the AWS Load Balancer Controller version
echo 'export LBC_VERSION="v2.3.0"' >>  ~/.bash_profile
.  ~/.bash_profile

#To ensure temporary credentials aren’t already in place we will remove any existing credentials file as well as disabling AWS managed temporary credentials:
aws cloud9 update-environment  --environment-id $C9_PID --managed-credentials-action DISABLE
rm -vf ${HOME}/.aws/credentials

#We should configure our aws cli with our current region as default.
export ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
export AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
export AZS=($(aws ec2 describe-availability-zones --query 'AvailabilityZones[].ZoneName' --output text --region $AWS_REGION))

#Check if AWS_REGION is set to desired region
test -n "$AWS_REGION" && echo AWS_REGION is "$AWS_REGION" || echo AWS_REGION is not set

# save these into bash_profile
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile
echo "export AZS=(${AZS[@]})" | tee -a ~/.bash_profile
aws configure set default.region ${AWS_REGION}
aws configure get default.region

#Validate the IAM role
#aws sts get-caller-identity --query Arn | grep eksworkshop-admin -q && echo "IAM role valid" || echo "IAM role NOT valid"

#CLONE THE SERVICE REPOS
cd ~/environment
git clone https://github.com/aws-containers/ecsdemo-frontend.git
git clone https://github.com/aws-containers/ecsdemo-nodejs.git
git clone https://github.com/aws-containers/ecsdemo-crystal.git


#download the eksctl binary
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv -v /tmp/eksctl /usr/local/bin

#Confirm the eksctl command works:
eksctl version

#Enable eksctl bash-completion
eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion

#Export the Worker Role Name for use throughout the workshop
STACK_NAME=$(eksctl get nodegroup --cluster eksworkshop-eksctl -o json | jq -r '.[].StackName')
ROLE_NAME=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.ResourceType=="AWS::IAM::Role") | .PhysicalResourceId')
echo "export ROLE_NAME=${ROLE_NAME}" | tee -a ~/.bash_profile

#Install the Helm CLI
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm version --short
helm repo add stable https://charts.helm.sh/stable
helm completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
source <(helm completion bash)



#Import your EKS Console credentials to your  clusters aws-auth config map - to see pods from console
#c9builder=$(aws cloud9 describe-environment-memberships --environment-id=$C9_PID | jq -r '.memberships[].userArn')
#if echo ${c9builder} | grep -q user; then
#  rolearn=${c9builder}
#        echo Role ARN: ${rolearn}
#elif echo ${c9builder} | grep -q assumed-role; then
#        assumedrolename=$(echo ${c9builder} | awk -F/ '{print $(NF-1)}')
#        rolearn=$(aws iam get-role --role-name ${assumedrolename} --query Role.Arn --output text) 
#        echo Role ARN: ${rolearn}
#fi
#eksctl create iamidentitymapping --cluster eksworkshop-eksctl --arn ${rolearn} --group system:masters --username admin
#kubectl describe configmap -n kube-system aws-auth


############
# create eksworkshop-admin role and give to instance
#https://www.eksworkshop.com/020_prerequisites/iamrole/
#eksctl create iamidentitymapping --cluster eksworkshop-eksctl --arn {eksworkshop-admin role arn} --group system:masters --username admin 
#kubectl describe configmap -n kube-system aws-auth
#https://www.eksworkshop.com/020_prerequisites/ec2instance/
#aws sts get-caller-identity --query Arn | grep eksworkshop-admin -q && echo "IAM role valid" || echo "IAM role NOT valid"

aws eks --region $AWS_REGION update-kubeconfig --name eksworkshop-eksctl
#test with this command, you should get the node list
#kubectl get nodes

