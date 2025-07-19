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
#=================================== UTILITY FUNCTIONS ==============================

#when program starts ===> read all databases and store their names in the global variables dbs_list
readAllDatabases(){
	db_list=$(ls -l | tail +2 | grep ^d)
	db_list=$(replaceMultipleSpaces "$db_list" | cut -d' ' -f9)
	dbs_list="$db_list"
}

#handle the select command
do_select(){
	selected_columns=""
	if [[ "$user_cmd" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]]*\*[[:space:]]*[Ff][Rr][Oo][Mm] ]]; then
		selected_columns="*"
	elif [[ "$user_cmd" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]]+([[:alpha:]][[:alnum:][:space:]_,]+)[Ff][Rr][Oo][Mm] ]]; then
		selected_columns="${BASH_REMATCH[1]}"
	fi
	echo "selected columns are: $selected_columns"
}

#handle the insert command
do_insert(){
	echo ""
}

#handle the delete command
do_delete(){
	echo ""
}

#handle the update command
do_update(){
	echo ""
}

readAllDatabases

while true; do
	
	read -p "> " user_cmd
	case "$user_cmd" in
	"ex"* )
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
			echo "You are now operating on database:" $cur_db
		else
			#database doesn't exist
			echo "The database you entered doesn't exist."
		fi
		;;
	"create database "+([a-zA-Z])*([0-9])@(';'))
		echo "Creating a database"
		;;
	"show tables"?(";") )
		if [[ -z $cur_db ]]; then
			echo  "You must select a database first. type 'use <db_name> to select a database."
		else
			cur_db_tables_list=$(ls -l "$cur_db/" | grep ^-)
			cur_db_tables_list=$(replaceMultipleSpaces "$cur_db_tables_list" | cut -d' ' -f9)
			echo "$cur_db_tables_list"
		fi
		;;
	@("select "*|"SELECT "*))
		echo "selecting..."
		do_select "$user_cmd"
		;;
	@("insert "*|"INSERT "*))
		echo "inserting..."
		do_insert "$user_cmd"
		;;
	@("delete "*|"DELETE "*))
		echo "deleting..."
		do_delete "$user_cmd"
		;;
	@("update "*|"UPDATE "*))
		echo "updating..."
		do_update "$user_cmd"
		;;
	*)
		echo "invalid syntax."
		;;
	esac
done