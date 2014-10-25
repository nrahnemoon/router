#!/bin/bash

# Set the log file and log function
log_file_prefix="/etc/sigmobi/log/"
current_log_file_name="current.log"

log () {
	log_file="$log_file_prefix$(date +"%m%d%y").log"
	if [ ! -e "$log_file" ] ; then
		touch $log_file
		ln -sf $log_file "$log_file_prefix$current_log_file_name"
	fi
	echo "`date`: $1"
        echo "`date`: $1" >> $log_file
}

