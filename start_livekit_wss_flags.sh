#!/bin/bash

echo "🔐 Starting LiveKit with WSS using command line flags"

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
sleep 3

# Check if certificate files exist
if [[ ! -f "livekit-cert.pem" || ! -f "livekit-key.pem" ]]; then
    echo -e "${RED}❌ SSL certificate files not found!${NC}"
    echo "Generating certificates..."
    mkcert -cert-file livekit-cert.pem -key-file livekit-key.pem localhost $MACHINE_IP 127.0.0.1 ::1
fi

echo -e "${BLUE}🚀 Starting LiveKit with command line TLS flags...${NC}"

# Start LiveKit with TLS flags
livekit-server \
  --bind 0.0.0.0 \
  --port 7880 \
  --cert-file livekit-cert.pem \
  --key-file livekit-key.pem \
  --node-ip $MACHINE_IP > livekit-wss.log 2>&1 &

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
    
    # Test HTTPS endpoint
    if curl -k -s https://localhost:7880/ >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HTTPS endpoint responding${NC}"
    else
        echo -e "${YELLOW}⚠️ HTTPS endpoint may not be responding (check logs)${NC}"
    fi
    
    echo -e "\n${BLUE}📋 Recent startup logs:${NC}"
    tail -10 livekit-wss.log
    
else
    echo -e "${RED}❌ LiveKit WSS server failed to start${NC}"
    echo -e "${YELLOW}📝 Full error log:${NC}"
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

echo -e "\n${GREEN}💡 LiveKit WSS server running. Press Ctrl+C to stop.${NC}"
echo -e "${BLUE}📝 Logs: tail -f livekit-wss.log${NC}"

wait
