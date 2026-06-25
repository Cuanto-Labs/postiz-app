#!/bin/bash
node --experimental-require-module apps/backend/dist/apps/backend/src/main.js &
BACKEND_PID=$!
node --experimental-require-module apps/orchestrator/dist/apps/orchestrator/src/main.js &
ORCHESTRATOR_PID=$!
wait $BACKEND_PID $ORCHESTRATOR_PID
