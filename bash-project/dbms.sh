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
	pk="" #boolean variable to indicate if a pk has been set to this table or not
	col_names_fo_far=""
	#first extract the table name before parsing its columns
	if [[ "$cmd" =~ [Cc][Rr][Ee][Aa][Tt][Ee][[:space:]][Tt][Aa][Bb][Ll][Ee][[:space:]]+([a-zA-Z][a-zA-Z0-9_-]*)[[:space:]]*["("] ]]; then
		echo "table name is: ${BASH_REMATCH[1]}"
		table_to_create="${BASH_REMATCH[1]}"
		if [[ "$table_to_create" =~ ^[0-9] ]]; then
			echo "Table name can't start with a number"
			return
		fi
	fi

	#search if there is an existing table having that name
	table_exists=$(echo "$cur_db_tables" | grep ^"$table_to_create"$)
	if [[ -n "$table_exists" ]]; then
		echo "There is already an existing table with the given name."
		return
	fi
	
	#parse columns and data types
	#
	#\(([[:space:]]*[a-zA-Z0-9_]+[[:space:]]*(int|string|boolean)[,|[[:space:]]*]?)[[:space:]]*\)[[:space:]]*
	if [[ "$cmd" =~ [[:space:]]*\(([[:space:]]*[^\)]*[[:space:]]*)[[:space:]]*\) ]]; then
		columns="${BASH_REMATCH[1]}"
		echo "columns are: $columns"
	else
		echo "You must provide proper column names and types"
		return
	fi
	#+(+([a-zA-Z0-9_])*([[:space:]])@(int|string|boolean)?(,[[:space:]]*))
	columns=$(replaceMultipleSpaces "$columns")
	#trim columns
	columns=$(echo "$columns" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
	#cut by comma
	columns=$(echo "$columns" | awk 'BEGIN { RS=","; FS=" " } { print $1":",$2 }' | tr -d ' ')
	columns+=":" #to be able to check for PK
	#loop through the columns registering them into .db file
	#check for conflicting names, improper data types and duplicate PK
	while read line; do
		col=$(echo "$line" | cut -d: -f1)
		dtype=$(echo "$line" | cut -d: -f2)
		p_k=$(echo "$line" | cut -d: -f3)
		if [[ -z "$col" || -z "$dtype" ]]; then
			echo "Field name of data type is missing, you must provide complete field info..."
			return
		fi
		#check for invalid data type
		if [[ "$dtype" != "int" && "$dtype" != "string" && "$dtype" != "boolean" ]]; then
			echo "Invalid data type: $dtype"
			return
		fi
		
		#duplicate col name
		col_in_cols=$(echo "$col_names_fo_far" | grep ^"$col"$ )
		if [[ -n "$col_in_cols" ]]; then
			echo "You must provide unique column names. [$col]"
			return
		fi
		col_names_fo_far+=$'\n'"$col" #append the column name for comparison with upcoming columns
		#duplicate pk
		if [[ -n "$p_k" && -n "$pk"  ]]; then
			echo "You can't provide more than one column as a PK"
			return
		fi
		if [[ -n "$p_k" ]]; then
			pk="$p_k"
		fi
		#write info in the file
		(echo "$line" >> "$cur_db/.$table_to_create")
	done <<< "$columns"
	#create a file 
	(touch "$cur_db/$table_to_create")
	#update cur_db_tables variable
	cur_db_tables+=$'\n'"$table_to_create"
	#add the table to the .db file
	(echo "$table_to_create" >> "$cur_db/.db")
}
#handles alter table command
do_alter_table(){
	echo "altering"
}
#handles describe table command
do_describe_table(){
	echo "describing table"
}
#handles drop table command
do_drop_table(){
	if [[ -z "$cur_db" ]]; then
		echo "You must USE a database to drop a table."
		return
	fi
	table_to_drop=""
	cmd="$1"
	#get the table name
	if [[ "$cmd" =~ [Dd][Rr][Oo][Pp][[:space:]][Tt][Aa][Bb][Ll][Ee][[:space:]]+([a-zA-Z_][a-zA-Z0-9_-]*)[[:space:]]*";"[[:space:]]* ]]; then
		table_to_drop="${BASH_REMATCH[1]}"
	else
		echo "You must provide a table name."
		return
	fi
	#see if there is a table with that name in the cur_db tables
	exists=$(echo "$cur_db_tables" | grep ^"$table_to_drop"$)
	if [[ -z "$exists" ]]; then
		echo "The table you entered doesn't exist"
		return
	fi
	#remove table from .db and delete its file
	(rm "$cur_db/$table_to_drop")
	(rm "$cur_db/.$table_to_drop")
	(sed -i '/^'"$table_to_drop"'$/d' "$cur_db/.db")
	#update the variable cur_db_tables
	#cur_db_tables=$(echo "$cur_db_tables" | awk -v tname="$table_to_drop" '{
	#	if($0 == tname){
	#		print tname
	#	}
	#}')
	cur_db_tables=$(ls -l "$cur_db" | grep ^-)
	cur_db_tables=$(replaceMultipleSpaces "$cur_db_tables" | cut -d' ' -f9)
	echo "deleted table $table_to_drop"
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
	if [[ -z "$cur_db" ]]; then
		echo "You must USE a database to insert."
		return
	fi
	#the syntax is: insert into <table [fields?] > values ()
	table_to_insert=""
	cmd="$1"
	fields_to_insert=""
	values_to_insert=""
	table_fields=""
	table_fields_types=""
	table_exists=""
	declare -i number_of_fields=0
	declare -i number_of_values=0
	declare -i number_of_table_fields=0
	
	#get table name
	if [[ $cmd =~ [Ii][Nn][Ss][Ee][Rr][Tt][[:space:]]+[Ii][Nn][Tt][Oo][[:space:]]+([a-zA-Z][a-zA-Z0-9_-]*)[[:space:]]*[(]?[[:space:]a-zA-Z0-9_,-]*[)]?[[:space:]]*[Vv][Aa][Ll][Uu][Ee][Ss] ]]; then
		table_to_insert="${BASH_REMATCH[1]}"
		echo "table name is: $table_to_insert"
	else
		echo "Invalid table name."
		return
	fi
	#check the table name exists in cur_db
	table_exists=$(cat "$cur_db/.db" | grep ^"$table_to_insert"$)
	if [[ $table_exists == "" ]]; then
		echo "Table doesn't exist."
		return
	fi
	table_fields=$(cat "$cur_db/.$table_to_insert" | cut -d: -f1)
	table_fields_types=$(cat "$cur_db/.$table_to_insert" | cut -d: -f2)
	number_of_table_fields=$(cat "$cur_db/.$table_to_insert" | wc -l)
	(cat "$cur_db/.$table_to_insert")
	echo "number of table fields: $number_of_table_fields"
	#get fields if existing
	if [[ "$cmd" =~  [Ii][Nn][Tt][Oo][[:space:]]+[a-zA-Z][a-zA-Z0-9_-]*[[:space:]]*([\(][[:space:]a-zA-Z0-9_,-]*[\)][[:space:]]*)[Vv][Aa][Ll][Uu][Ee][Ss] ]]; then
		fields_to_insert="${BASH_REMATCH[1]}"
		#trim these fields
		fields_to_insert=$(echo "$fields_to_insert" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/,$//' )
		fields_to_insert=$(echo "$fields_to_insert" | awk 'BEGIN { FS="," } { print $1":",$2 }' | tr -d ' ' | tr -d ')' | tr -d  '(' | sed 's/:$//')
		number_of_fields=$(echo "$fields_to_insert" | awk 'BEGIN{FS=":"} {print NF}')
		echo "fields to insert: $fields_to_insert and they are $number_of_fields"
	fi
	#get values to insert
	if [[ "$cmd" =~ [Vv][Aa][Ll][Uu][Ee][Ss][[:space:]]*([^\)]+) ]]; then
		values_to_insert="${BASH_REMATCH[1]}"
		values_to_insert=$(echo "$values_to_insert" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/,$//' | tr -d ')' | tr -d  '(')
		values_to_insert=$(echo "$values_to_insert" | awk 'BEGIN { FS=":" } {
		 for(i=1;i<=NF;i++){
		 	print $i
		 }
		}' |tr -d ' ' | tr $'\n' ':' | sed 's/:$//' )
		number_of_values=$(echo "$values_to_insert" | awk 'BEGIN{FS=","} {print NF}')
		if [[ $number_of_values -eq 0 ]]; then
			#as it could match () and don't go to else condition
			echo "You must provide values to insert into the table"
			return
		fi
		echo "values to insert: $values_to_insert and they are $number_of_values"
	else
		echo "You must provide values to insert into the table"
		return
	fi
	#check equal number of values and fields if exist
	if [[ $number_of_fields -gt 0 ]]; then
		#check if number of fields not greater than number of fields in the table
		if [[ $number_of_fields -gt $number_of_table_fields ]]; then
			echo "You must provide number of fields not greater than number of fields in the table."
			return
		fi
		
		#check equal number of provided fields and values
		if [[ $number_of_fields -ne $number_of_values ]]; then
			echo "Unequal number of fields and values."
			return
		fi
		#check matching data types for provided values and fields => get every data type for each field and compare it with value
		IFS=":" read -ra fields_array <<< $fields_to_insert
		IFS=":" read -ra values_array <<< $values_to_insert
		#check that all provided fields exist int the table
		#read -ra table_fields_array <<< $table_fields
		for ((i=0; i<$number_of_fields; i++)); do
			exists=$(echo "$table_fields" | grep ^"${fields_array[$i]}"$)
			if [[ "$exists" == "" ]]; then
				echo "field [${fields_array[$i]}] doesn't exist in the table"
			fi
		done
		for((i=0; i<number_of_fields;i++)); do
			#get the field $i
			field_i="${fields_array[$i]}"
			value_i="${values_array[$i]}"
			field_i_type=$(grep field_i "$cur_db/.$table_to_insert" | cut -d: -f2)
			if [[ $field_i_type == "int" ]]; then
				if [[ ! $value_i =~ ^[0-9]+$ ]]; then
					echo "$value_i is not of type $field_i_type"
				fi
			fi
			if [[ $field_i_type == "string" ]]; then
				if [[ ! $value_i =~ ^[[a-zA-Z0-9_[[:space:]]-]+$ ]]; then
					echo "$value_i is not of type $field_i_type"
				fi
			fi
			if [[ $field_i_type == "boolean" ]]; then
				if [[ ! $value_i =~ ^[01]$ ]]; then
					echo "$value_i is not of type $field_i_type"
				fi
			fi
		done
	else
		#if not providing fields ==> check values are equal to table fields in type and number
		
		if [[ $number_of_table_fields -ne $number_of_values ]]; then
			echo "You must provide a number values that matches number of table fields"
			return
		fi
	fi
	
	
	#if there is a field that is a primary key, check the consistency

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
	#([[:space:]])@([a-zA-Z])*([a-zA-Z0-9_-])*([[:space:]])@(';')*([[:space:]])
	@("create database "|"CREATE DATABASE ")* )
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
	#@("drop database "|"DROP DATABASE ")*([[:space:]])@([a-zA-Z_])*([a-zA-Z0-9_-])*([[:space:]])@(';')*([[:space:]]) )
	@("drop database "|"DROP DATABASE ")* )	
		echo "Dropping database..."
		;;
	#+([a-zA-Z0-9,_[:space:]])
	#@("create table "|"CREATE TABLE ")*([[:space:]])@([a-zA-Z_])*([a-zA-Z0-9_-])*([[:space:]])@(["("])*([[:space:]])+(+([a-zA-Z0-9_])*([[:space:]])@(int|string|boolean)?(,|[[:space:]]*))@([")"])*([[:space:]])@(';')*([[:space:]]) )
	#@([cC][rR][eE][aA][tT][eE]+[[:space:]][tT][aA][bB][lL][eE]+[[:space:]]\
	#+([a-zA-Z_][a-zA-Z0-9_-]*)[[:space:]]*\(\
	#+([a-zA-Z_][a-zA-Z0-9_]*[[:space:]]+(int|string|boolean)[[:space:]]*(,[[:space:]]*)?)+\
	#\)[[:space:]]*;) )
	#@("create table "|"CREATE TABLE ")*([[:space:]])@([a-zA-Z]_)*([a-zA-Z0-9_-])*([[:space:]])@(["("]) )	
	@("create table "|"CREATE TABLE ")* )	
		if [[ -z "$cur_db" ]]; then
			echo "No database selected. Please select a database first."
		else
			do_create_table "$user_cmd"
		fi
		;;
	#([[:space:]])@([a-zA-Z])+([a-zA-Z0-9_-])*([[:space:]])@(';')*([[:space:]])
	@("alter table "|"ALTER TABLE ")* )
		do_alter_table "$user_cmd"
		;;
	@("describe table "|"DESCRIBE TABLE ")* )
		do_describe_table "$user_cmd"
		;;
	#([[:space:]])@([a-zA-Z])+([a-zA-Z0-9_-])*([[:space:]])@(';')*([[:space:]])
	@("drop table "|"DROP TABLE ")* )
		do_drop_table "$user_cmd"
		;;
	@("show tables"|"SHOW TABLES")*([[:space:]])?(";")*([[:space:]]) )
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

	@("insert "*|"INSERT "*) )
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