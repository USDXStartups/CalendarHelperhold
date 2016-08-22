#!/usr/bin/env bash
env=$1
echo "Deploying to ${env}"
awsHosts=`aws ec2 describe-instances --query "Reservations[].Instances[].PublicDnsName" --filters "Name=tag-key,Values=Name,Name=tag-value,Values=${env}" --output text`
IN=`echo ${awsHosts} | tr ' ' ' '`
hosts=(${IN// / })

npm install
npm run build
rm -rf web-package.zip
zip -rq web-package.zip .
git add .
git commit -am "new build"
git push

for host in "${hosts[@]}"
do
  echo "Deploying to ${host}"
  echo "Copying package"
  scp -i ~/ec2-keypair.pem web-package.zip ec2-user@$host:/tmp

  echo "Running deployment script"
  ssh -i ~/ec2-keypair.pem ec2-user@$host "bash -s" < deploy_i.sh
done
