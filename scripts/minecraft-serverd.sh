#!/bin/bash

# to reside in /usr/bin/


#
# This script starts minecraft using screen so that server commands
# can still be issued
#

OPTION="$1"
MESSAGE="$2"

USER="minecraft"
MC_HOME="/usr/share/minecraft"
MAX_MEM="640M"
MIN_MEM="512M"
HOSTNAME=`hostname`


me=`whoami`

mc_procs=`ps aux | grep -c 'minecraft_server'`
mc_pid=`ps aux |  grep 'minecraft_server' | grep -v 'SCREEN' | grep -v grep  | awk -F ' ' '{print $2}'`
screen_pid=` ps aux |  grep 'minecraft_server' | grep 'SCREEN' | grep -v grep  | awk -F ' ' '{print $2}'`

if [ "$me" != "root" ]
then
        echo "Requires root!"
        exit 1;
fi

function start_mc () {
        if [ $mc_procs -gt 1 ]
        then
                echo "Minecraft server is already running!"
                exit 1;
        fi

        su - "$USER" -c "screen -d -m /usr/bin/java -Xmx$MAX_MEM -Xms$MIN_MEM -jar $MC_HOME/minecraft_server.jar nogui"
        logger "[Minecraft Server] Started"
        echo "Started!"
}

function stop_mc () {
        if [ $mc_procs -lt 2 ]
        then
                echo "Minecraft server is not running."
        else
                echo "Warning players that the server will be shut down in 10 seconds..."
                send_command "say Server will be shut down in 10 seconds."
                sleep 5s
                send_command "say Shutdown in 5 seconds."
                sleep 1s
                send_command "say Shutdown in 4 seconds."
                sleep 1s
                send_command "say Shutdown in 3 seconds."
                sleep 1s
                send_command "say Shutdown in 2 seconds."
                sleep 1s
                send_command "say Shutdown in 1 seconds."
                sleep 1s
                send_command "say Shutting down..."

                sudo kill $mc_pid
                sudo kill $screen_pid

                echo "Checking if minecraft server died..."
                sleep 3;
                mc_procs=`ps aux | grep -c 'minecraft_server'`

                if [ $mc_procs -gt 1 ]
                then
                        echo "Couldn't kill minecraft server."
                        echo "Try using kill -SIGKILL $mc_pid"
                        exit 1;
                else
                        echo "Minecraft server was shut down."
                fi
        fi

        if [ $mc_procs -lt 2 ] && [ "$1" != "ignore" ]
        then
                exit 1;
        fi
}

function mc_status () {
        if [ $mc_procs -gt 1 ]
        then
                echo "Minecraft server is running."
                echo "  Minecraft PID: $mc_pid"
                echo "  Screen PID: $screen_pid"
                exit 0;
        else
                echo "Minecraft server isn't running"
                exit 1;
        fi
}

function take_control () {
        if [ $mc_procs -lt 2 ]
        then
                echo "Minecraft server is not running."
                exit 1;
        fi
        chmod o+rw /dev/pts/*
        su - "$USER" -c "screen -dr $screen_pid..$HOSTNAME"
}

function send_command () {
        command="$1"
        su - "$USER" -c "screen -dr $screen_pid..$HOSTNAME -X stuff '$command'"
        su - "$USER" -c "screen -dr $screen_pid..$HOSTNAME -X stuff `echo -e '\015'`"
}

function print_help () {
        echo "Usage is $0 [help|start|stop|restart|status|control|say|command]"
        echo "help
        This help"

        echo "start
        Starts the server"

        echo "stop
        Stops the server
         - Gives a 10 second warning beforehand"

        echo "restart
        Issues a stop and a start"

        echo "status
        Tells you process information
         - If server is running or not
         - Minecraft server PID
         - Screen Session PID"

        echo "control
        Resumes minecraft server session, allowing you to take control of the server console"

        echo "say
        Allows you to say something to the chat as the server
         - Usage: $0 say 'message'"

        echo "command
        Allows you to issue commands to the server console
         - Usage: $0 command 'command'"
}


case $OPTION in
        start )
                start_mc
                ;;
        stop )
                stop_mc
                ;;
        status )
                mc_status
                ;;
        restart )
                stop_mc "ignore"
                start_mc
                ;;
        control )
                take_control
                ;;
        say )
                send_command "say $MESSAGE"
                ;;
        command )
                send_command "$MESSAGE"
                ;;
        help )
                print_help
                exit 0;
                ;;
        * )
                print_help
                exit 1;
                ;;
esac

