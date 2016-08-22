#!/usr/bin/env bash
cp /tmp/web-package.zip /home/ec2-user/app
unzip -o /tmp/web-package.zip -d /home/ec2-user/app
cd /home/ec2-user/app
forever stopall
forever start server.js
