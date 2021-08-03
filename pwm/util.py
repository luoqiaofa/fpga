#!/usr/bin/env python
# -*- coding: utf-8 -*-
# ************************************************************************ 
# * @File       : util.py 
# * @Author     : LuoQiaoFa@163.com 
# * @Date       : 2020-06-24 09:19 
# * @Version    : 1.0  
# * @Description: Python Script 
# * @License    : Copyright (C) 2020-, LuoQiaoFa all rights reserved 
#************************************************************************* 
import sys
import os
import os.path
import time
import getopt

def useage_help() :
    print("Usage:")
    print("    python3 util <opt> [arg]")
    print("    -h,--help    For help")
    print("    -c,--sys-clk=<sys clk freq in Hz> Default is 100000000 ie. 100MHz.")
    print("    -f,--work-freq=<work freq in Hz>  Default is 0.25,0.5,1,2,4, ie. 1Hz.")
    print("    -d,--duty=<1-100 duty percent>    Default is 50, ie. 50% duty circle.")
    print("    -b,--brightness=<0-255>           Default is 255,ie. constant lit.")
    print("    -p,--polar=<0-1>                  Default is 0 for high active,")
    print("                                                 1 for low active.")
    print("Example:")
    print("    python3 util.py -c 100000000 -f 1 -d 50")
    print("    or")
    print("    python3 util.py --sys-clk=100000000 --work-freq=1 --duty=50")


if __name__ == '__main__' :
    sys_clk_freq = 100000000 # 100MHz, work freq in HZ
    period_freq  = 1  # unit HZ
    duty         = 50 # 50 % duty circle;
    brightness   = 255
    polar        = 0
    mode         = 1
    debug        = False
    long_opts = ["help", "debug", "sys-clk=", "work-freq=","duty=", "brightness=", "polar="]
    opts,args = getopt.getopt(sys.argv[1:], "hDc:f:d:b:p:", long_opts)
    for opt,arg in opts :
        # print("opt:", opt, "arg:", arg)
        if opt in ('-h', "--help") :
            useage_help()
            sys.exit(0)
        elif opt in ('-c', "--sys-clk") :
            sys_clk_freq = float(arg) # 100MHz, work freq in HZ
        elif opt in ('-f', "--work-freq") :
            period_freq = float(arg)
        elif opt in ('-d', "--duty") :
            duty = float(arg)
        elif opt in ('-b', "--brightness") :
            brightness = int(arg)
        elif opt in ('-p', "--polar") :
            polar = int(arg)
        elif opt in ('-D', "--debug") :
            debug        = True
        else:
            useage_help()
            sys.exit(-1)

    print("PWM frequency=%f Hz, duty=%d, brightness=%d, polar=%d:" % \
            (period_freq, duty, brightness, polar))
    period_regval = int(sys_clk_freq / period_freq);
    duty_regval = int ((period_regval * duty) / 100)
    if (polar) :
        mode = mode | 0x02

    print("0x00(mode)      : 0x%02x" % mode)
    print("0x04(period)    : 0x%08x" % period_regval)
    print("0x08(duty)      : 0x%08x" % duty_regval)
    print("0x0c(brightness): 0x%02x" % brightness)
    
    pass

