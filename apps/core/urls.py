from django.urls import path
from . import views

urlpatterns = [
    path('', views.health_check, name='health_check'),
    path('health/', views.health_check, name='health_detailed'),
    path('health/simple/', views.simple_health, name='health_simple'),
    path('ready/', views.ready_check, name='readiness_check'),
    path('live/', views.live_check, name='liveness_check'),
]

