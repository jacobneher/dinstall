#!/bin/bash

##   VERSION: 0.1

##### DEFAULTS
user_dest=0
all_defaults=0

db_user=root
db_root_pass=blue5.houses
db_pass=blue5.houses
db_loc=localhost
drush_makefile=/var/www/drush-makefiles/bedrock_make/bedrock.make
drupal_dest=.

##### FUNCTIONS
function create_database
{
  # First, check to see if the given db name already exists...
  if mysql -uroot -p${db_root_pass} -e "use $db_name";
    then
    echo "A database with the name $db_name already exists. Exiting..."
    exit;
  fi

  sql="CREATE DATABASE IF NOT EXISTS $db_name; GRANT ALL ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass'; FLUSH PRIVILEGES;"
  `which mysql` -uroot -p${db_root_pass} -e "$sql"
}

function drupal_download
{
  `drush make $drush_makefile $drupal_dest`
}



##### PARSE ARGUMENTS
while [ "$1" != "" ]; do
  case $1 in
    --dbname* )
      db_name=`expr match "$1" '--dbname=\(.*\)'`
      ;;
    --dbuser* )
      db_user=`expr match "$1" '--dbuser=\(.*\)'`
      ;;
    --drushmake* )
      drush_makefile=`expr match "$1" '--drushmake=\(.*\)'`
      ;;
    --dest* )
      drupal_dest=`expr match "$1" '--dest=\(.*\)'`
      user_dest=1
      ;;
    -d | --defaults )
      all_defaults=1
      ;;
  esac
  shift
done



# If a --dbname parameter was not passed we need to ask for the name of the database to create
if [ "$db_name" == "" ]
  then
  read -p "Name of database to create: " db_name
fi

# We need to check to see if the db_user was passed in.
# If so, we need to make sure that a password was sent in as well.
if [ "$db_user" != 'root' ]
  then
    db_pass=
    while [[ $db_pass = "" ]]; do
      read -p "Password for database user $db_user: " db_pass
    done
fi
# CREATE A DATABASE WITH THE GIVEN INFORMATION
create_database



# Check for proper settings for drush make
### If drupal_dest equals the current directory (.)
### AND the user has not declared a path using --dest
### AND the user didn't set the --defaults flag to use all defaults
if [ "$drupal_dest" == '.' ] && [ "$user_dest" == "0" ] && [ "$all_defaults" == "0" ]
  then
  read -p "You are going to install Drupal in the current directory. Are you sure? " yn
  case $yn in
    [!yY] )
      read -p "Directory to install Drupal: " drupal_dest
      ;;
  esac;
fi
# RUN DRUSH MAKE WITH THE GIVEN INFORMATION
drupal_download



