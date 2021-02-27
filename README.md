Easy Minecraft Server Management
===================
```
Usage:
    minecraft.sh <start|stop|restart|clean-backups|upgrade|status|attach> [options]
    minecraft.sh help
    minecraft.sh log [number-of-lines]
    minecraft.sh backup [message]
    minecraft.sh cmd <minecraft command>
Options:
    --type=<type>
        Server type: vanilla or paper. Defaults to the last started type: 'vanilla'
    --min-ram=<memory value>
        Minimum memory for the JVM for the server. Defaults to '2048M'
    --max-ram=<memory value>
        Maximum memory for the JVM for the server. Defaults to '6144M'
    --cpu-count=<number>
        Amount of CPUs dedicated to this server. Defaults to '3'
    --delay=<seconds>
        Number of seconds to wait until the server stops (useful to warn players). Defaults to '30'
```