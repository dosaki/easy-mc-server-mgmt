easy-mc-server-mgmt
===================

Just a collection of scripts to make minecraft server easier to manage.

Includes an install script as well to set up minecraft server quickly for you! :D
Just clone this repository or download the zip file (and unzip it) and then run:

* install-minecraft-server.sh

The minecraft-server script has the following options:

* help
    * Show help.

* start
	* Starts the server

* stop
    * Stops the server
        * Gives a 10 second warning beforehand

* restart
    * Issues a stop and a start

* status
    * Tells you process information
        * If server is running or not
        * Minecraft server PID
        * Screen Session PID

* control
    * Resumes minecraft server session, allowing you to take control of the server console"

* say
    * Allows you to say something to the chat as the server
        * Usage: minecraft-server say 'message'

* command
    * Allows you to issue commands to the server console
        * Usage: minecraft-server command 'command'
