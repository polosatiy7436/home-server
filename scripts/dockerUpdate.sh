#!/bin/bash

#cd to Docker folder
cd /home/pi/docker

#Pull new images
docker compose pull

#Run new images. Docker auto detects updated images
docker compose up -d

#Delete old images
docker system prune -a -f
