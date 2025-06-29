#!/bin/bash

echo "🔐 Starting LiveKit with WSS (Secure WebSocket)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing LiveKit processes
echo "🧹 Stopping existing LiveKit processes..."
pkill -f livekit-server 2>/dev/null || true
lsof -ti:7880 | xargs kill -9 2>/dev/null || true
lsof -ti:7881 | xargs kill -9 2>/dev/null || true
sleep 3

# Check if certificate files exist
if [[ ! -f "livekit-cert.pem" || ! -f "livekit-key.pem" ]]; then
    echo -e "${RED}❌ SSL certificate files not found!${NC}"
    echo "Please run the LiveKit WSS setup script first"
    exit 1
fi

echo -e "${BLUE}🚀 Starting LiveKit server with WSS support...${NC}"

# Start LiveKit with TLS configuration
livekit-server --config livekit-wss.yaml > livekit-wss.log 2>&1 &
LIVEKIT_PID=$!

echo "LiveKit WSS PID: $LIVEKIT_PID"
echo "$LIVEKIT_PID" > livekit-wss.pid

sleep 5

# Check if LiveKit started successfully
if lsof -Pi :7880 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${GREEN}✅ LiveKit WSS server started successfully!${NC}"
    echo -e "${BLUE}📱 WSS Access URLs:${NC}"
    echo "  • WSS URL: wss://$MACHINE_IP:7880"
    echo "  • HTTPS API: https://$MACHINE_IP:7880"
    echo ""
    echo -e "${YELLOW}📋 Configuration:${NC}"
    echo "  • Protocol: WSS (Secure WebSocket)"
    echo "  • Certificate: livekit-cert.pem" 
    echo "  • Private Key: livekit-key.pem"
    echo "  • API Key: devkey"
    echo "  • API Secret: secret"
    
    # Show recent logs
    echo -e "\n${BLUE}📋 Recent startup logs:${NC}"
    tail -10 livekit-wss.log
    
else
    echo -e "${RED}❌ LiveKit WSS server failed to start${NC}"
    echo -e "${YELLOW}📝 Check logs for errors:${NC}"
    cat livekit-wss.log
    exit 1
fi

# Cleanup function
cleanup() {
    echo -e "\n🛑 Stopping LiveKit WSS server..."
    kill $LIVEKIT_PID 2>/dev/null || true
    rm -f livekit-wss.pid 2>/dev/null || true
    echo "✅ LiveKit WSS server stopped"
    exit 0
}

trap cleanup INT TERM

echo -e "\n${GREEN}💡 LiveKit WSS server is running. Press Ctrl+C to stop.${NC}"
echo -e "${BLUE}📝 Logs: tail -f livekit-wss.log${NC}"

wait
