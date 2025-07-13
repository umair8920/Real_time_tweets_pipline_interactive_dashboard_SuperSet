import os

# Superset specific config
ROW_LIMIT = 5000
SUPERSET_WEBSERVER_PORT = 8088

# Flask App Builder configuration
SECRET_KEY = '\2\1thisismyscretkey\1\2\e\y\y\h'

# JWT Secret for async queries (must be at least 32 bytes)
JWT_SECRET_KEY = 'this-is-a-very-long-jwt-secret-key-for-superset-async-queries-that-is-at-least-32-bytes-long'

# MySQL connection for Superset metadata
SQLALCHEMY_DATABASE_URI = 'mysql://twitter_user:twitter_password@mysql:3306/twitter_analytics'

# Flask-WTF flag for CSRF
WTF_CSRF_ENABLED = False

# Cache configuration
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_HOST': 'redis',
    'CACHE_REDIS_PORT': 6379,
    'CACHE_REDIS_DB': 1,
    'CACHE_REDIS_URL': 'redis://redis:6379/1'
}

# Enable feature flags
FEATURE_FLAGS = {
    'ENABLE_TEMPLATE_PROCESSING': True,
    'DASHBOARD_NATIVE_FILTERS': True,
    'DASHBOARD_CROSS_FILTERS': True,
    'DASHBOARD_NATIVE_FILTERS_SET': True,
    'ENABLE_EXPLORE_JSON_CSRF_PROTECTION': False,
    'ENABLE_EXPLORE_DRAG_AND_DROP': True,
    'GLOBAL_ASYNC_QUERIES': False,  # Disable async queries to avoid JWT issues
    'VERSIONED_EXPORT': True,
}

# Enable CORS
ENABLE_CORS = True
CORS_OPTIONS = {
    'supports_credentials': True,
    'allow_headers': ['*'],
    'resources': ['*'],
    'origins': ['*']
}

# Security configuration
TALISMAN_ENABLED = False
PREVENT_UNSAFE_DB_CONNECTIONS = False
