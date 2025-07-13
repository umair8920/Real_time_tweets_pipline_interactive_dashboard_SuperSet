Write-Host "=== Twitter Pipeline Testing Script ===" -ForegroundColor Green
Write-Host ""

# Function to test service health
function Test-ServiceHealth {
    param(
        [string]$ServiceName,
        [string]$Url,
        [int]$MaxRetries = 5
    )
    
    Write-Host "Testing $ServiceName..." -ForegroundColor Cyan
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        try {
            $response = Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec 10 -ErrorAction Stop
            Write-Host "✓ $ServiceName is healthy" -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "⚠ $ServiceName not ready (attempt $i/$MaxRetries)" -ForegroundColor Yellow
            if ($i -lt $MaxRetries) {
                Start-Sleep -Seconds 5
            }
        }
    }
    
    Write-Host "✗ $ServiceName is not responding" -ForegroundColor Red
    return $false
}

# Function to test Docker containers
function Test-DockerContainers {
    Write-Host "Checking Docker containers..." -ForegroundColor Cyan
    
    $containers = @(
        "python-publisher",
        "mosquitto", 
        "kafka",
        "kafka-connect",
        "druid-coordinator",
        "druid-broker",
        "druid-historical",
        "druid-middlemanager",
        "druid-router",
        "superset",
        "postgres",
        "redis"
    )
    
    $allHealthy = $true
    
    foreach ($container in $containers) {
        try {
            $status = docker ps --filter "name=$container" --format "{{.Status}}"
            if ($status -like "*Up*") {
                Write-Host "✓ $container is running" -ForegroundColor Green
            } else {
                Write-Host "✗ $container is not running" -ForegroundColor Red
                $allHealthy = $false
            }
        }
        catch {
            Write-Host "✗ Error checking $container" -ForegroundColor Red
            $allHealthy = $false
        }
    }
    
    return $allHealthy
}

# Function to test MQTT messages
function Test-MQTTMessages {
    Write-Host "Testing MQTT message flow..." -ForegroundColor Cyan
    
    try {
        # Check if python-publisher is generating logs
        $logs = docker logs python-publisher --tail 10 2>&1
        if ($logs -match "Published tweet") {
            Write-Host "✓ Python publisher is sending MQTT messages" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ No MQTT messages detected in publisher logs" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ Error checking MQTT messages: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test Kafka messages
function Test-KafkaMessages {
    Write-Host "Testing Kafka message flow..." -ForegroundColor Cyan
    
    try {
        # Check if kafka topic exists and has messages
        $topicInfo = docker exec kafka kafka-topics --list --bootstrap-server localhost:9092 2>&1
        if ($topicInfo -match "twitter-tweets") {
            Write-Host "✓ Kafka topic 'twitter-tweets' exists" -ForegroundColor Green
            
            # Try to consume a few messages to verify data flow
            $messages = docker exec kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic twitter-tweets --max-messages 1 --timeout-ms 5000 2>&1
            if ($messages -and $messages -notmatch "ERROR") {
                Write-Host "✓ Kafka is receiving messages" -ForegroundColor Green
                return $true
            } else {
                Write-Host "⚠ Kafka topic exists but no messages detected" -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "✗ Kafka topic 'twitter-tweets' not found" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ Error testing Kafka: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test Kafka Connect
function Test-KafkaConnect {
    Write-Host "Testing Kafka Connect..." -ForegroundColor Cyan
    
    try {
        $connectors = Invoke-RestMethod -Uri "http://localhost:8083/connectors" -Method Get
        if ($connectors -contains "mqtt-source-connector") {
            Write-Host "✓ MQTT Source Connector is deployed" -ForegroundColor Green
            
            $status = Invoke-RestMethod -Uri "http://localhost:8083/connectors/mqtt-source-connector/status" -Method Get
            if ($status.connector.state -eq "RUNNING") {
                Write-Host "✓ MQTT Source Connector is running" -ForegroundColor Green
                return $true
            } else {
                Write-Host "✗ MQTT Source Connector state: $($status.connector.state)" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "✗ MQTT Source Connector not found" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ Error testing Kafka Connect: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to test Druid ingestion
function Test-DruidIngestion {
    Write-Host "Testing Druid ingestion..." -ForegroundColor Cyan
    
    try {
        $supervisors = Invoke-RestMethod -Uri "http://localhost:8888/druid/indexer/v1/supervisor" -Method Get
        if ($supervisors.Count -gt 0) {
            Write-Host "✓ Druid supervisor is running" -ForegroundColor Green
            
            # Check if data is being ingested
            $query = @{
                "queryType" = "timeseries"
                "dataSource" = "twitter-tweets"
                "granularity" = "minute"
                "aggregations" = @(
                    @{
                        "type" = "count"
                        "name" = "count"
                    }
                )
                "intervals" = @("2020-01-01/2030-01-01")
            }
            
            $result = Invoke-RestMethod -Uri "http://localhost:8082/druid/v2/" -Method Post -Body ($query | ConvertTo-Json -Depth 10) -ContentType "application/json"
            if ($result.Count -gt 0 -and $result[0].result.count -gt 0) {
                Write-Host "✓ Druid is ingesting data ($(($result[0].result.count)) records)" -ForegroundColor Green
                return $true
            } else {
                Write-Host "⚠ Druid supervisor running but no data ingested yet" -ForegroundColor Yellow
                return $false
            }
        } else {
            Write-Host "✗ No Druid supervisors found" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "✗ Error testing Druid: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main testing sequence
Write-Host "Starting pipeline validation..." -ForegroundColor Yellow
Write-Host ""

# Test 1: Docker containers
$dockerHealthy = Test-DockerContainers
Write-Host ""

# Test 2: Service health checks
$services = @(
    @{Name="Kafka"; Url="http://localhost:8083/connectors"},
    @{Name="Druid Router"; Url="http://localhost:8888/status"},
    @{Name="Druid Broker"; Url="http://localhost:8082/status"},
    @{Name="Superset"; Url="http://localhost:8088/health"}
)

$servicesHealthy = $true
foreach ($service in $services) {
    $healthy = Test-ServiceHealth -ServiceName $service.Name -Url $service.Url
    $servicesHealthy = $servicesHealthy -and $healthy
}
Write-Host ""

# Test 3: Data flow tests
$mqttWorking = Test-MQTTMessages
Write-Host ""

$kafkaWorking = Test-KafkaMessages  
Write-Host ""

$kafkaConnectWorking = Test-KafkaConnect
Write-Host ""

$druidWorking = Test-DruidIngestion
Write-Host ""

# Summary
Write-Host "=== Pipeline Validation Summary ===" -ForegroundColor Green
Write-Host ""

if ($dockerHealthy) {
    Write-Host "✓ All Docker containers are running" -ForegroundColor Green
} else {
    Write-Host "✗ Some Docker containers are not running" -ForegroundColor Red
}

if ($servicesHealthy) {
    Write-Host "✓ All services are responding" -ForegroundColor Green
} else {
    Write-Host "✗ Some services are not responding" -ForegroundColor Red
}

if ($mqttWorking) {
    Write-Host "✓ MQTT message flow is working" -ForegroundColor Green
} else {
    Write-Host "✗ MQTT message flow has issues" -ForegroundColor Red
}

if ($kafkaWorking) {
    Write-Host "✓ Kafka message flow is working" -ForegroundColor Green
} else {
    Write-Host "✗ Kafka message flow has issues" -ForegroundColor Red
}

if ($kafkaConnectWorking) {
    Write-Host "✓ Kafka Connect is working" -ForegroundColor Green
} else {
    Write-Host "✗ Kafka Connect has issues" -ForegroundColor Red
}

if ($druidWorking) {
    Write-Host "✓ Druid ingestion is working" -ForegroundColor Green
} else {
    Write-Host "✗ Druid ingestion has issues" -ForegroundColor Red
}

Write-Host ""
$overallHealth = $dockerHealthy -and $servicesHealthy -and $mqttWorking -and $kafkaWorking -and $kafkaConnectWorking -and $druidWorking

if ($overallHealth) {
    Write-Host "🎉 Pipeline is fully operational!" -ForegroundColor Green
    Write-Host "You can now access Superset at http://localhost:8088 (admin/admin)" -ForegroundColor Cyan
} else {
    Write-Host "⚠ Pipeline has some issues that need to be addressed" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Cyan
    Write-Host "1. Check Docker logs: docker logs <container-name>"
    Write-Host "2. Restart services: docker-compose restart <service-name>"
    Write-Host "3. Check service ports are not in use by other applications"
    Write-Host "4. Ensure sufficient system resources (8GB+ RAM recommended)"
}
