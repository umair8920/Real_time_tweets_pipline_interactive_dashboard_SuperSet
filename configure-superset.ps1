Write-Host "=== Configuring Superset for Twitter Analytics ===" -ForegroundColor Green
Write-Host ""

# Configuration
$SUPERSET_URL = "http://localhost:8088"
$USERNAME = "admin"
$PASSWORD = "admin"

# Function to make authenticated requests
function Invoke-SupersetAPI {
    param(
        [string]$Endpoint,
        [string]$Method = "GET",
        [hashtable]$Body = @{},
        [hashtable]$Headers = @{}
    )
    
    $url = "$SUPERSET_URL$Endpoint"
    $requestParams = @{
        Uri = $url
        Method = $Method
        Headers = $Headers
        ContentType = "application/json"
        TimeoutSec = 30
    }
    
    if ($Method -ne "GET" -and $Body.Count -gt 0) {
        $requestParams.Body = ($Body | ConvertTo-Json -Depth 10)
    }
    
    try {
        return Invoke-RestMethod @requestParams
    }
    catch {
        Write-Host "❌ API Error: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Step 1: Login to Superset
Write-Host "1. Logging into Superset..." -ForegroundColor Cyan

# Get CSRF token
try {
    $csrfResponse = Invoke-WebRequest -Uri "$SUPERSET_URL/api/v1/security/csrf_token/" -Method GET -SessionVariable session
    $csrfToken = ($csrfResponse.Content | ConvertFrom-Json).result
    Write-Host "✅ CSRF token obtained" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to get CSRF token: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Login
$loginBody = @{
    username = $USERNAME
    password = $PASSWORD
    provider = "db"
    refresh = $true
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "$SUPERSET_URL/api/v1/security/login" -Method POST -Body $loginBody -ContentType "application/json" -Headers @{"X-CSRFToken" = $csrfToken} -WebSession $session
    $accessToken = $loginResponse.access_token
    Write-Host "✅ Successfully logged in to Superset" -ForegroundColor Green
}
catch {
    Write-Host "❌ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Set up headers for authenticated requests
$authHeaders = @{
    "Authorization" = "Bearer $accessToken"
    "X-CSRFToken" = $csrfToken
}

Write-Host ""
Write-Host "2. Adding MySQL database connection..." -ForegroundColor Cyan

# Check if database already exists
$databases = Invoke-SupersetAPI -Endpoint "/api/v1/database/" -Headers $authHeaders
$existingDb = $databases.result | Where-Object { $_.database_name -eq "twitter_analytics" }

if ($existingDb) {
    Write-Host "✅ Database connection already exists" -ForegroundColor Green
    $databaseId = $existingDb.id
} else {
    # Add database connection
    $dbBody = @{
        database_name = "twitter_analytics"
        sqlalchemy_uri = "mysql://twitter_user:twitter_password@mysql:3306/twitter_analytics"
        expose_in_sqllab = $true
        allow_ctas = $false
        allow_cvas = $false
        allow_dml = $false
        force_ctas_schema = ""
        allow_run_async = $false
        cache_timeout = 0
        impersonate_user = $false
        encrypted_extra = "{}"
        extra = '{"metadata_params":{},"engine_params":{},"metadata_cache_timeout":{},"schemas_allowed_for_csv_upload":[]}'
    }
    
    $dbResponse = Invoke-SupersetAPI -Endpoint "/api/v1/database/" -Method "POST" -Body $dbBody -Headers $authHeaders
    
    if ($dbResponse) {
        $databaseId = $dbResponse.id
        Write-Host "✅ Database connection added successfully (ID: $databaseId)" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to add database connection" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "3. Testing database connection..." -ForegroundColor Cyan

# Test the connection
$testResponse = Invoke-SupersetAPI -Endpoint "/api/v1/database/$databaseId/test_connection" -Method "POST" -Headers $authHeaders

if ($testResponse) {
    Write-Host "✅ Database connection test successful" -ForegroundColor Green
} else {
    Write-Host "⚠️ Database connection test failed, but continuing..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "4. Refreshing database schema..." -ForegroundColor Cyan

# Refresh schema
$refreshResponse = Invoke-SupersetAPI -Endpoint "/api/v1/database/$databaseId/refresh" -Method "POST" -Headers $authHeaders

Write-Host ""
Write-Host "5. Checking available tables..." -ForegroundColor Cyan

# Get tables
$tablesResponse = Invoke-SupersetAPI -Endpoint "/api/v1/database/$databaseId/tables" -Headers $authHeaders

if ($tablesResponse -and $tablesResponse.result) {
    $tables = $tablesResponse.result
    Write-Host "✅ Found tables: $($tables -join ', ')" -ForegroundColor Green
    
    if ($tables -contains "tweets") {
        Write-Host "✅ 'tweets' table found - ready for visualization!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ 'tweets' table not found in schema" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️ Could not retrieve table list" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Superset Configuration Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "🎉 Your Twitter Analytics Pipeline is Ready!" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Access Information:" -ForegroundColor Cyan
Write-Host "   URL: http://localhost:8088" -ForegroundColor White
Write-Host "   Username: admin" -ForegroundColor White
Write-Host "   Password: admin" -ForegroundColor White
Write-Host ""
Write-Host "📈 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Go to SQL Lab to explore your data" -ForegroundColor White
Write-Host "   2. Create charts from the 'tweets' table" -ForegroundColor White
Write-Host "   3. Build dashboards with your visualizations" -ForegroundColor White
Write-Host ""
Write-Host "Sample Queries to Try:" -ForegroundColor Cyan
Write-Host "   - SELECT COUNT(*) FROM tweets;" -ForegroundColor White
Write-Host "   - SELECT mbti_personality, COUNT(*) FROM tweets GROUP BY mbti_personality;" -ForegroundColor White
Write-Host "   - SELECT DATE(timestamp) as date, COUNT(*) FROM tweets GROUP BY DATE(timestamp);" -ForegroundColor White
