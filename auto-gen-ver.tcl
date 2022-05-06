#!/usr/bin/tclsh
# version_gen.tcl

set cur_path [pwd]
puts "curpath: ${cur_path}"
set SCRIPT_FILE [file normalize [info script]]
puts "filename: $SCRIPT_FILE"
set SCRIPT_PATH [file dirname $SCRIPT_FILE]
puts "SCRIPT_PATH: $SCRIPT_PATH"

set curtime [clock seconds]
set dat [clock format $curtime -format {%Y-%m-%d %H:%M:%S}]
# set dat [clock format ${curtime} -format{%Y-%m-%d %H:%M:%S}]
# puts stdout $dat
set date [clock format $curtime -format {%Y%m%d}]
# puts stdout $date
set  time [clock format $curtime -format {%H%M%S}] 
# puts stdout $time

##注意修改version.v的路径
set file "$SCRIPT_PATH/version.v"
puts "auot generated file: $file"
set fileid [open $file w+]
seek $fileid 0 start
# puts $fileid "`define VERSION       32'hAAAABBBB"
puts $fileid "`define COMPILE_DATE  32'h$date"
puts $fileid "`define COMPILE_TIME  32'hFF$time"
close $fileid

