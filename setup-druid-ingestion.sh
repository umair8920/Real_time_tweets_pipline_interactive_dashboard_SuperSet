#!/bin/bash

# Wait for Druid to be ready
echo "Waiting for Druid to be ready..."
while ! curl -f http://localhost:8888/status; do
    echo "Druid not ready yet, waiting..."
    sleep 10
done

echo "Druid is ready!"

# Submit ingestion spec
echo "Submitting Druid ingestion specification..."
curl -X POST \
  http://localhost:8888/druid/indexer/v1/supervisor \
  -H 'Content-Type: application/json' \
  -d @config/druid/twitter-ingestion-spec.json

echo "Druid ingestion specification submitted!"

# Check supervisor status
echo "Checking supervisor status..."
curl -X GET http://localhost:8888/druid/indexer/v1/supervisor

echo "Setup complete!"
