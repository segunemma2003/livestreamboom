#!/bin/bash

echo "🐍 Starting Django Backend with SSL (runserver_plus)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing processes
pkill -f "runserver_plus" 2>/dev/null || true
pkill -f "manage.py runserver" 2>/dev/null || true
lsof -ti:8443 | xargs kill -9 2>/dev/null || true
sleep 2

# Verify certificates and dependencies
if [[ ! -f "backend-cert.pem" || ! -f "backend-key.pem" ]]; then
    echo -e "${RED}❌ Backend certificates not found${NC}"
    exit 1
fi

# Check django-extensions
if ! python -c "import django_extensions" 2>/dev/null; then
    echo "Installing django-extensions..."
    pip install django-extensions Werkzeug pyOpenSSL
fi

echo -e "${BLUE}🚀 Starting Django with runserver_plus HTTPS...${NC}"

python manage.py runserver_plus 0.0.0.0:8443 \
    --cert-file backend-cert.pem \
    --key-file backend-key.pem \
    --nopin &

DJANGO_PID=$!

sleep 5

if lsof -Pi :8443 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Django HTTPS backend (runserver_plus) started!${NC}"
    echo -e "${BLUE}📱 Access: https://$MACHINE_IP:8443${NC}"
    echo "Django PID: $DJANGO_PID"
    echo "$DJANGO_PID" > django_runserver_ssl.pid
    
    cleanup() {
        kill $DJANGO_PID 2>/dev/null || true
        rm -f django_runserver_ssl.pid 2>/dev/null || true
        exit 0
    }
    
    trap cleanup INT TERM
    wait
else
    echo -e "${RED}❌ runserver_plus failed to start${NC}"
    kill $DJANGO_PID 2>/dev/null || true
    exit 1
fi
