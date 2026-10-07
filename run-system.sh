#!/bin/sh

set -e

NETWORK_NAME="CA-network"
DB_USERNAME="user"
DB_PASSWORD="password"
DB_NAME="music-store"

echo
echo "## run-system ##"

# Create bridge network
echo "Creating custom network: '${NETWORK_NAME}'."
docker network create $NETWORK_NAME > /dev/null 2>&1

# Pull images

echo "Pulling postgres image from Docker Hub."
docker pull postgres:latest > /dev/null 2>&1

echo "Pulling MCP gateway image from Docker Hub."
docker pull docker/mcp-gateway:latest > /dev/null 2>&1

# Run postgres container
echo "Starting postgres container."
docker run \
    --detach \
    --name database \
    --label cleanup \
    --network $NETWORK_NAME \
    --env POSTGRES_USER=$DB_USERNAME \
    --env POSTGRES_PASSWORD=$DB_PASSWORD \
    --env POSTGRES_DB=$DB_NAME \
    --health-cmd="pg_isready -U ${DB_USERNAME} -d ${DB_NAME}" \
    --health-interval=5s \
    --health-timeout=3s \
    --health-retries=5 \
    postgres:latest > /dev/null 2>&1

# Build seeder image
echo "Building seeder image."
docker build --target seeder -t seeder . > /dev/null 2>&1

# Wait for postgres to initialise
echo "Waiting for postgres to accept connections."

DB_HEALTHCHECK_RETRIES=0
DB_STATUS=$(docker inspect --format='{{.State.Health.Status}}' database)

while [ $DB_STATUS != "healthy" ] && [ $DB_HEALTHCHECK_RETRIES -lt 5 ]; do
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
echo "Running seeder container."
docker run \
    --rm \
    --network $NETWORK_NAME \
    --volume ./Chinook.db:/app/Chinook.db \
    --env SQLITE_FILE=/app/Chinook.db \
    --env DATABASE_URL=postgres://${DB_USERNAME}:${DB_PASSWORD}@database:5432/${DB_NAME} \
    seeder:latest > /dev/null 2>&1

# Verify DB has been seeded
DB_HAS_DATA=$(docker exec -i database psql -U ${DB_USERNAME} -d ${DB_NAME} -tA -c 'SELECT EXISTS (SELECT 1 FROM artist);')

if [ $DB_HAS_DATA != 't' ]; then
    echo "Failed to seed database."
    exit 1
fi

echo "Database has been successfully seeded."

# Run mcp gateway container
echo "Running MCP gateway container."
docker run \
    --detach \
    --name mcp-gateway \
    --label cleanup \
    --network $NETWORK_NAME \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume ./mcp_config.yaml:/mcp_config.yaml \
    --volume ./mcp_secret.env:/run/secrets/database-url \
    docker/mcp-gateway:latest \
    --transport=sse \
    --secrets=/run/secrets/database-url \
    --allow-unauthenticated \
    --servers=cockroachdb \
    --tools=execute_query \
    --config=/mcp_config.yaml \
    > /dev/null 2>&1

# Build agent image
echo "Building agent image."
docker build --target agent -t agent . > /dev/null 2>&1

# Run agent container
echo "Running agent container."
echo
echo "### Agent Output ###"
echo 

docker run \
    --name agent \
    --label cleanup \
    --network $NETWORK_NAME \
    --volume ./secret.ollama-api-key:/run/secrets/openai-api-key \
    --env MCP_SERVER_URL=http://mcp-gateway:8811/sse \
    --env DATABASE_DIALECT=PostgreSQL \
    --env QUESTION="What are the top 3 albums by sales?" \
    --env OPENAI_API_BASE_URL="https://ollama.com/v1" \
    --env OPENAI_MODEL_NAME="gpt-oss:20b" \
    agent:latest
