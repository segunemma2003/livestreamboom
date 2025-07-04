import json
import logging
import time
from django.http import JsonResponse, HttpResponse
from django.db import connection
from django.core.cache import cache
from django.conf import settings
import redis

logger = logging.getLogger(__name__)

def health_check(request):
    """
    Enhanced health check endpoint with better error handling
    """
    start_time = time.time()
    health_status = {
        'status': 'healthy',
        'timestamp': int(time.time()),
        'services': {},
        'version': getattr(settings, 'VERSION', 'unknown'),
        'environment': getattr(settings, 'ENVIRONMENT', 'production')
    }
    
    # Check database connection
    db_healthy = True
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            if result and result[0] == 1:
                health_status['services']['database'] = {
                    'status': 'healthy',
                    'response_time': f"{(time.time() - start_time) * 1000:.2f}ms"
                }
            else:
                health_status['services']['database'] = {
                    'status': 'unhealthy',
                    'error': 'query returned unexpected result'
                }
                db_healthy = False
    except Exception as e:
        health_status['services']['database'] = {
            'status': 'unhealthy',
            'error': str(e)
        }
        db_healthy = False
        logger.error(f"Database health check failed: {str(e)}")
    
    # Check Redis connection (non-critical)
    redis_healthy = True
    try:
        cache_start = time.time()
        test_key = f'health_check_{int(time.time())}'
        cache.set(test_key, 'ok', timeout=10)
        if cache.get(test_key) == 'ok':
            cache.delete(test_key)
            health_status['services']['redis'] = {
                'status': 'healthy',
                'response_time': f"{(time.time() - cache_start) * 1000:.2f}ms"
            }
        else:
            health_status['services']['redis'] = {
                'status': 'unhealthy',
                'error': 'cache test failed'
            }
            redis_healthy = False
    except Exception as e:
        health_status['services']['redis'] = {
            'status': 'unhealthy',
            'error': str(e)
        }
        redis_healthy = False
        logger.warning(f"Redis health check failed: {str(e)}")
    
    # Check disk space (if possible)
    try:
        import shutil
        disk_usage = shutil.disk_usage('/app')
        free_space_percent = (disk_usage.free / disk_usage.total) * 100
        health_status['services']['disk'] = {
            'status': 'healthy' if free_space_percent > 10 else 'warning',
            'free_space_percent': f"{free_space_percent:.1f}%"
        }
    except Exception as e:
        health_status['services']['disk'] = {
            'status': 'unknown',
            'error': str(e)
        }
    
    # Overall health status
    # Database is critical, Redis is not
    if not db_healthy:
        health_status['status'] = 'unhealthy'
    elif not redis_healthy:
        health_status['status'] = 'warning'
    
    # Add response time
    health_status['response_time'] = f"{(time.time() - start_time) * 1000:.2f}ms"
    
    # Return appropriate status code
    if health_status['status'] == 'healthy':
        status_code = 200
    elif health_status['status'] == 'warning':
        status_code = 200  # Still return 200 for warnings
    else:
        status_code = 503
    
    return JsonResponse(health_status, status=status_code)

def simple_health(request):
    """
    Simplified health check that just returns OK
    Useful for basic load balancer health checks
    """
    return HttpResponse("OK", content_type="text/plain")

def ready_check(request):
    """
    Readiness check - ensures application is ready to serve traffic
    """
    try:
        # Quick database check
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            result = cursor.fetchone()
            if result and result[0] == 1:
                return HttpResponse("READY", content_type="text/plain")
            else:
                return HttpResponse("NOT READY - DB", content_type="text/plain", status=503)
    except Exception as e:
        logger.error(f"Readiness check failed: {str(e)}")
        return HttpResponse(f"NOT READY - {str(e)}", content_type="text/plain", status=503)

def live_check(request):
    """
    Liveness check - ensures application is still alive
    """
    return HttpResponse("ALIVE", content_type="text/plain")
