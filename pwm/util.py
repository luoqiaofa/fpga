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
    print("    -c,--sys-clk=<sys clk freq in Hz> Default is 100000000 ie. 100MHz")
    print("    -f,--work-freq=<work freq in Hz>  Default is 1, ie. 1Hz")
    print("    -d,--duty=<1-100 duty percent>    Default is 50, ie. 50% duty circle")
    print("Example:")
    print("    python3 util.py -c 100000000 -f 1 -d 50")
    print("    or")
    print("    python3 util.py --sys-clk=100000000 --work-freq=1 --duty=50")


if __name__ == '__main__' :
    sys_clk_freq = 100000000 # 100MHz, work freq in HZ
    period_freq  = 1; # unit HZ
    duty         = 50 # 50 % duty circle;
    debug        = False
    opts,args = getopt.getopt(sys.argv[1:], \
            "hDc:f:d:", ["help", "debug", "sys-clk=", "work-freq=","duty="])
    for opt,arg in opts :
        # print("opt:", opt, "arg:", arg)
        if opt in ('-h', "--help") :
            useage_help()
            sys.exit(0)
        elif opt in ('-c', "--sys-clk") :
            sys_clk_freq = int(arg) # 100MHz, work freq in HZ
        elif opt in ('-f', "--work-freq") :
            period_freq = int(arg)
        elif opt in ('-d', "--duty") :
            duty = int(arg)
        elif opt in ('-D', "--debug") :
            debug        = True
        else:
            useage_help()
            sys.exit(-1)

    period_regval = sys_clk_freq // period_freq;
    duty_regval = (period_regval * 50) // 100
    print("00(mode)  : %08x" % 1)
    print("04(period): %08x" % period_regval)
    print("08(duty)  : %08x" % duty_regval)
    
    pass

