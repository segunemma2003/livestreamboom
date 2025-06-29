#!/bin/bash

echo "🐍 Starting Django with Simple HTTP + CORS"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing Django processes
pkill -f "manage.py runserver" 2>/dev/null || true
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
sleep 2

echo -e "${BLUE}🚀 Starting Django HTTP server with CORS...${NC}"

python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

sleep 3

if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Django HTTP server started!${NC}"
    echo -e "${BLUE}📱 Access URLs:${NC}"
    echo "  • Local: http://localhost:8000"
    echo "  • Network: http://$MACHINE_IP:8000"
    echo "  • API Test: http://$MACHINE_IP:8000/api/v1/livestream/test-connection/"
    echo ""
    echo -e "${BLUE}📋 Notes:${NC}"
    echo "  • HTTP only (no HTTPS certificate issues)"
    echo "  • Works with HTTPS React frontend"
    echo "  • CORS properly configured"
    echo ""
    echo "Django PID: $DJANGO_PID"
    echo "$DJANGO_PID" > django_simple.pid
    
    # Cleanup function
    cleanup() {
        echo -e "\n🛑 Stopping Django server..."
        kill $DJANGO_PID 2>/dev/null || true
        rm -f django_simple.pid 2>/dev/null || true
        echo "✅ Django server stopped"
        exit 0
    }
    
    trap cleanup INT TERM
    
    echo -e "\n${GREEN}💡 Press Ctrl+C to stop Django server${NC}"
    wait
else
    echo "❌ Django server failed to start"
    exit 1
fi
