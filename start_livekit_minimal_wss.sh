#!/bin/bash

echo "🔐 Starting LiveKit with Minimal WSS Config"

MACHINE_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}')

# Kill existing processes
pkill -f livekit-server 2>/dev/null || true
lsof -ti:7880 | xargs kill -9 2>/dev/null || true
sleep 3

echo "🚀 Starting LiveKit with minimal WSS config..."
livekit-server --config livekit-minimal-wss.yaml > livekit-minimal-wss.log 2>&1 &
LIVEKIT_PID=$!

sleep 5

if lsof -Pi :7880 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✅ LiveKit WSS server started!"
    echo "📱 WSS URL: wss://$MACHINE_IP:7880"
    tail -10 livekit-minimal-wss.log
else
    echo "❌ Failed to start. Logs:"
    cat livekit-minimal-wss.log
    exit 1
fi

trap "kill $LIVEKIT_PID 2>/dev/null; exit" INT TERM
wait
