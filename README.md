Easy Minecraft Server Management
===================
```
Usage:
    minecraft.sh start [options]
    minecraft.sh <restart|upgrade> [seconds-until-stop] [options]
    minecraft.sh <status|attach|help>
    minecraft.sh <stop|clean-backups> [seconds-until-stop]
    minecraft.sh log [number-of-lines]
    minecraft.sh backup [message]
    minecraft.sh cmd <minecraft command>
Options:
    --type=<type>
        Server type: vanilla or paper. Defaults to 'vanilla'
    --min-ram=<memory value>
        Minimum memory for the JVM for the server. Defaults to '2048M'
    --max-ram=<memory value>
        Maximum memory for the JVM for the server. Defaults to '6144M'
    --cpu-count=<number>
        Amount of CPUs dedicated to this server. Defaults to '3'
```