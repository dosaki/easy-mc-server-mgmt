!#/bin/bash

#
# Author: Tiago 'Dosaki' Correia
#
# This script installs minecraft-server on your machine
# along with a few scripts to help manage your server!
#
# Must be run as root!
#
# Depends:
#	screen
#	wget
#	apt-get
#
# Installs:
#	screen (optional)
#	wget (optional)
#	minecraft_server.jar
#

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

HAS_MISSING_DEPENDENCIES=false;
MISSING_DEPENDENCIES="";

if [ -f /usr/bin/screen ]; then
	HAS_MISSING_DEPENDENCIES=true;
	MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES screen"
fi

if [ -f /usr/bin/wget ]; then
	HAS_MISSING_DEPENDENCIES=true;
	MISSING_DEPENDENCIES="$MISSING_DEPENDENCIES wget"
fi

if [ $HAS_MISSING_DEPENDENCIES ]; then
	if [ $# -eq 0 ]; then
		echo "Dependencies not found: $MISSING_DEPENDENCIES"
		echo "	Please install them using:"
		echo "		sudo apt-get install $MISSING_DEPENDENCIES"
		echo "	or by forcing the installation of missing dependencies with:"
		echo "		$0 -f"
		exit 1;
	elif [ "$1" == "-f" ]; then
		echo "Installing $MISSING_DEPENDENCIES"
		sudo apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install "$MISSING_DEPENDENCIES"
	else
		echo "Option not recognised! Try -f"
		exit 0
	fi	
fi


MC_VERSION="1.7.4"
MC_HOME=/usr/share/minecraft
MC_USER=minecraft
DL_LINK="https://s3.amazonaws.com/Minecraft.Download/versions/$MC_VERSION/minecraft_server.$MC_VERSION.jar"
SCRIPTS_FOLDER=./scripts

MC_USER_EXISTS=`cat /etc/passwd | grep -c "$MC_USER:"`
if [ $MC_USER_EXISTS -eq 0 ]; then
	echo "Setting up minecraft user"
	useradd --home $MV_HOME --create-home -p "" $MC_USER
else
	echo "User $MC_USER was already created!"
	echo "I will continue but check that $MC_USER's home is $MC_HOME"
fi

echo "Downloading minecraft server"
wget $DL_LINK -P $MC_HOME/*
mv $MC_HOME/minecraft_server.$MC_VERSION.jar minecraft_server.jar
chown -R minecraft:minecraft $MC_HOME/*

echo "Setting up minecraft-server scripts"
#Copy minecraft-server script
cp $SCRIPTS/minecraft-serverd.sh /usr/bin/minecraft-server
chmod 777 /usr/bin/minecraft-server

#Copy tab autocompletion for minecraft-server script
cp $SCRIPTS/minecraft-server /etc/bash_completion.d/minecraft-server
chmod 644 /usr/bin/minecraft-server

. /etc/bash_completion.d/minecraft-server

exit 0