#!/bin/sh

set -e

# Create bridge network
docker network create CA-network

# Pull images
# Commented out during dev
# docker pull postgres:latest

# Run Postgres container
docker run \
    --detach \
    --name database \
    --label cleanup \
    --network CA-network \
    --env POSTGRES_USER=user \
    --env POSTGRES_PASSWORD=secret \
    --env POSTGRES_DB=music-store \
    --health-cmd="pg_isready -U user -d music-store" \
    --health-interval=5s \
    --health-timeout=3s \
    --health-retries=12 \
    postgres:latest

# Build Seeder image
docker build --target seeder -t seeder .

# Wait for DB to initalise

echo "Waiting for postgres to be ready to accept connections."

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

# Run Seeder container
docker run \
    --rm \
    --network CA-network \
    --volume ./Chinook.db:/app/Chinook.db \
    --env SQLITE_FILE=/app/Chinook.db \
    --env DATABASE_URL=postgres://user:secret@database:5432/music-store \
    seeder:latest > /dev/null 2>&1

# docker exec -it database psql -U user -d music-store -c "SELECT COUNT(*) FROM artist;"

# docker build -t assignment-demo:1.0 ./sample-app/
# 
# docker run -d --name assignment \
#        -p 3000:80 \
#     assignment-demo:1.0
# 
# sleep 10
# echo "Container started"
