#!/bin/sh

# Stop all containers with 'cleanup' label
docker stop $(docker ps -aq --filter "label=cleanup")
