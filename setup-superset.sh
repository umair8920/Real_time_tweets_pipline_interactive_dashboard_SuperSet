#!/bin/bash

# Wait for Superset to be ready
echo "Waiting for Superset to be ready..."
while ! curl -f http://localhost:8088/health; do
    echo "Superset not ready yet, waiting..."
    sleep 10
done

echo "Superset is ready!"

# Login to get session cookie
echo "Logging into Superset..."
CSRF_TOKEN=$(curl -c cookies.txt -b cookies.txt -X GET http://localhost:8088/api/v1/security/csrf_token/ | jq -r '.result')

LOGIN_RESPONSE=$(curl -c cookies.txt -b cookies.txt -X POST \
  http://localhost:8088/api/v1/security/login \
  -H 'Content-Type: application/json' \
  -H "X-CSRFToken: $CSRF_TOKEN" \
  -d '{
    "username": "admin",
    "password": "admin",
    "provider": "db",
    "refresh": true
  }')

ACCESS_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.access_token')

echo "Logged in successfully!"

# Add Druid database connection
echo "Adding Druid database connection..."
curl -c cookies.txt -b cookies.txt -X POST \
  http://localhost:8088/api/v1/database/ \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "X-CSRFToken: $CSRF_TOKEN" \
  -d '{
    "database_name": "druid",
    "sqlalchemy_uri": "druid://broker:8082/druid/v2/sql/",
    "expose_in_sqllab": true,
    "allow_ctas": false,
    "allow_cvas": false,
    "allow_dml": false,
    "force_ctas_schema": "",
    "allow_run_async": false,
    "cache_timeout": 0,
    "impersonate_user": false,
    "encrypted_extra": "{}",
    "extra": "{\"metadata_params\":{},\"engine_params\":{},\"metadata_cache_timeout\":{},\"schemas_allowed_for_csv_upload\":[]}"
  }'

echo "Druid database connection added!"

# Clean up
rm -f cookies.txt

echo "Superset setup complete!"
echo "You can now access Superset at http://localhost:8088"
echo "Username: admin"
echo "Password: admin"
