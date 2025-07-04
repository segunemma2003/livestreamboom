from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse

def root_health_check(request):
    """Simple root health check"""
    return JsonResponse({'status': 'ok', 'service': 'livestream'})

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', root_health_check),  # Root endpoint
    path('health/', include('apps.core.urls')),  # Health check endpoints
    path('api/', include('apps.livestream.urls')),  # Your livestream API
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
