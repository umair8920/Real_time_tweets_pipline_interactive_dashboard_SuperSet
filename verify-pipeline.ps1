Write-Host "=== Twitter Personality Analysis Pipeline Verification ===" -ForegroundColor Green
Write-Host ""

# Function to check service health
function Test-ServiceHealth {
    param([string]$ServiceName, [string]$Url)
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 5 -ErrorAction Stop
        Write-Host "✅ $ServiceName is healthy (Status: $($response.StatusCode))" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "❌ $ServiceName is not responding" -ForegroundColor Red
        return $false
    }
}

Write-Host "🔍 1. Checking Service Health..." -ForegroundColor Cyan
Write-Host ""

$services = @(
    @{Name="Superset Dashboard"; Url="http://localhost:8088"},
    @{Name="Kafka"; Url="http://localhost:9092"}  # This will fail but shows we're trying
)

$supersetHealthy = Test-ServiceHealth -ServiceName "Superset Dashboard" -Url "http://localhost:8088"

Write-Host ""
Write-Host "🐳 2. Checking Docker Containers..." -ForegroundColor Cyan
$containers = docker ps --format "table {{.Names}}\t{{.Status}}"
Write-Host $containers

Write-Host ""
Write-Host "📊 3. Checking Data Pipeline..." -ForegroundColor Cyan

# Check current tweet count
Write-Host "Getting current tweet count..." -ForegroundColor Yellow
$tweetCount1 = docker exec mysql mysql -u twitter_user -ptwitter_password twitter_analytics -e "SELECT COUNT(*) FROM tweets;" 2>$null | Select-String -Pattern "^\d+$"
if ($tweetCount1) {
    $count1 = [int]$tweetCount1.Line
    Write-Host "✅ Current tweets in database: $count1" -ForegroundColor Green
} else {
    Write-Host "❌ Could not get tweet count" -ForegroundColor Red
    exit 1
}

# Wait and check again to verify real-time processing
Write-Host "Waiting 10 seconds to verify real-time processing..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

$tweetCount2 = docker exec mysql mysql -u twitter_user -ptwitter_password twitter_analytics -e "SELECT COUNT(*) FROM tweets;" 2>$null | Select-String -Pattern "^\d+$"
if ($tweetCount2) {
    $count2 = [int]$tweetCount2.Line
    $newTweets = $count2 - $count1
    if ($newTweets -gt 0) {
        Write-Host "✅ Real-time processing verified: $newTweets new tweets added" -ForegroundColor Green
    } else {
        Write-Host "⚠️ No new tweets detected - pipeline may be slow" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ Could not verify real-time processing" -ForegroundColor Red
}

Write-Host ""
Write-Host "📈 4. Data Analysis Summary..." -ForegroundColor Cyan

# Get MBTI distribution
Write-Host "MBTI Personality Distribution:" -ForegroundColor Yellow
$mbtiData = docker exec mysql mysql -u twitter_user -ptwitter_password twitter_analytics -e "SELECT mbti_personality, COUNT(*) as count FROM tweets GROUP BY mbti_personality ORDER BY count DESC LIMIT 5;" 2>$null
$mbtiLines = $mbtiData -split "`n" | Where-Object { $_ -match "^\w+\s+\d+$" }
foreach ($line in $mbtiLines) {
    if ($line -match "^(\w+)\s+(\d+)$") {
        Write-Host "  $($matches[1]): $($matches[2]) tweets" -ForegroundColor White
    }
}

# Get time range
Write-Host ""
Write-Host "Data Time Range:" -ForegroundColor Yellow
$timeRange = docker exec mysql mysql -u twitter_user -ptwitter_password twitter_analytics -e "SELECT MIN(timestamp) as first_tweet, MAX(timestamp) as last_tweet FROM tweets;" 2>$null
$timeLines = $timeRange -split "`n" | Where-Object { $_ -match "\d{4}-\d{2}-\d{2}" }
foreach ($line in $timeLines) {
    Write-Host "  $line" -ForegroundColor White
}

Write-Host ""
Write-Host "🎯 5. Pipeline Component Status..." -ForegroundColor Cyan

# Check each component
$components = @(
    @{Name="Python Publisher"; Container="python-publisher"},
    @{Name="MQTT Broker"; Container="mosquitto"},
    @{Name="MQTT-Kafka Bridge"; Container="mqtt-kafka-bridge"},
    @{Name="Kafka"; Container="kafka"},
    @{Name="MySQL Consumer"; Container="kafka-mysql-consumer"},
    @{Name="MySQL Database"; Container="mysql"},
    @{Name="Superset"; Container="superset"}
)

foreach ($component in $components) {
    $status = docker ps --filter "name=$($component.Container)" --format "{{.Status}}"
    if ($status -like "*Up*") {
        Write-Host "✅ $($component.Name): Running" -ForegroundColor Green
    } else {
        Write-Host "❌ $($component.Name): Not running" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "🚀 6. Access Information..." -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Superset Dashboard:" -ForegroundColor Green
Write-Host "   URL: http://localhost:8088" -ForegroundColor White
Write-Host "   Username: admin" -ForegroundColor White
Write-Host "   Password: admin" -ForegroundColor White
Write-Host ""
Write-Host "🔗 Database Connection String for Superset:" -ForegroundColor Green
Write-Host "   mysql://twitter_user:twitter_password@mysql:3306/twitter_analytics" -ForegroundColor White
Write-Host ""

Write-Host "📋 7. Next Steps to Create Visualizations..." -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Open Superset: http://localhost:8088" -ForegroundColor White
Write-Host "2. Login with admin/admin" -ForegroundColor White
Write-Host "3. Add database connection using the string above" -ForegroundColor White
Write-Host "4. Go to SQL Lab and try these queries:" -ForegroundColor White
Write-Host ""
Write-Host "   Query 1 - Tweet Count:" -ForegroundColor Yellow
Write-Host "   SELECT COUNT(*) as total_tweets FROM tweets;" -ForegroundColor Gray
Write-Host ""
Write-Host "   Query 2 - MBTI Distribution:" -ForegroundColor Yellow
Write-Host "   SELECT mbti_personality, COUNT(*) as count" -ForegroundColor Gray
Write-Host "   FROM tweets GROUP BY mbti_personality ORDER BY count DESC;" -ForegroundColor Gray
Write-Host ""
Write-Host "   Query 3 - Tweet Volume Over Time:" -ForegroundColor Yellow
Write-Host "   SELECT DATE_FORMAT(timestamp, '%Y-%m-%d %H:%i:00') as time_bucket," -ForegroundColor Gray
Write-Host "   COUNT(*) as tweet_count FROM tweets" -ForegroundColor Gray
Write-Host "   GROUP BY time_bucket ORDER BY time_bucket;" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Create charts from these queries using the Explore feature" -ForegroundColor White
Write-Host "6. Build a dashboard combining your visualizations" -ForegroundColor White

Write-Host ""
Write-Host "🎉 PIPELINE VERIFICATION COMPLETE!" -ForegroundColor Green
Write-Host ""
if ($supersetHealthy -and $count2 -gt $count1) {
    Write-Host "✅ Your Twitter Personality Analysis Pipeline is FULLY OPERATIONAL!" -ForegroundColor Green
    Write-Host "✅ Real-time data is flowing through all components" -ForegroundColor Green
    Write-Host "✅ Superset is ready for visualization creation" -ForegroundColor Green
} else {
    Write-Host "⚠️ Pipeline is mostly operational but may need attention" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📖 For detailed setup instructions, see: SUPERSET_SETUP_GUIDE.md" -ForegroundColor Cyan
