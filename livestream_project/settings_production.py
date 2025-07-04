# Add this to your livestream_project/settings_production.py

# Health check settings - ensure these are at the top after imports
import os
from pathlib import Path
import sys

# Ensure health checks work even without full configuration
HEALTH_CHECK_ENABLED = True

# Make sure URLs are accessible
DEBUG_TOOLBAR_ENABLED = False

# Ensure static files work in production
USE_S3 = os.environ.get('USE_S3', 'True').lower() == 'true'

# Add this section right after your ALLOWED_HOSTS configuration:
ALLOWED_HOSTS = [
    'localhost',
    '127.0.0.1',
    '.elasticbeanstalk.com',
    '.amazonaws.com',
    '.netlify.app',
    os.environ.get('DOMAIN_NAME', ''),
]

# Remove empty strings and add wildcard for development
ALLOWED_HOSTS = [host for host in ALLOWED_HOSTS if host]
if not ALLOWED_HOSTS or os.environ.get('DEBUG', 'False').lower() == 'true':
    ALLOWED_HOSTS.append('*')

# Database configuration with better error handling
if os.environ.get('LIVESTREAM_DB_HOST'):
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': os.environ.get('LIVESTREAM_DB_NAME'),
            'USER': os.environ.get('LIVESTREAM_DB_USER'),
            'PASSWORD': os.environ.get('LIVESTREAM_DB_PASSWORD'),
            'HOST': os.environ.get('LIVESTREAM_DB_HOST'),
            'PORT': os.environ.get('LIVESTREAM_DB_PORT', '5432'),
            'OPTIONS': {
                'connect_timeout': 20,
            },
            'CONN_MAX_AGE': 300,  # Keep connections alive
        }
    }
else:
    # Fallback to SQLite for testing/development
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

# Ensure logging doesn't break health checks
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
        'simple': {
            'format': '{levelname} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
    'loggers': {
        'django': {
            'handlers': ['console'],
            'level': os.environ.get('LOG_LEVEL', 'INFO'),
            'propagate': False,
        },
        'livestream': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
        'apps.core': {
            'handlers': ['console'],
            'level': 'DEBUG' if DEBUG else 'INFO',
            'propagate': False,
        },
    },
}

# Redis configuration with fallback
REDIS_URL = os.environ.get('REDIS_URL', 'redis://localhost:6379/0')

CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': REDIS_URL,
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
            'CONNECTION_POOL_KWARGS': {
                'max_connections': 50,
                'retry_on_timeout': True,
            }
        },
        'TIMEOUT': 300,
        'KEY_PREFIX': 'livestream',
        'VERSION': 1,
    }
}

# Add a dummy cache for when Redis is not available
CACHES['dummy'] = {
    'BACKEND': 'django.core.cache.backends.dummy.DummyCache',
}

# Add version and environment info for health checks
VERSION = os.environ.get('APP_VERSION', 'unknown')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'production')

# Security settings - only enable in production
if not DEBUG:
    SECURE_SSL_REDIRECT = os.environ.get('SECURE_SSL_REDIRECT', 'True').lower() == 'true'
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_BROWSER_XSS_FILTER = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    X_FRAME_OPTIONS = 'DENY'
else:
    # Development settings
    SECURE_SSL_REDIRECT = False
