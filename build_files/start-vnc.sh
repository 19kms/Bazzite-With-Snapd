#!/bin/bash
export USER=root
export HOME=/root
vncserver :1 -geometry 1280x800 -depth 24
tail -f /root/.vnc/*.log
