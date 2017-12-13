#!/bin/bash
echo "Starting midpoint container..."
docker run -d -p 8080:8080 --name midpoint evolveum/midpoint:latest
