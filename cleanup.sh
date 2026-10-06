#!/bin/sh

# Stop all containers with 'cleanup' label
docker stop $(docker ps -aq --filter "label=cleanup")

# Remove all containers with 'cleanup' label
docker rm $(docker ps -aq --filter "label=cleanup")

# Remove all images by name
docker rmi postgres:latest

# Remove custom bridge network
docker network rm CA-network
