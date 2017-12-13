#!/bin/bash
echo "Stopping midpoint container..."
docker stop midpoint
docker rm midpoint
