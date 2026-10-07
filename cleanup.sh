#!/bin/sh

echo
echo "## Cleanup ##"

# Stop all containers with 'cleanup' label
echo "Stopping all 'cleanup' tagged containers."
docker stop $(docker ps -aq --filter "label=cleanup") > /dev/null 2>&1

# Remove all containers with 'cleanup' label
echo "Removing all 'cleanup' tagged containers." 
docker rm $(docker ps -aq --filter "label=cleanup") > /dev/null 2>&1

# Remove all images by name
# Commented out during dev

# echo "Removing postgres image."
# docker rmi postgres:latest
echo "Removing seeder image."
docker rmi seeder:latest > /dev/null 2>&1

# Remove custom bridge network
echo "Removing custom network"
docker network rm CA-network > /dev/null 2>&1
