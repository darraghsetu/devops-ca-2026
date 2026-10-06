#!/bin/sh

set -e

NETWORK_NAME="CA-network"
DB_USERNAME="user"
DB_PASSWORD="password"
DB_NAME="music-store"

# Create bridge network
echo "Creating network: ${NETWORK_NAME}"
docker network create $NETWORK_NAME > /dev/null 2>&1

# Pull images
# Commented out during dev

# echo "Pulling postgres image from Dockerhub"
# docker pull postgres:latest > /dev/null 2>&1

# Run postgres container
echo "Starting postgres container"
docker run \
    --detach \
    --name database \
    --label cleanup \
    --network $NETWORK_NAME \
    --env POSTGRES_USER=$DB_USERNAME \
    --env POSTGRES_PASSWORD=$DB_PASSWORD \
    --env POSTGRES_DB=$DB_NAME \
    --health-cmd="pg_isready -U user -d music-store" \
    --health-interval=5s \
    --health-timeout=3s \
    --health-retries=5 \
    postgres:latest > /dev/null 2>&1

# Build seeder image
echo "Building Seeder image"
docker build --target seeder -t seeder . > /dev/null 2>&1

# Wait for postgres to initialise
echo "Waiting for postgres to accept connections."

DB_HEALTHCHECK_RETRIES=0
DB_STATUS=$(docker inspect --format='{{.State.Health.Status}}' database)

while [ $DB_STATUS != "healthy" ] && [ $DB_HEALTHCHECK_RETRIES -lt 12 ]; do
    DB_STATUS=$(docker inspect --format='{{.State.Health.Status}}' database)
    DB_HEALTHCHECK_RETRIES=$((DB_HEALTHCHECK_RETRIES + 1))
    sleep 5
done

if [ $DB_STATUS != "healthy" ]; then
    echo "Database failed to initialise."
    exit 1
fi

echo "Postgres is ready to accept connections."

# Run seeder container
docker run \
    --rm \
    --network CA-network \
    --volume ./Chinook.db:/app/Chinook.db \
    --env SQLITE_FILE=/app/Chinook.db \
    --env DATABASE_URL=postgres://${DB_USERNAME}:${DB_PASSWORD}@database:5432/${DB_NAME} \
    seeder:latest > /dev/null 2>&1

echo "Database has been seeded."

# docker exec -it database psql -U user -d music-store -c "SELECT COUNT(*) FROM artist;"

# docker build -t assignment-demo:1.0 ./sample-app/
# 
# docker run -d --name assignment \
#        -p 3000:80 \
#     assignment-demo:1.0
# 
# sleep 10
# echo "Container started"
