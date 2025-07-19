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
	#the syntax is: insert into <table[fields?]> values ()
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

do_create_table(){
	cmd="$1"
	
}

#when starting the program ==> load all database names in the global variable dbs_list
readAllDatabases

while true; do
	
	read -p "> " user_cmd
	case "$user_cmd" in
	@("ex"|"EX")* )
		exit
		;;

	@("show databases"|"SHOW DATABASES")?(";") )
		echo "$dbs_list"
		;;

	@("use " | "USE ")+([a-zA-Z0-9])?(";"))
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

	@("create database "|"CREATE DATABASE ")+([a-zA-Z])*([0-9a-zA-Z])@(';') )
		echo "Creating a database..."
		#parse the user command
		db_name=$(echo "$user_cmd" | cut -d' ' -f3 | tr -d ";" )
		#see if there is already existing database with the given name or not
		exists=$(echo "$dbs_list" | grep "^$db_name$")
		if [[ -n $exists ]]; then
			#there exists a database with that name
			echo "Database Already Exists."
		else
			#create a new folder with the given name
			mkdir "$db_name"
			#update the dbs_list variable
			dbs_list+=$'\n'$db_name
			dbs_list=$(echo "$dbs_list" | sort -k1)
		fi
		
		;;

	@("create table " | "CREATE TABLE ")+([a-zA-Z])*([0-9a-zA-Z])@(';') )
		if [[ -z "$cur_db" ]]; then
			echo "No database selected. Please select a database first."
		else
			do_create_table "$user_cmd"
		fi
		;;
	@("show tables"|"SHOW TABLES")?(";") )
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