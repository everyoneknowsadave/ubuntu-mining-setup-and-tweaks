#! /bin/bash

command -v nvcc >/dev/null 2>&1 || { nvcc_not_installed=true; }
if [ "$nvcc_not_installed" = false ]
then
        printf "%s\n" "CUDA toolkit 8.0 already installed..." 1>&3 2>&4
        touch $progress/cuda_toolkit_complete
else
	printf "$s\n" "Else...what"
fi
