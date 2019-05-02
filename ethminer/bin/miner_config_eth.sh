#setx GPU_FORCE_64BIT_PTR 0
#setx GPU_MAX_HEAP_SIZE 100
#setx GPU_USE_SYNC_OBJECTS 1
#setx GPU_MAX_ALLOC_PERCENT 100
#setx GPU_SINGLE_ALLOC_PERCENT 100
./ethminer --farm-recheck 200 -U --cuda-devices 0 1 2 3 -S eu1.ethermine.org:4444 -FS us1.ethermine.org:4444 -O 0x266e19fbf9ee26adc24b4bd3dd53de8c2a70599912.rig001
