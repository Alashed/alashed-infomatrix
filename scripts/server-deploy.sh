#!/bin/bash
set -e

APP_DIR=/home/ubuntu/infomatrix

cd "$APP_DIR"
sudo -u ubuntu git clean -fd
sudo -u ubuntu git pull origin main
sudo -u ubuntu npm install --production --silent
sudo systemctl reset-failed infomatrix 2>/dev/null || true
sudo systemctl restart infomatrix
sleep 10
sudo systemctl is-active infomatrix
echo "OK"
