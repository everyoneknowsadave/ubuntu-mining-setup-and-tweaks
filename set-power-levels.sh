#!/bin/bash

function calcpwr
{
echo "scale=3;
var1 = $maxpower * $gfxpwr;
var1  " \
| bc
}

# Handle --help :)
if [[ "$1" == "--help" ]]; then
    head "$0" -n 9 | tail -n +2 | cut -c 3-
    exit
fi

# Handle --dry-run
# Will Display Commands if not Root User
if [[ $EUID -ne 0 || "$1" == "--dry-run" ]]; then
    echo '# dry-run mode, just showing commands that would be run'
    echo '# (run as root and without --dry-run to execute commands instead)'
    run_or_print=echo
else
    run_or_print=
fi

percent_gfx_power=0.7

num_gpus=$(nvidia-smi -L | wc -l)
for ((i=0; i<num_gpus; i++)); do
    # set persistence mode
    $run_or_print nvidia-smi -i $i -pm 1
    # find maximum supported power limit
    maxpower=$(nvidia-smi -i $i -q -d POWER | grep -F 'Max Power')
    maxpower="${maxpower#*: }"
    maxpower="${maxpower%.00 W}"
    # set power limit to maximum
    if [[ "$power" != "N/A" ]]; then
        gfxname=$(nvidia-smi -i $i --query-gpu=gpu_name --format=csv)
        #echo "name was..." $gfxname
        if echo "$gfxname" | grep --ignore-case '1060'; then
           gfxpwr=0.85
        elif echo "$gfxname" | grep --ignore-case '970'; then
           #max power 240w! bringing down to around 150 seems to give good hashrate
           gfxpwr=0.55
        fi
        newpl=$(calcpwr)
        echo "$newpl"
        echo "Slot $i -- $gfxname -- (MWatts = $maxpower -- PSaving = $newpl watts"
        $run_or_print nvidia-smi -i $i -pl "$newpl"
    fi
done
