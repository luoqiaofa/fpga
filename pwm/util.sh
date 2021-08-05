#!/bin/sh
#===============================================================================
#          FILE:  util.sh
#         USAGE:  ./util.sh 
#   DESCRIPTION:  
#       OPTIONS:  ---
#  REQUIREMENTS:  ---
#          BUGS:  ---
#         NOTES:  ---
#        AUTHOR: LuoQiaofa (Luoqf), luoqiaofa@163.com
#  ORGANIZATION: 
#       CREATED: 08/05/2021 09:29:32 AM CST
#      REVISION:  ---
#===============================================================================
useage_help()
{
    printf "Usage:\n"
    printf "    ./util.sh <opt> [arg]\n"
    printf "    -h For help\n"
    printf "    -c <sys clk freq in Hz> Default is 100000000 ie. 100MHz.\n"
    printf "    -f <work freq in Hz>    Default is 0.25,0.5,1,2,4, ie. 1Hz.\n"
    printf "    -d <duty percent:0-100> Default is 50, ie. 50% duty circle.\n"
    printf "    -b <brightness:0-255>   Default is 255,ie. constant lit.\n"
    printf "    -p <polar:0-1>          Default is 0 for high active,\n"
    printf "                                       1 for low active.\n"
    printf "Example:\n"
    printf "    ./util.sh -c 100000000 -f 0.5 -d 50 -b 128 -p 0\n"
}

sys_clk_freq=100000000 # 100MHz, work freq in HZ
period_freq=1  # unit HZ
duty=50 # 50 % duty circle;
brightness=255
polar=0
mode=1
debug="False"
while getopts "hDc:f:d:b:p:" opt; do
    case $opt in
        h)
            useage_help
            exit 0
            ;;
        D)
            debug=$OPTARG
            ;;
        c)
            sys_clk_freq=$OPTARG
            ;;
        f)
            period_freq=$OPTARG
            ;;
        d)
            duty=$OPTARG
            ;;
        b)
            brightness=$OPTARG
            ;;
        p)
            polar=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" 
            exit 0
            ;;
    esac
done

printf "PWM frequency=${period_freq} Hz, duty=${duty}%%, brightness=${brightness} polar=${polar}\n"
period_regval=$(awk "BEGIN{print ${sys_clk_freq}/${period_freq} }")
duty_regval=$(awk "BEGIN{print ${period_regval}*${duty}/100 }")
if [ 1 -eq ${polar} ]
then
    mode=$(( mode | 0x02 ))
fi

printf "0x00(mode)      : 0x%02x(%d)\n" ${mode} ${mode}
printf "0x04(period)    : 0x%08x(%d)\n" ${period_regval} ${period_regval}
printf "0x08(duty)      : 0x%08x(%d)\n" ${duty_regval} ${duty_regval}
printf "0x0c(brightness): 0x%02x(%d)\n" ${brightness} ${brightness}

