from django.urls import path
from . import views

app_name = 'livestream'

urlpatterns = [
    path('v1/livestream/generate-token/', views.generate_token, name='generate_token'),
    path('v1/livestream/test-connection/', views.test_connection, name='test_connection'),
    path('v1/livestream/rooms/', views.list_rooms, name='list_rooms'),
    path('v1/livestream/rooms/<str:room_name>/participants/', views.list_participants, name='list_participants'),
]
