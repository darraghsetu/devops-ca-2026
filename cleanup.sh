#!/bin/sh

echo "\n## Cleanup ##"

# Stop all containers with 'cleanup' label
echo "\n1. Stopping all 'cleanup' tagged containers."
docker stop $(docker ps -aq --filter "label=cleanup") > /dev/null 2>&1

# Remove all containers with 'cleanup' label
echo "\n2. Removing all 'cleanup' tagged containers." 
docker rm $(docker ps -aq --filter "label=cleanup") > /dev/null 2>&1

# Remove all images by name
echo "\n3. Removing images:"

echo "  - postgres"
docker rmi postgres:latest > /dev/null 2>&1

echo "  - mcp-gateway"
docker rmi docker/mcp-gateway:latest > /dev/null 2>&1

echo "  - cockroachdb"
docker rmi $(docker images --filter "reference=mcp/cockroachdb*" -q) > /dev/null 2>&1

echo "  - seeder"
docker rmi seeder:latest > /dev/null 2>&1

echo "  - agent"
docker rmi agent:latest > /dev/null 2>&1

# Prune unattached volumes
echo "\n4. Removing unattached volumes"
docker volume prune --all --force > /dev/null 2>&1

# Prune build cache
echo "\n5. Removing build cache"
docker builder prune --all --force > /dev/null 2>&1

# Remove custom bridge network
echo "\n6. Removing custom network: CA-network"
docker network rm CA-network > /dev/null 2>&1

echo "\n## Verification ##\n"
docker system df
