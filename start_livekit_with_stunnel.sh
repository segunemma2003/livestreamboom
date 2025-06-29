#!/bin/bash

echo "🔐 Starting LiveKit with Stunnel WSS Proxy"

# Check if stunnel is available
if ! command -v stunnel &> /dev/null; then
    echo "Installing stunnel..."
    brew install stunnel || {
        echo "❌ Please install stunnel: brew install stunnel"
        exit 1
    }
fi

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing processes
pkill -f livekit-server 2>/dev/null || true
pkill -f stunnel 2>/dev/null || true
lsof -ti:7880 | xargs kill -9 2>/dev/null || true
lsof -ti:7443 | xargs kill -9 2>/dev/null || true
sleep 3

# Start LiveKit on HTTP
echo "🎥 Starting LiveKit on HTTP..."
livekit-server --dev --bind 127.0.0.1 --node-ip $MACHINE_IP > livekit-http.log 2>&1 &
LIVEKIT_PID=$!

sleep 5

# Create stunnel configuration
cat > stunnel.conf << 'STUNNEL_EOF'
[https]
accept = 7443
connect = 127.0.0.1:7880
cert = livekit-cert.pem
key = livekit-key.pem
STUNNEL_EOF

# Start stunnel
echo "🚀 Starting Stunnel SSL proxy..."
stunnel stunnel.conf &
STUNNEL_PID=$!

sleep 3

echo "✅ LiveKit + Stunnel WSS setup complete!"
echo "📱 WSS URL: wss://$MACHINE_IP:7443"

cleanup() {
    echo "🛑 Stopping services..."
    kill $LIVEKIT_PID $STUNNEL_PID 2>/dev/null || true
    exit 0
}

trap cleanup INT TERM
wait
