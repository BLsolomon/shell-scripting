#!/bin/bash

# The script ask for a folder name, find it and itirate over it content (can be recursive)
# and does 3 things, if file is archive or compressed, changes the name, else if the file name
# follows the pattern, then checks for access time and if older then two days, delete the file
# else compress the file using gzip and change it name, there is a log file attached and
# on screen only progress bar is displayed

explanation() {
	clear
	printf "\e[1;34m\"%s\e[m\n%s\n%s\n%s\n\e[1;34m%s\"\e[m\n\n"\
	'The script ask for a folder name, find it, itirate over it content (can be recursive) and does 3 things:'\
	'	if file is archive or compressed, changes the name'\
	'	else if file name follows the pattern, checks for access time and if older then two days, delete it'\
	'	else compress the file using gzip and change it name'\
	'there is a log file attached and on screen only progress bar is displayed'
}

# Kill background proccess - progress bar
prc_kill() {
	kill ${1} &>/dev/null
	wait ${1} &>/dev/null
}

# Display on screen while searching
progress_bar() {
	echo "THIS MAY TAKE A WHILE, PLEASE BE PATIENT WHILE "$1"..."
	printf "["
	while [ 1 ]; do
		printf  "▓"
		sleep 1
	done
}

# Search for user input folder
ask_folder() {
	read -p "Enter a location: " location
	progress_bar "SEARCHING" &

	# Stops the progress bar background process in case of unnatural exit
	back_pid=$! && trap 'prc_kill ${back_pid}; echo; echo "Bye ";exit' INT TERM EXIT
	
	# if bash version 4.4++ 
	# mapfile -d $'\0' folders < <(find ~ -type d -name "$location" -print0)
	while IFS=  read -r -d $'\0'; do
		folders+=("$REPLY")
	done < <(find ~ -type d -name "$location" -print0 2>/dev/null)
	kill %% &>/dev/null
	echo "] done!"
}

# Display on screen the search output
chose() {
	echo "Chose your option (0 - "$((len - 1 ))") or -1 to search again: "
	while [ 1 ]; do
		read elm
		[ $elm -gt -1 -a $elm -lt $len ] 2>/dev/null && chosen=${folders[$elm]} && return
		[ $elm -eq -1 ] 2>/dev/null && return || 
		echo "Number only! (0 - "$((len - 1 ))")"
	done
}

# The function which process the files as mentioned above in the brief
if_file() {
	if [ "$(grep "zipped-*" <<<"$1")" ]; then
		[ $(date -r "$1" "+%Y%m%d%H%M") -lt $(date --date="48 hour ago" "+%Y%m%d%H%M") ] && rm -vf "$1" &>>"$logPath"/task.log || touch -c "$1"
	elif [ "$(file "$1" | grep -E "gzip|bzip2|archive")" ]; then
		mv -nv "$1" "`dirname $1`/zipped-`basename $1`" &>>"$logPath"/task.log
	else 
		gzip -vfc "$1" > "$(dirname "$1")/zipped-$(basename "$1")" &>>"$logPath"/task.log && rm -vf "$1" &>>"$logPath"/task.log
	fi
}

itirate_in_folder() {
	for x in "$1/"*; do
		if [ -f "$x" ]; then
			if_file "$x"
		elif [ -d "$x" ]; then
			[ "${flag:+r}" ] && itirate_in_folder "$x" || {
				for y in "$x/"*; do [ -f "$y" ] && if_file "$y"; done
			}
		fi
	done
}

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# Get Opt evaluate flags
options=$(getopt -o hr --long help,recursive -- "$@" 2>/dev/null)
[ $? -eq 0 ] || {
	printf '\e[31m%s\e[0m\n' "Incorrect option provided" >&2
	printf '\e[31m%s\e[0m\n' "[-r] --recursive" >&2
	printf '\e[31m%s\e[0m\n\n' "[-h] --help" >&2
	exit 1 
}

eval set -- "$options"
#[ $1 = -r -o $1 = --recursive ] && flag=true
while true; do
	case "$1" in
    	-h | --help ) explanation; exit 0 ;;
    	-r | --recursive ) flag=true ;;
    	--) shift; break ;;
    esac
    shift
done

clear
while [ 1 ]; do
	ask_folder
	len=${#folders[@]}
	if (( $len )); then
		echo "Found: "
		for (( i=0; i<$len; i++ )); do 
			echo "$i. \"${folders[$i]}\""
		done
		chose
		[ ! -z "$chosen" ] && break
	fi
	echo "Folder not found"
	while [ "$answer" != n -a "$answer" != y ]; do
		read -p "Would you like to try again (y/n) ? " answer
		[ "$answer" = n ] && exit 0
	done
done

progress_bar "WORKING" &
back_pid=$!
logPath="$SCRIPTPATH"		
itirate_in_folder "$chosen"
prc_kill $back_pid
echo "] done!"
while [ "$log" != n -a "$log" != y ]; do
	read -p "Would you like to see the log (y/n) ? " log
	[ $log = y ] && { 
	[ -s "$logPath"/task.log ] && cat "$logPath"/task.log | more || echo "Nothing changed"
	}
done

trap - INT TERM EXIT