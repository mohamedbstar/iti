#!/usr/bin/bash


#make a nameed pipe for putting input into dbms
mkfifo dbms_input
#open the ./dbms.sh in the background and store its PID in a variable
./dbms.sh < dbms_input &

echo "drop database new;" > dbms_input
echo "use school"> dbms_input #for testing non-existing databases
echo "create database school;" > dbms_input
echo "use school;" > dbms_input
echo "create table student(s_id, s_name, age);" > dbms_input #testing missing field types
echo "create table student(s_id int pk, s_name string, age int);" > dbms_input
echo "create table course(c_id int pk, c_name string);" > dbms_input
echo "create table student_course_grade(s_id int, c_id int, grade int);" > dbms_input
echo "describe student;" > dbms_input
echo "describe course;" > dbms_input
echo "describe student_course_grade;" > dbms_input
echo "insert into student values(1,mohamed, 26);"> dbms_input
echo "insert into student values(1,mohamed, 26);"> dbms_input #for testing pk constraint
echo "insert into student values(2,hamada, 30);"> dbms_input
echo "insert into student values(3,ali, 40);"> dbms_input
echo "insert into student values(4,mostafa, 50);"> dbms_input
echo "insert into course values(1,linux);"> dbms_input 
echo "insert into course values(2,bash);"> dbms_input
echo "insert into course values(3,git);"> dbms_input
echo "insert into course values(7);" > dbms_input #test incomplete fields in insert
echo "insert into course values(mohamed, computer vision);" > dbms_input #test incompatible data type
echo "insert into course values(4,computer networks);"> dbms_input
echo "insert into student_course_grade values(1,1,100);"> dbms_input
echo "insert into student_course_grade values(1,2,100);"> dbms_input
echo "insert into student_course_grade values(1,3,100);"> dbms_input
echo "insert into student_course_grade values(1,4,100);"> dbms_input
echo "insert into student_course_grade values(2,1,40);"> dbms_input
echo "insert into student_course_grade values(2,2,50);"> dbms_input
echo "insert into student_course_grade values(2,3,50);"> dbms_input
echo "insert into student_course_grade values(2,4,70);"> dbms_input
echo "insert into student_course_grade values(3,1,90);"> dbms_input
echo "insert into student_course_grade values(3,2,96);"> dbms_input
echo "insert into student_course_grade values(3,3,80);"> dbms_input
echo "insert into student_course_grade values(3,4,85);"> dbms_input
echo "insert into student_course_grade values(4,1,70);"> dbms_input
echo "insert into student_course_grade values(4,2,70);"> dbms_input
echo "insert into student_course_grade values(4,3,91);"> dbms_input
echo "insert into student_course_grade values(4,4,89);"> dbms_input
echo "select * from student;"> dbms_input
echo "select * from student where id = 1;" > dbms_input #testing where caluse
echo "select name from student where id = 3;" > dbms_input
echo "select name from student where id = incompatible;" > dbms_input #test incompatible data type
echo "select name from student where non-existing-field = 3;" > dbms_input #test non-existing-field
echo "select non-existing-field from student where id = 3;" > dbms_input #test non-existing-field
echo "select c_name from course;"> dbms_input
echo "select non-existing-field from student_course_grade;"> dbms_input #testing selecting non-existing field

#test update
echo "update student set s_name = new_name where id = 1 ;"> dbms_input
echo "update student set s_name = another_name where id = 88;" > dbms_input #test non-existing student
#test delete

#=============================== Test Join operation ================================
echo "select student.name ,student.age, student_course_grade.grade from student join student_course_grade on student.id = student_course_grade.s_id;" > dbms_input

#============================== Test Aggregatino ====================================
#get maximum grade of students for each course
echo "select max(grade) from student_course_grade group by c_id;" > dbms_input
#get sum of grades of each student
echo "select sum(grade) from student_course_grade group bu s_id;" > dbms_input

rm dbms_input

dbms_pid=$!


#open many processes that runs ./dbms.sh and do insert in x table in new database