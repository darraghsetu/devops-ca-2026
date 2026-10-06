#!/bin/sh

set -e

# Create bridge network
docker network create CA-network

# Pull images
docker pull postgres:latest

# Run Postgres container
docker run --detach \
    --name database \
    --label cleanup \
    --network CA-network \
    --env POSTGRES_USER=user \
    --env POSTGRES_PASSWORD=secret \
    --env POSTGRES_DB=music-store \
    postgres

# Build Seeder image 
docker build --target seeder -t seeder .

# docker build -t assignment-demo:1.0 ./sample-app/
# 
# docker run -d --name assignment \
#        -p 3000:80 \
#     assignment-demo:1.0
# 
# sleep 10
# echo "Container started"
