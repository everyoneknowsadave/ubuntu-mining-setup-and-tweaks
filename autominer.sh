#! /bin/bash
export DISPLAY=:0
echo "Auto Mining Script Starting - Version 1.0"
# Delcare Functions
rig_reboot () 
{
  printf "%s\n" "Done, system will reboot in 10 seconds..." 1>&3 2>&4
  printf "%s\n" "This script will continue automatically upon reboot..." 1>&3 2>&4           
  sleep 10s
  systemctl reboot     
}

readonly SCRIPT_SAVETO="/usr/local/sbin/autominer.sh"
readonly RIGNAME="rig001"

# test for root

    if [[ $EUID -ne 0 ]]
    then
      printf "%s\n" "Failed - This script is running as root" 
        exit 1
    else
      printf "%s\n" "Success - This script must be run as root "
    fi

# Create variable of where the progress files should go and create directory if it does not exist

    progress="/opt/eth"

    if [ ! -d $progress ]
    then
      printf "%s\n" "Warning - No Progress Directory Exists ...CREATING "
      mkdir -p $progress
    else
      printf "%s\n" "Success - Progress Directory Already Exists"
    fi
	
# check for Ubuntu 16.04

    if [ -e $progress/os_check ]
    then
        printf "%s\n" "Success - Ubuntu 16.04 Found..."
        :
    elif [[ "$(uname -v)" =~ .*16.04.* ]]
    then 
        touch $progress/os_check 
    else
        printf "%s\n" "Failed - Ubuntu 16.04 not found, exiting..."
        exit 
    fi

# set file descriptors for verbose actions, catch verbose on second pass

    exec 3>&1
    exec 4>&2
    exec 1>/dev/null
    exec 2>/dev/null

    if [ -e $progress/verbose ]
    then
        exec 1>&3
        exec 2>&4
    fi 
   
# parsing command line options

    cuda_toolkit=0
    driver_version="nvidia-384"
    skip_action=false
    install=false
    grid=8192
    help=false

    printf "%s\n" "Success - Executing Menu Options if entered!"

    while getopts "hvocdfw:p:" option
    do
        case "${option}" in
        h)
            help=true
            ;;
        v) 
            exec 1>&3
            exec 2>&4
            touch $progress/verbose
            ;;
        o)  
            skip_action=true
            ;;
        c)  
            cuda_toolkit=1 
            ;;                      
        d) 
            driver_version="nvidia-375"
            ;;
        f) 
            install=true
            ;;
        w) 
            printf "%s" "$OPTARG" 1>&3 2>&4 > $progress/wallet_provided
            ;;
        p) 
            printf "%s" "$OPTARG" 1>&3 2>&4 > $progress/pool_provided
            ;;
        \?)
            help=true
            ;;
        esac
    done

    printf "%s\n" "Finished - Executing Menu Options if entered!"

    if [ $help != false ]
    then
        printf "\n%s\n\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n\n%s\n%s\n%s\n\n" \
            "--------- autominer.sh help menu ---------" \
            "-v       enable verbose mode, lots of output" \
            "-c       install CUDA 8.0 toolkit, not required for ethminer" \
            "-h       print this menu" \
            "-d       installs Nvidia 375 driver instead of latest 381" \
            "-f       forces the install of Nvidia driver, can be used with -d" \
            "-o       overclocking only" \
            "-w       input wallet for mining, if not included mining will not start" \
            "-p       input pool http://address:port, default is bitfly ethermine" \
            "example usage:" \
            "sudo autominer.sh -v" \
            "sudo autominer.sh -o -a 0x266e19fbf9ee26adc24b4bd3dd53de8c2a705999" 1>&3 2>&4
        exit 1
    fi

# overwriting script that runs automatically
# This Script to New Directory to Allow Loop Running
# Changed this as I want to update this every time!
   
# setting up permissions and files for automated second and/or third run
    
    if [ -e $progress/autostart_complete ] || [ "$skip_action" = true ]
    then
        printf "%s\n" "Success - AutoStart Already Setup"
        :
    else
        printf "%s\n" "Failed - AutoStart Not Setup, Correcting Issue"
        # Read Linux Users
        read -d "\0" -a user_array < <(who)
        # Remove Password for Auto Login
        grep -q -F "${user_array[0]} ALL=(ALL:ALL) NOPASSWD:/usr/bin/gnome-terminal" /etc/sudoers || printf "%s\n" "${user_array[0]} ALL=(ALL:ALL) NOPASSWD:/usr/bin/gnome-terminal" 1>&3 2>&4 >> /etc/sudoers
        # Give Execute Permissions
        rm $SCRIPT_SAVETO -f
        cp "$(readlink -f $0)" $SCRIPT_SAVETO
        chmod a+x $SCRIPT_SAVETO
        # Create Autostart Directory
        if [ -d "/home/${user_array[0]}/.config/autostart/" ] || mkdir -p "/home/${user_array[0]}/.config/autostart/"
        then           
             printf "%s\n%s\n%s\n%s" "[Desktop Entry]" "Name=eth" \
             "Exec=sudo /usr/bin/gnome-terminal -e $SCRIPT_SAVETO" \
             "Type=Application" 1>&3 2>&4 > /home/${user_array[0]}/.config/autostart/autominer.desktop

             printf "%s\n%s\n" "[Desktop Entry]" "Name=lock" \
             'Exec=/usr/bin/gnome-terminal -e "gnome-screensaver-command -l"' \
             "Type=Application" 1>&3 2>&4 > /home/${user_array[0]}/.config/autostart/lock.desktop
             touch $progress/autostart_complete
        fi                       
    fi 

    if [ -e $progress/auto_login_complete ] || [ "$skip_action" = "true" ]
    then
        :
    else
        printf "%s\n%s\n%s" "[SeatDefaults]" "autologin-user=${user_array[0]}" "autologin-user-timeout=0" 1>&3 2>&4 > /etc/lightdm/lightdm.conf.d/autologin.conf
        touch $progress/auto_login_complete 
    fi
    
# Grabbing materials

    if [ -e $progress/materials_complete ] || [ "$skip_action" = true ]
    then
        :
    else
        printf "%s\n" "Grabbing Drivers, CUDA, Ethminerome materials for later use ..." 1>&3 2>&4
         
        declare -a repos=("graphics-drivers/ppa" "ethereum/ethereum")
        for i in "${repos[@]}"; do
            grep -h "^deb.*$i" /etc/apt/sources.list.d/* > /dev/null 2>&1
            if [ $? -ne 0 ]
            then
                add-apt-repository -y ppa:$i
            else
                echo "ppa:$i already exists"
            fi
        done
        
        apt-get -y install software-properties-common 
        apt-get -y install jq curl
        mkdir -p $progress/setupethminer
        cd $progress/setupethminer
        printf "%s\n" "Downloading cuda repo..." 1>&3 2>&4
        wget "http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_8.0.61-1_amd64.deb" 
        dpkg -i cuda-repo-ubuntu1604_8.0.61-1_amd64.deb 
        printf "%s\n" "Downloading latest ethminer..." 1>&3 2>&4
        wget $(curl -s https://api.github.com/repos/ethereum-mining/ethminer/releases/latest | jq -r ".assets[] | select(.name | test(\"Linux\")) | .browser_download_url")
        tar -xvzf ethminer*.tar.gz 
        apt-get update 
        printf "%s\n" "Done..." 1>&3 2>&4
        touch $progress/materials_complete 
    fi 

# check for Nvidia driver

    if [ "$install" = true ]
    then
        :                                                                                                                                                 $
    elif [ -e $progress/driver_complete ] || [ "$skip_action" = true ]
    then
        :
    elif nvidia-smi 
    then
        printf "%s\n" "Nvidia driver found ..." 1>&3 2>&4
        printf "%s\n" "Generating xorg config with cool-bits enabled" 1>&3 2>&4
        nvidia-xconfig 
        nvidia-xconfig --cool-bits=8 
        touch $progress/driver_complete
        rig_reboot
    else
        install=true   
    fi

    if [ "$install" = true ]
    then
        printf "%s\n" "Grabbing  driver, this may take a while..." 1>&3 2>&4
        apt-get -y --allow-unauthenticated install "$driver_version" 
        printf "%s\n" "Done, system will reboot in 10 seconds..." 1>&3 2>&4
        printf "%s\n" "This will continue automatically upon reboot..." 1>&3 2>&4
        printf "%s\n" "Auto Reboot Disabled Please Manually Restart..." 1>&3 2>&4
        touch $progress/materials_complete 
        rig_reboot
    fi
                               
 # get CUDA 8.0 toolkit

    if [ -e $progress/cuda_toolkit_complete ] || [ "$skip_action" = true ]
    then
        :
    elif [ $cuda_toolkit -eq 1 ]
    then
        if nvcc -V | grep "release 8" 
        then
            printf "%s\n" "CUDA toolkit 8.0 already installed..." 1>&3 2>&4
            touch $progress/cuda_toolkit_complete
        else
            printf "%s\n" "Getting CUDA 8.0 toolkit, this may take a really long time..." 1>&3 2>&4
            apt-get -y install cuda 
            export PATH=/usr/local/cuda-8.0/bin${PATH:+:${PATH}}
            printf "%s\n" "Done..." 1>&3 2>&4
            touch $progress/cuda_toolkit_complete
        fi
    fi
          
# get ethminer
    
    if [ -e $progress/ethminer_complete ] || [ "$skip_action" = true ]
    then
         :
    else
        printf "%s\n" "Installing CUDA optimized ethminer" 1>&3 2>&4
        cp "$progress/setupethminer/bin/ethminer" "/usr/local/sbin/"
        chmod a+x "/usr/local/sbin/ethminer"
        touch $progress/ethminer_complete
        printf "%s\n" "ethminer installed..." 1>&3 2>&4
     fi

# install Ethereum

    if [ -e $progress/ethereum_complete ] || [ "$skip_action" = true ]
    then
        :
    else
        printf "%s\n" "Getting Ethereum..." 1>&3 2>&4
        apt-get -y install ethereum
        printf "%s\n" "Ethereum Miner Installed!..." 1>&3 2>&4
        touch $progress/ethereum_complete 
    fi 

# overclocking and reducing power limit on GTX 1060 and GTX 1070

    exec 1>&3
    exec 2>&4 

    if [ -e $progress/driver_complete ] || grep -E "Coolbits.*8" /etc/X11/xorg.conf 1> /dev/null
    then
        :
    else
        printf "%s\n" "Generating xorg config with cool-bits enabled"
        printf "%s\n" "This will require a one time reboot"
        nvidia-xconfig
        nvidia-xconfig --cool-bits=8
        rig_reboot
    fi 
         
    read -d "\0" -a number_of_gpus < <(nvidia-smi --query-gpu=count --format=csv,noheader,nounits)
    printf "%s\n" "found ${number_of_gpus[0]} gpu[s]..."
    index=$(( number_of_gpus[0] - 1 ))

    for i in $(seq 0 $index)
    do
       gpu_name="null" 

       if nvidia-smi -i $i --query-gpu=name --format=csv,noheader,nounits | grep -E "1060" 1> /dev/null
       then
           gpu_name="1060"
           power_limit=75
           memory_overclock=500
           grid=8192
       elif nvidia-smi -i $i --query-gpu=name --format=csv,noheader,nounits | grep -E "1070" 1> /dev/null
       then 
           gpu_name="1070"
           power_limit=95
           memory_overclock=500
           grid=16384
       elif nvidia-smi -i $i --query-gpu=name --format=csv,noheader,nounits | grep -E "1080" 1> /dev/null
       then 
           gpu_name="1080"
           # power limit which should be between 100.00 W and 216.00 W
           power_limit=100
           memory_overclock=500
           grid=16384
       fi  
       
       if [ "$gpu_name" != "null" ]
       then
           printf "%s\n" "found GeForce GTX $gpu_name at index $i..."
           printf "%s\n" "setting persistence mode..."
           nvidia-smi -i $i -pm 1
           printf "%s\n" "setting power limit to $power_limit watts.."
           nvidia-smi -i $i -pl $power_limit
           printf "%s\n" "setting memory overclock of $memory_overclock Mhz..."
           nvidia-settings -a [gpu:${i}]/GPUMemoryTransferRateOffset[3]=$memory_overclock
       fi
    done
    
    printf "$s\n" "GFX Setup Complete, beginning Ethminer Test"

# Automatic startup with provided wallet address

    if [ -e $progress/wallet_provided ]
    then
       wallet="$(cat $progress/wallet_provided)"
       if [ -e $progress/pool_provided ]
       then
           pool="$(cat $progress/pool_provided)"
       else
           pool="eu1.ethermine.org:4444"
       fi

       printf "%s\n\n" "starting your miner at address $wallet using pool $pool"
       timeout 24h ethminer -U --farm-recheck 400 -F "$pool/$wallet" --cuda-grid-size $grid
       
       if [ "$?" -eq 0 ]
       then
           rig_reboot
       else
           exit
       fi
    fi 
