#!/bin/bash

echo "=== Twitter Personality Analysis Pipeline Setup ==="
echo "This script will set up the complete real-time data pipeline"
echo ""

# Start all services
echo "1. Starting all Docker services..."
docker-compose up -d

echo "Waiting for services to initialize..."
sleep 30

# Setup Kafka Connect
echo "2. Setting up Kafka Connect..."
chmod +x setup-kafka-connect.sh
./setup-kafka-connect.sh

echo "Waiting for Kafka Connect to process messages..."
sleep 20

# Setup Druid ingestion
echo "3. Setting up Druid ingestion..."
chmod +x setup-druid-ingestion.sh
./setup-druid-ingestion.sh

echo "Waiting for Druid to start ingesting data..."
sleep 30

# Setup Superset
echo "4. Setting up Superset..."
chmod +x setup-superset.sh
./setup-superset.sh

echo ""
echo "=== Pipeline Setup Complete! ==="
echo ""
echo "Services are running on the following ports:"
echo "- MQTT Broker (Mosquitto): http://localhost:1883"
echo "- Kafka: http://localhost:9092"
echo "- Kafka Connect: http://localhost:8083"
echo "- Druid Router: http://localhost:8888"
echo "- Druid Broker: http://localhost:8082"
echo "- Superset: http://localhost:8088 (admin/admin)"
echo ""
echo "To monitor the pipeline:"
echo "1. Check MQTT messages: docker logs python-publisher"
echo "2. Check Kafka Connect: curl http://localhost:8083/connectors/mqtt-source-connector/status"
echo "3. Check Druid ingestion: curl http://localhost:8888/druid/indexer/v1/supervisor"
echo "4. Access Superset dashboard: http://localhost:8088"
echo ""
echo "To stop all services: docker-compose down"
