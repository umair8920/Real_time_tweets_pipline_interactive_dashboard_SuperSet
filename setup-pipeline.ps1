Write-Host "=== Twitter Personality Analysis Pipeline Setup ===" -ForegroundColor Green
Write-Host "This script will set up the complete real-time data pipeline" -ForegroundColor Yellow
Write-Host ""

# Start all services
Write-Host "1. Starting all Docker services..." -ForegroundColor Cyan
docker-compose up -d

Write-Host "Waiting for services to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Setup Kafka Connect
Write-Host "2. Setting up Kafka Connect..." -ForegroundColor Cyan

# Wait for Kafka Connect to be ready
Write-Host "Waiting for Kafka Connect to be ready..."
do {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method Get -ErrorAction Stop
        Write-Host "Kafka Connect is ready!" -ForegroundColor Green
        break
    }
    catch {
        Write-Host "Kafka Connect not ready yet, waiting..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
} while ($true)

# Create Kafka topic
Write-Host "Creating Kafka topic..."
docker exec kafka kafka-topics --create --topic twitter-tweets --bootstrap-server localhost:9092 --partitions 3 --replication-factor 1 --if-not-exists

# Deploy MQTT Source Connector
Write-Host "Deploying MQTT Source Connector..."
$connectorConfig = Get-Content "config/kafka-connect/mqtt-source-connector.json" -Raw
try {
    Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method Post -Body $connectorConfig -ContentType "application/json"
    Write-Host "MQTT Source Connector deployed!" -ForegroundColor Green
}
catch {
    Write-Host "Error deploying connector: $($_.Exception.Message)" -ForegroundColor Red
}

# Check connector status
Write-Host "Checking connector status..."
try {
    $status = Invoke-RestMethod -Uri "http://localhost:8083/connectors/mqtt-source-connector/status" -Method Get
    Write-Host "Connector Status: $($status.connector.state)" -ForegroundColor Green
}
catch {
    Write-Host "Could not get connector status" -ForegroundColor Yellow
}

Write-Host "Waiting for Kafka Connect to process messages..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# Setup Druid ingestion
Write-Host "3. Setting up Druid ingestion..." -ForegroundColor Cyan

# Wait for Druid to be ready
Write-Host "Waiting for Druid to be ready..."
do {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8888/status" -Method Get -ErrorAction Stop
        Write-Host "Druid is ready!" -ForegroundColor Green
        break
    }
    catch {
        Write-Host "Druid not ready yet, waiting..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
} while ($true)

# Submit ingestion spec
Write-Host "Submitting Druid ingestion specification..."
$ingestionSpec = Get-Content "config/druid/twitter-ingestion-spec.json" -Raw
try {
    Invoke-RestMethod -Uri "http://localhost:8888/druid/indexer/v1/supervisor" -Method Post -Body $ingestionSpec -ContentType "application/json"
    Write-Host "Druid ingestion specification submitted!" -ForegroundColor Green
}
catch {
    Write-Host "Error submitting ingestion spec: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "Waiting for Druid to start ingesting data..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Setup Superset
Write-Host "4. Setting up Superset..." -ForegroundColor Cyan

# Wait for Superset to be ready
Write-Host "Waiting for Superset to be ready..."
do {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8088/health" -Method Get -ErrorAction Stop
        Write-Host "Superset is ready!" -ForegroundColor Green
        break
    }
    catch {
        Write-Host "Superset not ready yet, waiting..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
} while ($true)

Write-Host ""
Write-Host "=== Pipeline Setup Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Services are running on the following ports:" -ForegroundColor Cyan
Write-Host "- MQTT Broker (Mosquitto): http://localhost:1883"
Write-Host "- Kafka: http://localhost:9092"
Write-Host "- Kafka Connect: http://localhost:8083"
Write-Host "- Druid Router: http://localhost:8888"
Write-Host "- Druid Broker: http://localhost:8082"
Write-Host "- Superset: http://localhost:8088 (admin/admin)" -ForegroundColor Yellow
Write-Host ""
Write-Host "To monitor the pipeline:" -ForegroundColor Cyan
Write-Host "1. Check MQTT messages: docker logs python-publisher"
Write-Host "2. Check Kafka Connect: Invoke-RestMethod -Uri http://localhost:8083/connectors/mqtt-source-connector/status"
Write-Host "3. Check Druid ingestion: Invoke-RestMethod -Uri http://localhost:8888/druid/indexer/v1/supervisor"
Write-Host "4. Access Superset dashboard: http://localhost:8088"
Write-Host ""
Write-Host "To stop all services: docker-compose down" -ForegroundColor Red

# Open Superset in browser
Write-Host ""
Write-Host "Opening Superset in your default browser..." -ForegroundColor Green
Start-Process "http://localhost:8088"
