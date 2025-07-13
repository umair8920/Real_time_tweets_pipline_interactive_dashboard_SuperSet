#!/bin/bash

# Wait for Kafka Connect to be ready
echo "Waiting for Kafka Connect to be ready..."
while ! curl -f http://localhost:8083/connectors; do
    echo "Kafka Connect not ready yet, waiting..."
    sleep 10
done

echo "Kafka Connect is ready!"

# Create Kafka topic
echo "Creating Kafka topic..."
docker exec kafka kafka-topics --create --topic twitter-tweets --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists

# Deploy MQTT Source Connector
echo "Deploying MQTT Source Connector..."
curl -X POST \
  http://localhost:8083/connectors \
  -H 'Content-Type: application/json' \
  -d @config/kafka-connect/mqtt-source-connector.json

echo "MQTT Source Connector deployed!"

# Check connector status
echo "Checking connector status..."
curl -X GET http://localhost:8083/connectors/mqtt-source-connector/status
