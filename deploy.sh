#!/usr/bin/env bash

ENV=$1
EB_ENV="stationfyWeb-env-stg"
echo "Deploying to $ENV environment"

echo "Building..."

if [ "$ENV" = "prd" ]
then
  EB_ENV="stationfyWeb-env-prd"
	npm run build
else
  npm run build
fi

echo "Copying to webserver repo..."
rm -rf ../express-app-react/dist
cp -r ./public ../express-app-react/dist

cd ../express-app-react
echo "Directory is now `pwd`"

git add --all

git commit -am "deploy $EB_ENV `date`"

echo "Deploying to AWS EB environment $EB_ENV"

eb deploy "$EB_ENV"

git reset --hard origin/master
