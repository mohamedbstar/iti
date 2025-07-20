#! /usr/bin/bash

shopt -s extglob

user_cmd=""
cur_db=""
last_output=""

dbs_list=""
cur_db_tables=""


#=================================== UTILITY FUNCTIONS ==============================

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

#when program starts ===> read all databases and store their names in the global variables dbs_list
readAllDatabases(){
	db_list=$(ls -l | tail +2 | grep ^d)
	db_list=$(replaceMultipleSpaces "$db_list" | cut -d' ' -f9)
	dbs_list="$db_list"
}
loadTablesIntoCurDb(){
	all_tables=$(ls -l "$cur_db" | grep "^-") #choose files only and exclude possible directories
	all_tables=$(replaceMultipleSpaces "$all_tables" | cut -d ' ' -f9)
	cur_db_tables="$all_tables"
}
#handles create table command
do_create_table(){
	cmd="$1"
	echo "in do_create_table"
	table_to_create=""
	columns=""
	#first extract the table name before parsing its columns
	if [[ "$cmd" =~ [Cc][Rr][Ee][Aa][Tt][Ee][[:space:]][Tt][Aa][Bb][Ll][Ee][[:space:]]+([a-zA-Z][a-zA-Z0-9_-]*)[[:space:]]*["("] ]]; then
		echo "table name is: ${BASH_REMATCH[1]}"
		table_to_create="${BASH_REMATCH[1]}"
	fi

	#search if there is an existing table having that name
	table_exists=$(echo "$cur_db_tables" | grep ^"$table_to_create"$)
	if [[ -n "$table_exists" ]]; then
		echo "There is already an existing table with the given name."
		return
	fi
	#create a file in the cur_db directory with that name
	touch "$cur_db/$table_name"

	#parse columns and data types
	#
	#\(([[:space:]]*[a-zA-Z0-9_]+[[:space:]]*(int|string|boolean)[,|[[:space:]]*]?)[[:space:]]*\)[[:space:]]*
	if [[ "$cmd" =~ [[:space:]]*\(([[:space:]]*[^\)]*[[:space:]]*)[[:space:]]*\) ]]; then
		columns="${BASH_REMATCH[1]}"
		echo "columns are: $columns"
	fi
	#+(+([a-zA-Z0-9_])*([[:space:]])@(int|string|boolean)?(,[[:space:]]*))

}
#handles alter table command
do_alter_table(){
	echo "altering"
}

#handles drop table command
do_drop_table(){
	echo "dropping"
}

#handle the select command
do_select(){
	#check if there is a current database selected or not
	if [[ -z "$cur_db" ]]; then
		echo "You must USE a database to begin selecting."
		return
	fi

	#first extract columns to be selected
	selected_columns=""
	if [[ "$user_cmd" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]]*\*[[:space:]]*[Ff][Rr][Oo][Mm] ]]; then
		selected_columns="*"
	elif [[ "$user_cmd" =~ ^[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]]+([[:alpha:]][[:alnum:][:space:]_,]+)[Ff][Rr][Oo][Mm] ]]; then
		selected_columns="${BASH_REMATCH[1]}"
	else
		echo "You must provide at least one column to select."
		return
	fi
	selected_columns=$(echo "$selected_columns" | tr -d ' ')
	echo "selected columns are: $selected_columns"
	#then extract the table name to select from
	if [[ "$user_cmd" =~ [Ff][Rr][Oo][Mm][[:space:]]([a-zA-Z][a-zA-Z0-9_-]+[[:space:]]*;[[:space:]]*) ]]; then
		#statements
		table_name="${BASH_REMATCH[1]}"
		#trim the table name
		table_name=$(echo "$table_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
		table_name=$(echo "$table_name" | sed 's/;$//')
		echo "trimmed table name: $table_name"
	else
		echo "You must provide a table name."
		return
	fi

	#check if there is a table by this name in the cur_db or not
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



#when starting the program ==> load all database names in the global variable dbs_list
readAllDatabases

#program main loop
while true; do
	prompt="> "
	user_cmd=""
	while true; do
		if [[ -n "$user_cmd" ]]; then
			prompt="--"
		fi
    	read -p "$prompt" line
    	user_cmd+="$line"$'\n'

    	[[ "$line" == *";" ]] && break
	done

	#normalize the input to be all without new lines
	user_cmd=$(echo "$user_cmd" | tr $'\n' ' ' )

	case "$user_cmd" in
	@("ex"|"EX")**([[:space:]])";"*([[:space:]]) )
		exit
		;;

	@("show databases"|"SHOW DATABASES")?(";")*([[:space:]]) )
		echo "$dbs_list"
		;;

	@("use "|"USE ")*([[:space:]])@([a-zA-Z])*([a-zA-Z0-9_-])*([[:space:]])@([;])*([[:space:]]) )
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
			#load the tables inside cur_db into cur_db_tables
			loadTablesIntoCurDb
			echo "You are now operating on database:" $cur_db
		else
			#database doesn't exist
			echo "The database you entered doesn't exist."
		fi
		;;

	@("create database "|"CREATE DATABASE ")*([[:space:]])@([a-zA-Z])*([a-zA-Z0-9_-])*([[:space:]])@(';')*([[:space:]]) )
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
			touch "$db_name/.db"
			#update the dbs_list variable
			dbs_list+=$'\n'$db_name
			dbs_list=$(echo "$dbs_list" | sort -k1)
		fi
		;;
	@("drop database "|"DROP DATABASE ")*([[:space:]])@([a-zA-Z_])*([a-zA-Z0-9_-])*([[:space:]])@(';')*([[:space:]]) )
		echo "Dropping database..."
		;;
	#+([a-zA-Z0-9,_[:space:]])
	@("create table "|"CREATE TABLE ")*([[:space:]])@([a-zA-Z_])*([a-zA-Z0-9_-])*([[:space:]])@(["("])*([[:space:]])+(+([a-zA-Z0-9_])*([[:space:]])@(int|string|boolean)?(,|[[:space:]]*))@([")"])*([[:space:]])@(';')*([[:space:]]) )
	#@([cC][rR][eE][aA][tT][eE]+[[:space:]][tT][aA][bB][lL][eE]+[[:space:]]\
	#+([a-zA-Z_][a-zA-Z0-9_-]*)[[:space:]]*\(\
	#+([a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+(int|string|boolean)[[:space:]]*(,[[:space:]]*)?)+\
	#\)[[:space:]]*;) )
	#@("create table "|"CREATE TABLE ")*([[:space:]])@([a-zA-Z]_)*([a-zA-Z0-9_-])*([[:space:]])@(["("]) )	
		if [[ -z "$cur_db" ]]; then
			echo "No database selected. Please select a database first."
		else
			do_create_table "$user_cmd"
		fi
		;;
		
	@("alter table "|"ALTER TABLE ")*([[:space:]])@([a-zA-Z])+([a-zA-Z0-9_-])*([[:space:]])@(';')*([[:space:]]) )
		do_alter_table "$user_cmd"
		;;

	@("drop table "|"DROP TABLE ")*([[:space:]])@([a-zA-Z])+([a-zA-Z0-9_-])*([[:space:]])@(';')*([[:space:]]) )
		do_drop_table "$user_cmd"
		;;
	@("show tables"|"SHOW TABLES")?(";")*([[:space:]]) )
		if [[ -z $cur_db ]]; then
			echo  "You must select a database first. type 'use <db_name> to select a database."
		else
			echo "$cur_db_tables"
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
		echo "your input is $user_cmd"
		echo "invalid syntax."
		;;
	esac
done