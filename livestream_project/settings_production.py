import os
from pathlib import Path
import sys

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(BASE_DIR))

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('SECRET_KEY', 'change-me-in-production')

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = os.environ.get('DEBUG', 'False').lower() == 'true'

# Health check settings
HEALTH_CHECK_ENABLED = True
DEBUG_TOOLBAR_ENABLED = False

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
if not ALLOWED_HOSTS or DEBUG:
    ALLOWED_HOSTS.append('*')

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Third party apps
    'rest_framework',
    'corsheaders',
    'django_celery_beat',
    
    # Local apps - using correct app names from your structure
    'apps.core',
    'apps.livestream',
    'apps.analytics',
    'apps.streaming',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'livestream_project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'livestream_project.wsgi.application'
ASGI_APPLICATION = 'livestream_project.asgi.application'

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

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

# S3 Configuration for your specific buckets
USE_S3 = os.environ.get('USE_S3', 'True').lower() == 'true'

if USE_S3:
    # AWS S3 settings
    AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
    AWS_S3_REGION_NAME = os.environ.get('AWS_S3_REGION_NAME', 'us-east-1')
    
    # Your specific bucket names
    AWS_STORAGE_BUCKET_NAME = 'livestream-static'
    AWS_MEDIA_BUCKET_NAME = 'livestream-medias'
    
    # S3 settings
    AWS_DEFAULT_ACL = 'public-read'
    AWS_S3_OBJECT_PARAMETERS = {
        'CacheControl': 'max-age=86400',
    }
    AWS_S3_FILE_OVERWRITE = False
    AWS_QUERYSTRING_AUTH = False
    
    # Custom storage backends for separate buckets
    AWS_LOCATION = 'static'
    
    # Static files configuration
    STATICFILES_STORAGE = 'storages.backends.s3boto3.StaticS3Boto3Storage'
    STATIC_URL = f'https://{AWS_STORAGE_BUCKET_NAME}.s3.amazonaws.com/{AWS_LOCATION}/'
    
    # Media files configuration - using separate bucket
    DEFAULT_FILE_STORAGE = 'livestream_project.storage_backends.MediaStorage'
    MEDIA_URL = f'https://{AWS_MEDIA_BUCKET_NAME}.s3.amazonaws.com/media/'
    
    # CloudFront support (optional)
    AWS_S3_CUSTOM_DOMAIN = os.environ.get('AWS_S3_CUSTOM_DOMAIN')
    if AWS_S3_CUSTOM_DOMAIN:
        STATIC_URL = f'https://{AWS_S3_CUSTOM_DOMAIN}/static/'
        MEDIA_URL = f'https://{AWS_S3_CUSTOM_DOMAIN}/media/'
else:
    # Local static files (development)
    STATIC_URL = '/static/'
    MEDIA_URL = '/media/'

STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_ROOT = BASE_DIR / 'media'

STATICFILES_DIRS = [
    BASE_DIR / 'static',
] if (BASE_DIR / 'static').exists() else []

# Default primary key field type
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Redis Configuration with fallback
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

# Celery Configuration
CELERY_BROKER_URL = os.environ.get('CELERY_BROKER_URL', REDIS_URL)
CELERY_RESULT_BACKEND = os.environ.get('CELERY_RESULT_BACKEND', REDIS_URL)
CELERY_ACCEPT_CONTENT = ['application/json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = TIME_ZONE

# Django Channels
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [REDIS_URL],
        },
    },
} if 'channels' in INSTALLED_APPS else {}

# Django REST Framework
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.SessionAuthentication',
        'apps.core.authentication.ServiceTokenAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}

# CORS Configuration
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    os.environ.get('FRONTEND_URL', ''),
]

# Remove empty strings
CORS_ALLOWED_ORIGINS = [origin for origin in CORS_ALLOWED_ORIGINS if origin]

# Main App Integration
MAIN_APP_CONFIG = {
    'BASE_URL': os.environ.get('MAIN_APP_URL', 'https://your-main-app.com'),
    'TOKEN': os.environ.get('MAIN_APP_TOKEN', ''),
    'TIMEOUT': 30,
}

# LiveKit Configuration
LIVEKIT_CONFIG = {
    'WS_URL': os.environ.get('LIVEKIT_WS_URL', 'ws://localhost:7880'),
    'HTTP_URL': os.environ.get('LIVEKIT_HTTP_URL', 'http://localhost:7880'),
    'API_KEY': os.environ.get('LIVEKIT_API_KEY', 'devkey'),
    'API_SECRET': os.environ.get('LIVEKIT_API_SECRET', 'secret'),
    'WEBHOOK_SECRET': os.environ.get('LIVEKIT_WEBHOOK_SECRET', ''),
}

# Recording Configuration
RECORDING_CONFIG = {
    'STORAGE_TYPE': os.environ.get('RECORDING_STORAGE_TYPE', 'local'),
    'S3_BUCKET': os.environ.get('RECORDING_S3_BUCKET', ''),
    'S3_REGION': os.environ.get('RECORDING_S3_REGION', 'us-east-1'),
    'BASE_URL': os.environ.get('RECORDING_BASE_URL', '/media/recordings/'),
    'LOCAL_PATH': '/var/recordings/',
}

# Email Configuration
EMAIL_BACKEND = os.environ.get('EMAIL_BACKEND', 'django.core.mail.backends.console.EmailBackend')
if EMAIL_BACKEND == 'django.core.mail.backends.smtp.EmailBackend':
    EMAIL_HOST = os.environ.get('EMAIL_HOST', 'email-smtp.us-east-1.amazonaws.com')
    EMAIL_PORT = int(os.environ.get('EMAIL_PORT', '587'))
    EMAIL_USE_TLS = os.environ.get('EMAIL_USE_TLS', 'True').lower() == 'true'
    EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
    EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')

# Add version and environment info for health checks
VERSION = os.environ.get('APP_VERSION', 'unknown')
ENVIRONMENT = os.environ.get('ENVIRONMENT', 'production')

# Logging configuration
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

# Only add file logging if we're in a Docker container or have write permissions
if os.path.exists('/app') or os.environ.get('DOCKER_CONTAINER'):
    # Create logs directory if it doesn't exist
    log_dir = Path('/app/logs')
    log_dir.mkdir(parents=True, exist_ok=True)
    
    # Add file handler only if directory exists and is writable
    if log_dir.exists() and os.access(log_dir, os.W_OK):
        LOGGING['handlers']['file'] = {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/app/logs/django.log',
            'formatter': 'verbose',
        }
        # Add file handler to existing handlers
        LOGGING['root']['handlers'].append('file')
        LOGGING['loggers']['django']['handlers'].append('file')
        LOGGING['loggers']['livestream']['handlers'].append('file')

# Security Settings for Production
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
