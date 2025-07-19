#! /usr/bin/bash

shopt -s extglob

user_cmd=""
cur_db=""
last_output=""


replaceMultipleSpaces(){
	string=$1
	len=${#string}
	output=""
	i=0
	while [[ $i -lt $len ]]
	do
		char=${string:$i:1}
		declare -i j=i+1
		if [[ $char == ' ' ]]
		then
			nextChar=${string:$j:1}
			while [[ $nextChar == ' ' && $j -lt $len ]]
			do
				((j++))
				nextChar=${string:$j:1}
			done
			i=$j
			output+=" "
		else
			output+="$char"
			((i++))
		fi
	done

	echo "$output"
}


while true; do
	
	read -p "> " user_cmd
	case "$user_cmd" in
	"exi"* )
		exit
		;;
	"show databases"?(";") )
		db_list=$(ls -l | tail +2 | grep ^d)
		db_list=$(replaceMultipleSpaces "$db_list" | cut -d' ' -f9)
		echo "$db_list"
		;;
	"show tables"?(";") )
		echo "showing tables"
		;;
	*)
		echo "something else"
		;;
	esac
done