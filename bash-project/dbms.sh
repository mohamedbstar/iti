#! /usr/bin/bash

shopt -s extglob

user_cmd=""
cur_db=""
last_output=""

dbs_list=""


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

readAllDatabases(){
	db_list=$(ls -l | tail +2 | grep ^d)
	db_list=$(replaceMultipleSpaces "$db_list" | cut -d' ' -f9)
	dbs_list="$db_list"
}

#when program starts ===> read all databases and store their names in the global variables dbs_list
readAllDatabases

while true; do
	
	read -p "> " user_cmd
	case "$user_cmd" in
	"exi"* )
		exit
		;;
	"show databases"?(";") )
		echo "$dbs_list"
		;;
	"use "+([a-zA-Z0-9])?(";"))
		#parse the user command
		input_db=$(echo "$user_cmd" | cut -d' ' -f2)
		if [[ "$input_db" == *\; ]]; then
			db_name_len=${#input_db}
			input_db=${input_db:0:((db_name_len-1))}
		fi
		#check if the database name exists or not
		exists=$(echo "$dbs_list" | grep "^$input_db$")
		if [[ -n $exists ]]; then
			#the database exists
			cur_db=$input_db
			echo "You are now operating on database:  " $cur_db
		else
			#database doesn't exist
			echo "The database you entered doesn't exist."
		fi
		;;

	"show tables"?(";") )
		if [[ -z $cur_db ]]; then
			echo  "You must select a database first. type 'use <db_name> to select a database."
		else
			
		fi
		;;
	*)
		echo "something else"
		;;
	esac
done