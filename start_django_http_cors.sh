#!/bin/bash

echo "🐍 Starting Django with HTTP + CORS for HTTPS Frontend"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing Django processes
echo "🧹 Cleaning up existing Django processes..."
pkill -f "manage.py" 2>/dev/null || true
lsof -ti:8000 | xargs kill -9 2>/dev/null || true
sleep 2

echo -e "${BLUE}🚀 Starting Django HTTP server with CORS...${NC}"
python manage.py runserver 0.0.0.0:8000 &
DJANGO_PID=$!

sleep 3

if lsof -Pi :8000 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Django HTTP server started successfully!${NC}"
    echo -e "${BLUE}📱 Access URLs:${NC}"
    echo "  • Local: http://localhost:8000"
    echo "  • Network: http://$MACHINE_IP:8000"
    echo "  • API Test: http://$MACHINE_IP:8000/api/v1/livestream/test-connection/"
    echo ""
    echo -e "${YELLOW}📋 This works with HTTPS frontend because:${NC}"
    echo "  • CORS is properly configured"
    echo "  • HTTPS can make requests to HTTP APIs"
    echo "  • Your React app (HTTPS) → Django API (HTTP) works fine"
    echo ""
    echo -e "${YELLOW}📋 Use this in your React app:${NC}"
    echo "  const [backendUrl] = useState('http://$MACHINE_IP:8000')"
    echo ""
    echo "Django HTTP PID: $DJANGO_PID"
    echo "$DJANGO_PID" > django_http.pid
    
    # Cleanup function
    cleanup() {
        echo -e "\n🛑 Stopping Django HTTP server..."
        kill $DJANGO_PID 2>/dev/null || true
        rm -f django_http.pid 2>/dev/null || true
        echo "✅ Django HTTP server stopped"
        exit 0
    }
    
    trap cleanup INT TERM
    
    echo -e "\n${GREEN}💡 Press Ctrl+C to stop Django HTTP server${NC}"
    wait
    
else
    echo -e "${RED}❌ Django HTTP server failed to start${NC}"
    exit 1
fi
