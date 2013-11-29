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
site_acct=admin
site_pass=Jd4ms!


##### FUNCTIONS
function check_database_exists
{
  # Assign our test for the given database to a variable
  database_present=`mysql -uroot -p${db_root_pass} -e "show databases like '$db_name'"`
  if [[ $database_present ]];
    then
    echo "ERROR: A database with the name $db_name already exists."
    # Prompt for a new database name and assign it to the same variable
    read -p "Enter a new database name: " db_name
    # Re-run this function to test the newly given database name
    check_database_exists
    # exit;
  fi
}

function create_database
{
  sql="CREATE DATABASE IF NOT EXISTS $db_name; GRANT ALL ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass'; FLUSH PRIVILEGES;"
  `which mysql` -uroot -p${db_root_pass} -e "$sql"
}

function drupal_download
{
  echo '*********************************'
  echo 'Drupal is now being downloaded...'
  `drush make $drush_makefile $drupal_dest`
}

function drupal_install
{
  echo '********************************'
  echo 'Drupal is now being installed...'
  `drush site-install $drush_makefile --db-url=mysql://$db_user:$db_pass@localhost/$db_name --site-name="$site_name" --account-name=$site_acct --account-pass=$site_pass`
}


##### PARSE ARGUMENTS
while [ "$1" != "" ]; do
  case $1 in
    -dbn | --dbname* )
      db_name=`expr match "$1" '(?:-dbn|--dbname)=\(.*\)'`
      ;;
    -dbu | --dbuser* )
      db_user=`expr match "$1" '(?:-dbu|--dbuser)=\(.*\)'`
      ;;
    -dbp | --dbpass* )
      db_user=`expr match "$1" '(?:-dbp|--dbpass)=\(.*\)'`
      ;;
    -dm | --drushmake* )
      drush_makefile=`expr match "$1" '(?:-dm|--drushmake)="{0,1}\(.*\)"{0,1}'`
      ;;
    -dest | --destination* )
      drupal_dest=`expr match "$1" '(?:-dest|--destination)="{0,1}\(.*\)"{0,1}'`
      user_dest=1
      ;;
    -sn | --site-name* )
      site_name=`expr match "$1" '(?:-sn|--site-name)="{0,1}\(.*\)"{0,1}'`
      ;;
    -sa | --site-acct* )
      site_acct=`expr match "$1" '(?:-sa|--site-acct)=\(.*\)'`
      ;;
    -sp | --site-pass* )
      site_pass=`expr match "$1" '(?:-sp|--site-pass)=\(.*\)'`
      ;;
    -d | --defaults )
      all_defaults=1
      ;;
  esac
  shift
done


# GATHER INFORMATION FROM THE USER

# If a --dbname parameter was not passed we need to ask for the name of the database to create
if [ "$db_name" == "" ]
  then
  read -p "Name of database to create: " db_name
fi
# Check the name of the database so that if the database already exists we don't go any further
check_database_exists

# We need to check to see if the db_user was passed in.
# If so, we need to make sure that a password was sent in as well.
if [ "$db_user" != 'root' ]
  then
    db_pass=
    while [[ $db_pass = "" ]]; do
      read -p "Password for database user $db_user: " db_pass
    done
fi


# Check for proper settings for drush make
### If drupal_dest equals the current directory (.)
### AND the user has not declared a path using --dest
### AND the user didn't set the --defaults flag to use all defaults
if [ "$drupal_dest" == '.' ] && [ "$user_dest" == "0" ] && [ "$all_defaults" == "0" ]
  then
  read -p "You are going to install Drupal in the current directory. Are you sure? (y/n) " yn
  case $yn in
    [!yY] )
      read -p "Directory to install Drupal: " drupal_dest
      ;;
  esac;
fi


# Items to handle before we can run drush site-install
if [ "$site_name" == "" ];
  then
  read -p "Enter the human-readable name for this site: " site_name
fi

##########################


# CREATE A DATABASE WITH THE GIVEN INFORMATION
create_database
# RUN DRUSH MAKE WITH THE GIVEN INFORMATION
drupal_download
# INSTALL DRUPAL WITH THE GIVEN INFORMATION
drupal_install