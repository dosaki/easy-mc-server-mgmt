#!/bin/bash
SCRIPT="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

cd "$DIR"

ACTION="$1"
shift
OPTION="$1"
shift


MIN_RAM="2048M"
MAX_RAM="6144M"
CPU_COUNT=3

SERVER_TYPE="vanilla"

LOGFILEDIR="$DIR/logs"
LOGFILE="$LOGFILEDIR/latest.log"


function usage {
  echo "Usage:"
  echo "    $SCRIPT start [options]"
  echo "    $SCRIPT <restart|upgrade> [seconds-until-stop] [options]"
  echo "    $SCRIPT <status|attach|help>"
  echo "    $SCRIPT <stop|clean-backups> [seconds-until-stop]"
  echo "    $SCRIPT log [number-of-lines]"
  echo "    $SCRIPT backup [message]"
  echo "    $SCRIPT cmd <minecraft command>"
  echo "Options:"
  echo "    --type=<type>"
  echo "        Server type: vanilla or paper. Defaults to 'vanilla'"
  echo "    --min-ram=<memory value>"
  echo "        Minimum memory for the JVM for the server. Defaults to '${MIN_RAM}'"
  echo "    --max-ram=<memory value>"
  echo "        Maximum memory for the JVM for the server. Defaults to '${MAX_RAM}'"
  echo "    --cpu-count=<number>"
  echo "        Amount of CPUs dedicated to this server. Defaults to '${CPU_COUNT}'"
}


for i in "$@"; do
  case $i in
  --type=*)
    SERVER_TYPE="${i#*=}"
    shift
    ;;
  --min-ram=*)
    MIN_RAM="${i#*=}"
    shift
    ;;
  --max-ram=*)
    MAX_RAM="${i#*=}"
    shift
    ;;
  --cpu-count=*)
    CPU_COUNT="${i#*=}"
    shift
    ;;
  *)
    usage
    echo "Unknown option ${i}"
    exit 1
    ;;
  esac
done

if [[ "${SERVER_TYPE}" == "vanilla" ]]; then
  SERVER_TYPE=""
else
  SERVER_TYPE=".${SERVER_TYPE}"
fi
SERVER_JAR="server${SERVER_TYPE}.jar"

mkdir -p "$LOGFILEDIR"
touch "$LOGFILE"

SCREEN_PID=`screen -list | grep Detached | awk '{ print $1 }' | tr '.' ' ' | awk '{ print $1 }'`
PID=`ps aux | grep minecraft | grep java | grep -v "SCREEN" | awk '{ print $2 }'`

function wait_for {
  LINE="$1"
  LIMIT="$2"
  num=0
  while true; do
    if [[ ${num} -gt ${LIMIT} ]]; then
      return 1
    fi
    #check if it's been there in the past
    grepped_line=`cat "$LOGFILE" | grep "$LINE"`
    if [ "$grepped_line" != "" ]; then
      return 0
    fi
    num=$((num + 1))
    sleep 1
  done
  return 1
}

function backup_world {
  MESSAGE="$1"
  cd $DIR/world
  git add .
  git commit -am "${MESSAGE}"
}

function cleanup_backups {
  cd "${DIR}"
  git clone file://${DIR}/world prunedWorld --depth=60
  cd ./prunedWorld
  git remote rm origin
  cd "${DIR}"
  rm -rf world
  mv prunedWorld world
}

function send_command {
  COMMAND="$1"
  screen -S $SCREEN_PID -p 0 -X stuff "$COMMAND\n"
}

function status {
  RCON_LINE=""
  FIRST_LINE=`head -1 $LOGFILE | grep "Starting minecraft server version"`
  PLAYERS="0/0"
  if [ "$SCREEN_PID" != "" ]; then
    RCON_LINE=`cat $LOGFILE | grep RCON`
    if [ "$RCON_LINE" == "" ] && [ "$FIRST_LINE" == "" ] || [ "$RCON_LINE" != "" ]; then
      send_command "list"
      sleep 2
      PLAYERS=`tail -1 logs/latest.log | head -1 | awk '{ print $6 }'`
    fi
  fi

  echo "+----"
  echo "| PROCESS INFORMATION"
  if [ "$SCREEN_PID" != "" ]; then
    if [ "$RCON_LINE" == "" ] && [ "$FIRST_LINE" == "" ] || [ "$RCON_LINE" != "" ]; then
      echo "|   Status....: Running"
    else
      echo "|   Status....: Starting"
    fi
    echo "|   PID.......: $PID"
    echo "|   Screen PID: $SCREEN_PID"
    echo "+----"
    echo "| MINECRAFT INFO"
    echo "|   Players: $PLAYERS"
  else
    echo "   Status: Stopped"
  fi
  echo "+----"
}

function start {
  if [ "$SCREEN_PID" == "" ]; then
    screen -d -m java -Xms$MIN_RAM -Xmx$MAX_RAM -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT -XX:+AggressiveOpts -jar $DIR/$SERVER_JAR nogui
    wait_for "Starting minecraft server" 10
    wait_for "Done" 10
  else
    echo "Already running!"
    status
  fi
}

function stop {
  if [ "$SCREEN_PID" == "" ]; then
    echo "Already stopped."
    exit
  fi
  TYPE="$1"
  T="$2"
  H=$((T/60/60%24))
  M=$((T/60%60))
  S=$((T%60))
  TIME=""
  if [ $H -gt 0 ]; then
    TIME="${H}h"
  fi
  if [ $M -gt 0 ]; then
    TIME="${TIME}${M}m"
  fi
  if [ $S -gt 0 ]; then
    TIME="${TIME}${S}s"
  fi
  MESSAGE="Server will $TYPE in $TIME"
  echo "$MESSAGE"
  send_command "say $MESSAGE"
  sleep $T
  echo "Stopping..."
  send_command "stop"
  if [[ "${SERVER_TYPE}" == "vanilla" ]]; then
    wait_for "Saving chunks for level 'world'/the_end" 10
  else
    wait_for "Saving chunks for level 'ServerLevel[world_the_end]'/minecraft:the_end" 10
  fi
  kill $SCREEN_PID
}

function attach {
  echo "NOTE: Press CTRL+A and then CTRL+D to detach again."
  read -n1 -r -p "Press any key to attach..."
  screen -r $SCREEN_PID
}

function log {
  LINES="$1"
  if [ "$LINES" == "" ]; then
    less "$LOGFILE"
  else
    tail -$LINES "$LOGFILE"
  fi
}

function upgrade_paper {
  TIME_UNTIL_STOP=$1
  cd $DIR
  VERSION=$(unzip -qc ./server.paper.jar version.json | jq -r .name)
  
  VERSION_GROUP=$(curl https://papermc.io/api/v2/projects/paper/ | jq -r .version_groups[-1])
  DOWNLOAD_PAGE_CONTENT=$(curl https://papermc.io/api/v2/projects/paper/version_group/${VERSION_GROUP}/builds)
  NEW_VERSION=$(echo ${DOWNLOAD_PAGE_CONTENT} | jq -r .versions[-1])
  BUILD_NR=$(echo ${DOWNLOAD_PAGE_CONTENT} | jq .builds[-1].build)
  NEW_VERSION_URL="https://papermc.io/api/v2/projects/paper/versions/${NEW_VERSION}/builds/503/downloads/paper-${NEW_VERSION}-${BUILD_NR}.jar"
  if [[ "${NEW_VERSION_URL}" == "" ]]; then
    echo "Unable to get download url"
    exit 1
  fi
  if [[ "${DOWNLOAD_PAGE_CONTENT}" == "" ]]; then
    echo "Download page content was empty"
    exit 1
  fi
  if [[ "${VERSION}" == "${NEW_VERSION}" ]]; then
    echo "No upgrade required."
    echo "Latest version is ${NEW_VERSION}."
    exit 2
  fi
  echo "Upgrading from ${VERSION} to ${NEW_VERSION} (${BUILD_NR})"
  wget -O "server.paper.${NEW_VERSION}.jar" "${NEW_VERSION_URL}"
  stop "restart for upgrading to ${NEW_VERSION}" $TIME_UNTIL_STOP
  sleep 1
  backup_world "Before upgrading from ${VERSION} to ${NEW_VERSION}"
  cleanup_backups

  cd $DIR
  mv server.paper.jar "server.paper.old.${VERSION}.jar"
  mv "server.paper.${NEW_VERSION}.jar" server.paper.jar

  upgrade_plugins

  start
}

function upgrade_harbor {
  cd ${DIR}/plugins
  CURRENT_VERSION=$(unzip -qc harbor.jar plugin.yml | grep version | grep -v api | tr '"' ' ' | awk '{print $2}')
  LATEST_RELEASE_INFO=$(curl "https://api.github.com/repos/nkomarn/Harbor/releases" | jq '[.[] | select(.prerelease == false)][0]')
  LATEST_VERSION=$(echo "${LATEST_RELEASE_INFO}" | jq -r .tag_name)
  DOWNLOAD_URL=$(echo "${LATEST_RELEASE_INFO}" | jq -r .assets[0].browser_download_url)

  if [[ "${CURRENT_VERSION}" == "${LATEST_VERSION}" ]]; then
    echo "No upgrade required."
    echo "Latest version is ${LATEST_VERSION}."
  else
    cd ${DIR}/plugins
    wget -O "harbor.${LATEST_VERSION}.jar" "${DOWNLOAD_URL}"
    mv "harbor.${LATEST_VERSION}.jar" harbor.jar
  fi
}

function upgrade_plugins {
  upgrade_harbor
}

function upgrade_vanilla {
  TIME_UNTIL_STOP=$1
  cd $DIR
  VERSION=$(unzip -qc ./server.jar version.json | jq -r .name)
  DOWNLOAD_PAGE_CONTENT=$(curl https://www.minecraft.net/en-us/download/server)
  NEW_VERSION=$(echo "${DOWNLOAD_PAGE_CONTENT}" | grep minecraft_server | grep "\.jar" | grep -v "<a href" | awk '{print $1}')
  NEW_VERSION=${NEW_VERSION/minecraft_server./}
  NEW_VERSION=${NEW_VERSION/.jar/}
  NEW_VERSION_URL=$(echo "${DOWNLOAD_PAGE_CONTENT}" | grep "minecraft_server" | tr '"' ' ' | awk '{print $3}')
  if [[ "${NEW_VERSION_URL}" == "" ]]; then
    echo "Unable to get download url"
    exit 1
  fi
  if [[ "${DOWNLOAD_PAGE_CONTENT}" == "" ]]; then
    echo "Download page content was empty"
    exit 1
  fi
  if [[ "${VERSION}" == "${NEW_VERSION}" ]]; then
    echo "No upgrade required."
    echo "Latest version is ${NEW_VERSION} and you're running ${VERSION}."
    exit 2
  fi
  echo "Upgrading from ${VERSION} to ${NEW_VERSION}"
  wget -O "server.${NEW_VERSION}.jar" "${NEW_VERSION_URL}"
  stop "restart for upgrading to ${NEW_VERSION}" $TIME_UNTIL_STOP
  sleep 1
  backup_world "Before upgrading from ${VERSION} to ${NEW_VERSION}"
  cleanup_backups

  cd $DIR
  mv server.jar "server.old.${VERSION}.jar"
  mv "server.${NEW_VERSION}.jar" server.jar

  start
}

if [ "$ACTION" == "backup" ]; then
  if [ "$OPTION" == "" ]; then
    OPTION="Scheduled backup"
  fi
  backup_world "${OPTION}"
elif [ "$ACTION" == "clean-backups" ]; then
  if [ "$OPTION" == "" ]; then
    OPTION=30
  fi
  stop "restart" $OPTION
  start
elif [ "$ACTION" == "start" ]; then
  start
elif [ "$ACTION" == "stop" ]; then
  if [ "$OPTION" == "" ]; then
    OPTION=30
  fi
  stop "stop" $OPTION
elif [ "$ACTION" == "restart" ]; then
  if [ "$OPTION" == "" ]; then
    OPTION=30
  fi
  stop "restart" $OPTION
  start
elif [ "$ACTION" == "status" ]; then
  status
elif [ "$ACTION" == "attach" ]; then
  attach
elif [ "$ACTION" == "log" ]; then
  log $OPTION
elif [ "$ACTION" == "cmd" ]; then
  send_command "$OPTION"
elif [ "$ACTION" == "upgrade" ]; then
  if [ "$OPTION" == "" ]; then
    OPTION=30
  fi
  upgrade ${OPTION}
else
  usage
  exit 1
fi