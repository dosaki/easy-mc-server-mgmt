#!/bin/bash

#
# This script will check if the minecraft server
# is running and restart it if needed be.
#

minecraft-server status
MC_STATUS=$?	# 0 if status is OK
				# >0 if not running


if($MC_STATUS -gt 0)
then
	logger "Minecraft server was down!"
	/usr/bin/minecraft-server restart;
	logger "Minecraft server was restarted..."
fi

exit 0