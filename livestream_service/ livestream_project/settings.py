import os
from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = os.environ.get('SECRET_KEY', 'your-secret-key')

DEBUG = os.environ.get('DEBUG', 'True') == 'True'

ALLOWED_HOSTS = ['localhost', '127.0.0.1', 'livestream-service.com']

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    
    # Third party
    'rest_framework',
    'rest_framework.authtoken',
    'corsheaders',
    'channels',
    'celery',
    'drf_spectacular',
    
    # Local apps
    'core',
    'livestream',
    'streaming',
    'analytics',
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
        'DIRS': [],
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

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('LIVESTREAM_DB_NAME', 'livestream_db'),
        'USER': os.environ.get('LIVESTREAM_DB_USER', 'postgres'),
        'PASSWORD': os.environ.get('LIVESTREAM_DB_PASSWORD', 'password'),
        'HOST': os.environ.get('LIVESTREAM_DB_HOST', 'localhost'),
        'PORT': os.environ.get('LIVESTREAM_DB_PORT', '5432'),
    }
}

# Cache configuration
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379/1'),
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# Channels configuration for WebSockets
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [os.environ.get('REDIS_URL', 'redis://127.0.0.1:6379')],
        },
    },
}

# REST Framework configuration
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework.authentication.TokenAuthentication',
        'core.authentication.ServiceTokenAuthentication',  # For service-to-service calls
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
}

# CORS settings for main app communication
CORS_ALLOWED_ORIGINS = [
    "http://localhost:3000",  # React frontend
    "http://localhost:8000",  # Main Django app
    "https://your-main-app.com",
]

CORS_ALLOW_CREDENTIALS = True

# LiveKit Configuration (Self-hosted)
LIVEKIT_CONFIG = {
    'WS_URL': os.environ.get('LIVEKIT_WS_URL', 'ws://localhost:7880'),
    'HTTP_URL': os.environ.get('LIVEKIT_HTTP_URL', 'http://localhost:7880'),
    'API_KEY': os.environ.get('LIVEKIT_API_KEY', ''),
    'API_SECRET': os.environ.get('LIVEKIT_API_SECRET', ''),
    'WEBHOOK_SECRET': os.environ.get('LIVEKIT_WEBHOOK_SECRET', ''),
    'RECORDING': {
        'enabled': True,
        'storage_type': os.environ.get('RECORDING_STORAGE_TYPE', 'local'),
        'local_path': os.environ.get('RECORDING_LOCAL_PATH', '/var/recordings/'),
        's3_bucket': os.environ.get('RECORDING_S3_BUCKET', ''),
        's3_region': os.environ.get('RECORDING_S3_REGION', 'us-east-1'),
        'base_url': os.environ.get('RECORDING_BASE_URL', 'http://localhost:8001/recordings/'),
    },
    'DEFAULT_ROOM_CONFIG': {
        'empty_timeout': 300,
        'max_participants': 1000,
    }
}

# Main app service configuration
MAIN_APP_CONFIG = {
    'BASE_URL': os.environ.get('MAIN_APP_URL', 'http://localhost:8000'),
    'API_TOKEN': os.environ.get('MAIN_APP_TOKEN', ''),
    'TIMEOUT': 30,
}

# Celery configuration
CELERY_BROKER_URL = os.environ.get('CELERY_BROKER_URL', 'redis://127.0.0.1:6379/0')
CELERY_RESULT_BACKEND = os.environ.get('CELERY_RESULT_BACKEND', 'redis://127.0.0.1:6379/0')
CELERY_ACCEPT_CONTENT = ['json']
CELERY_TASK_SERIALIZER = 'json'
CELERY_RESULT_SERIALIZER = 'json'
CELERY_TIMEZONE = 'UTC'

# Logging
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': 'livestream_service.log',
            'formatter': 'verbose',
        },
        'console': {
            'level': 'DEBUG',
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        'livestream': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': True,
        },
        'streaming': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': True,
        },
    },
}
