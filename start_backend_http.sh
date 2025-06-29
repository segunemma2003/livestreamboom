#!/bin/bash

echo "🐍 Starting Django Backend with HTTP (No SSL)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing processes
pkill -f "manage.py runserver" 2>/dev/null || true
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
sleep 2

echo -e "${BLUE}🚀 Starting Django HTTP backend on port 8000...${NC}"

python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

sleep 3

if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Django HTTP backend started!${NC}"
    echo -e "${BLUE}📱 Backend URLs:${NC}"
    echo "  • Local: http://localhost:8000"
    echo "  • Network: http://$MACHINE_IP:8000"
    echo "  • API Test: http://$MACHINE_IP:8000/api/v1/livestream/test-connection/"
    echo ""
    echo -e "${BLUE}💡 HTTP Backend Benefits:${NC}"
    echo "  • No SSL certificate issues"
    echo "  • Works with HTTPS frontend via CORS"
    echo "  • Simpler debugging"
    echo ""
    echo "Django HTTP PID: $DJANGO_PID"
    echo "$DJANGO_PID" > django_backend_http.pid
    
    cleanup() {
        echo -e "\n🛑 Stopping Django HTTP backend..."
        kill $DJANGO_PID 2>/dev/null || true
        rm -f django_backend_http.pid 2>/dev/null || true
        echo "✅ Django backend stopped"
        exit 0
    }
    
    trap cleanup INT TERM
    
    echo -e "\n${GREEN}💡 Press Ctrl+C to stop Django HTTP backend${NC}"
    wait
else
    echo -e "${RED}❌ Django HTTP backend failed to start${NC}"
    exit 1
fi
