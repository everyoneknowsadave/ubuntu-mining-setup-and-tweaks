#!/bin/bash
#/ Script Name: setup-mining.sh
#/ Author: DAVIDHAZELDENUK
#  Date:   01-02-2018
#/
#/ Error Log Location /tmp/setup-mining.sh.log
#/
#/ Usage: setup-mining.sh
#/ Or: setup-mining <main option> <secondary option>
#/
#/ Options:
#/   --help, -h display this help



readonly MAX_MENU_OPTIONS=1000

usage() {
  grep "^#/" "$0" | cut -c4-
  exit 0
}

# read-only globals
readonly NOCOL="\033[0m"                      # No Color
readonly BLACK="\033[0;30m"                   # Black
readonly WHITE="\033[1;37m"                   # White
readonly LOG_FILE="/tmp/$(basename "$0").log" # temp log file

# Determine major driver version
NVIDIA_DRIVER_VERSION=`awk '/NVIDIA/ {print $8}' /proc/driver/nvidia/version | cut -d . -f 1`
#DEBUG echo $NVIDIA_DRIVER_VERSION

# colored output
_grey()         { local c="\033[1;30m"; echo -e "${c}$*${NOCOL}"; }
_light_grey()   { local c="\033[0;37m"; echo -e "${c}$*${NOCOL}"; }
_red()          { local c="\033[0;31m"; echo -e "${c}$*${NOCOL}"; }
_light_red()    { local c="\033[1;31m"; echo -e "${c}$*${NOCOL}"; }
_green()        { local c="\033[0;32m"; echo -e "${c}$*${NOCOL}"; }
_light_green()  { local c="\033[1;32m"; echo -e "${c}$*${NOCOL}"; }
_orange()       { local c="\033[0;33m"; echo -e "${c}$*${NOCOL}"; }
_yellow()       { local c="\033[1;33m"; echo -e "${c}$*${NOCOL}"; }
_blue()         { local c="\033[0;34m"; echo -e "${c}$*${NOCOL}"; }
_light_blue()   { local c="\033[1;34m"; echo -e "${c}$*${NOCOL}"; }
_purple()       { local c="\033[0;35m"; echo -e "${c}$*${NOCOL}"; }
_light_purple() { local c="\033[1;35m"; echo -e "${c}$*${NOCOL}"; }
_cyan()         { local c="\033[0;36m"; echo -e "${c}$*${NOCOL}"; }
_light_cyan()   { local c="\033[1;36m"; echo -e "${c}$*${NOCOL}"; }

# log output
_date()    { date +"%Y-%m-%d %H:%M:%S"; }
_info()    { echo "$(_date) [INFO]    $*" | tee -a "$LOG_FILE"; }
_warning() { echo "$(_date) [WARNING] $*" | tee -a "$LOG_FILE"; }
_error()   { echo "$(_date) [ERROR]   $*" | tee -a "$LOG_FILE"; }
_fatal()   { echo "$(_date) [FATAL]   $*" | tee -a "$LOG_FILE"; exit 1 ; }

# cleanup triggered on bad exit code
cleanup() {
    echo ""
    _light_red "Exit"
    exit -1
}

parse_input() {
    local input=$1
    local second_input=$2
    re='^[0-9]+$'
    if ! [[ $input =~ $re ]] ; then
        _light_red "$(_error "Input is not a number")"
        sleep 1
    # elif ! [[ $second_input =~ $re ]] ; then
    #     _light_red "$(_error "Second input is not a number")"
    #     sleep 1
    elif [ "$input" -gt 0 -a "$input" -le "$MAX_MENU_OPTIONS" ]; then
        case $input in
        1 | drivers)
            install_drivers_menu $second_input
	;;
        2 | fanspeed)
	   set_fan_speed_menu $second_input
        ;;
        *)
            _light_red "$(_error "No such option")"
        ;;
        esac
    fi
    # exit 0
}

set_fan_speed_menu() {

    local choice=$1

    if [ -z $choice ]; then
        clear
        printf "_grey() testing"
        echo "============================================================"
        echo "*               NVIDIA TWEAK SETTINGS                      *"
        echo "============================================================"
	echo "40	Fix Nvidia-Settings - failed to connect to mir    "
        echo "50	Setup Coolbits Config, do this first!             "
	echo "100.      Set Fan Speed type Value between 40 and 100       "
	echo "200.	Disable Fan Speed Persistence - reset             "
        echo "999.      Back to Main Menu                                 "
        echo "000.      Exit Program                                      "
        read -p "Enter choice [ 40 - 1000 ] " choice
    fi
    case $choice in
        40)
		echo "fixing...fixed hopefully...display nvidia-settings now..."
		export DISPLAY=:0
		nvidia-settings
	;;
        50)
		echo "setting coolbits to allow modification"
		nvidia-xconfig -a --force-generate --allow-empty-initial-configuration --cool-bits=28 --registry-dwords="PerfLevelSrc=0x2222" --no-sli --connected-monitor="DFP-0"
	;;
         100)
			read -p "Enter a fan speed between 40 and 100 to set speed" inputfanspeed
			# Read a numerical command line arg between 40 and 100
			if [ "$inputfanspeed" -eq "$inputfanspeed" ] 2>/dev/null && [ "0$inputfanspeed" -ge "40" ]  && [ "0$inputfanspeed" -le "100" ]
			then
				/usr/bin/nvidia-smi -pm 1 # enable persistance mode
				speed=$inputfanspeed   # set speed

				echo "Setting fan to $speed%."

				# how many GPU's are in the system?
				NUMGPU="$(nvidia-smi -L | wc -l)"

				# loop through each GPU and individually set fan speed
				n=0
				while [  $n -lt  $NUMGPU ];
				do
					# start an x session, and call nvidia-settings to enable fan control and set speed
					service lightdm stop
					xinit /usr/bin/nvidia-settings -a [gpu:${n}]/GPUFanControlState=1 -a [fan:${n}]/GPUTargetFanSpeed=$speed --  :0 -once
					let n=n+1
				done

				echo "Complete"; exit 0;
			else
				echo "Error: Please pick a fan speed between 40 and 100, or stop."; exit 1;
			fi

	;;
	200)
				/usr/bin/nvidia-smi -pm 0 # disable persistance mode

				echo "Enabling default auto fan control."
				echo "Detecting  how many GPUs are in the system..."
				# how many GPU's are in the system?
				NUMGPU="$(nvidia-smi -L | wc -l)"
				echo "Counted $NUMGPU ..."
				# loop through each GPU and individually set fan speed
				n=0
				while [  $n -lt  $NUMGPU ];
				do
					# start an x session, and call nvidia-settings to enable fan control and set speed
					service lightdm stop
					xinit /usr/bin/nvidia-settings -a [gpu:${n}]/GPUFanControlState=0 --  :0 -once
					let n=n+1
				done

				echo "Complete"; exit 0;

        ;;
        999)
                echo "Going to Main Menu"
                main_menu
        ;;
        000)
                exit
        ;;
        *)
            _light_red "$(_error "No such option")"
        ;;
    esac
    exit 0
}

install_drivers_menu() {

    local choice=$1

    if [ -z $choice ]; then
        clear
        echo "============================================================"
        echo "*              INSTALL NVIDIA DRIVERS                      *"
        echo "============================================================"
        echo "1. 	Add PPA:GFX drivers repository                    "
	echo "2.	Display Current Driver Version                    "
        echo "390.  	Install NVIDIA Drivers V390                       "
	echo "999.      Back to Main Menu                                 "
	echo "000.      Exit Program                                      "
        read -p "Enter choice [ 1 - 999 ] " choice
    fi

    case $choice in
        1)
        	add-apt-repository ppa:graphics-drivers/ppa || echo "Sorry Couldn't Add Repo, check connection" && exit
		echo "Driver Repo Added!";
		apt-get update || echo "Sorry couldn't update apt-get" && exit
		echo "apt-get updated successfully"
        ;;
	2)
		echo "Current Driver Listed as $NVIDIA_DRIVER_VERSION"
		echo "Returning to menu in  5s"
		sleep 5
		main_menu
	;;
        390)
		echo "Trying to Install Driver Version 390"
		apt-get update && apt-get install nvidia-390 | "Sorry couldn't install drivers version 384"
        ;;
	999)
		echo "Going to Main Menu"
		main_menu
        ;;
        000)
                exit
        ;;
        *)
            _light_red "$(_error "No such option")"
        ;;
    esac
    exit 0
}

main() {
  parse_input $1 $2
}

main_menu() {
    clear
    echo "========================================================="
    echo "*     Welcome to the Mining Setup Script V1.0           *"
    echo "========================================================="
    echo "1.  Install Nvidia Drivers:             Type the number 1"
    echo "------------or type the commmand drivers-----------------"
    echo ""
    echo ""
    echo "2.  Set Fan Speed Menu                  Type the number 2"
    echo "3.  Not Implemented yet                 Type the number 3" 
    echo "4.  Not Implemented yet                 Type the number 2"
    echo "5.  Not Implemented yet                 Type the number 2"
    echo "6.  Not Implemented yet                 Type the number 2"
    echo "Ctrl C to Exit                                        Bye"

    local choice
    read -p "Enter choice [ 1 - 1000 ] " choice
    parse_input $choice
}

interactive_menu() {
    while true
    do
        main_menu
        read_options
    done
}

# executes only when executed directly not sourced
SCRIPT_PATH="${BASH_SOURCE[0]}";

if [[ $SCRIPT_PATH = "$0" ]]; then
  trap cleanup SIGHUP SIGINT SIGTERM
  [[ "$*" =~ .*--help ]] > /dev/null || [[ "$*" =~ .*-h ]] > /dev/null && usage
  #[[ $# -lt 1 ]] && usage
    if  [[ $# -ge 1 ]]; then
        main "$@"
    else
        interactive_menu
    fi
fi
