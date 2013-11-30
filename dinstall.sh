#!/bin/bash

##   VERSION: 0.1
#######################################################################
# NOTES
# The user running this script must be able to write to the vhost file!
#
#######################################################################

##### CONFIGURABLE DEFAULTS
# Set the location of the file that holds the template vhost configuration
vhost_template=/var/www/scripts/dinstall/vhost.txt
# Set the location of where vhost records are stored on the system
vhost_file=/etc/httpd/vhosts.d/sites.conf


##########################################################################################
###############   YOU SHOULD NOT NEED TO EDIT ANYTHING BELOW THIS LINE!!   ###############
##########################################################################################

##### DEFAULTS
display_help=0
user_dest=0
all_defaults=0
no_vhost=0
db_user=root
db_root_pass=blue5.houses
db_pass=blue5.houses
db_loc=localhost
drush_makefile=/var/www/drush-makefiles/bedrock_make/bedrock.make
drupal_dest=.
site_acct=admin
site_pass=Jd4ms!


##### PARSE ARGUMENTS
while [ "$1" != "" ]; do
  case $1 in
    -h | --help )
      display_help=1
      ;;
    -dbn* | --dbname* )
      db_name=$(expr match "$1" '(?:-dbn|--dbname)=\(.*\)')
      ;;
    -dbu* | --dbuser* )
      db_user=$(expr match "$1" '(?:-dbu|--dbuser)=\(.*\)')
      ;;
    -dbp* | --dbpass* )
      db_user=$(expr match "$1" '(?:-dbp|--dbpass)=\(.*\)')
      ;;
    -dm* | --drushmake* )
      drush_makefile=$(expr match "$1" '(?:-dm|--drushmake)="{0,1}\(.*\)"{0,1}')
      ;;
    -dest* | --destination* )
      drupal_dest=$(expr match "$1" '(?:-dest|--destination)="{0,1}\(.*\)"{0,1}')
      user_dest=1
      ;;
    -sn* | --site-name* )
      site_name=$(expr match "$1" '(?:-sn|--site-name)="{0,1}\(.*\)"{0,1}')
      ;;
    -sa* | --site-acct* )
      site_acct=$(expr match "$1" '(?:-sa|--site-acct)=\(.*\)')
      ;;
    -sp* | --site-pass* )
      site_pass=$(expr match "$1" '(?:-sp|--site-pass)=\(.*\)')
      ;;
    -nv | --no-vhost )
      no_vhost=1
      ;;
    -d | --defaults )
      all_defaults=1
      ;;
  esac
  shift
done


##### FUNCTIONS
function check_database_exists
{
  # Assign our test for the given database to a variable
  database_present=$(mysql -uroot -p${db_root_pass} -e "show databases like '$db_name'")
  if [[ $database_present ]]; then
    echo "ERROR: A database with the name $db_name already exists."
    # Prompt for a new database name and assign it to the same variable
    db_name=
    while [[ $db_name = "" ]]; do
      read -p "Enter a new database name: " db_name
    done
    # Re-run this function to test the newly given database name
    check_database_exists
  fi
}

function check_database_user_exists
{
  user_present=$(mysql -uroot -p${db_root_pass} -e "use mysql; SELECT user FROM user WHERE user='$db_user';")
  if [[ $user_present ]]; then
    read -p "The user $db_user already exists in the database. Continue using this user? (y/n) " yn
    case $yn in
      [!yY] )
        db_user=
        while [[ $db_user = "" ]]; do
          read -p "Name of database user to create: " db_user
        done
        # Re-run this function to test the newly given user
        check_database_user_exists
        ;;
    esac;
  fi
}

function create_database
{
  sql="CREATE DATABASE IF NOT EXISTS $db_name; GRANT ALL ON $db_name.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_pass'; FLUSH PRIVILEGES;"
  $(which mysql) -uroot -p${db_root_pass} -e "$sql"
}

function drupal_download
{
  echo '*********************************'
  echo 'Drupal is now being downloaded...'
  $(drush make $drush_makefile $drupal_dest)
}

function drupal_install
{
  echo '********************************'
  echo 'Drupal is now being installed...'
  $(drush site-install $drush_makefile --db-url=mysql://$db_user:$db_pass@localhost/$db_name --site-name="$site_name" --account-name=$site_acct --account-pass=$site_pass)
}

function create_vhost
{
  # Create vhost as long as user did not say not to
  if [ "$no_vhost" == "0" ]; then
    # Get the drupal_dest, if it's the current directory (.) we need to get the actual path for vhost_template
    # We don't do this check in confirming that the user wants to install Drupal in the current directory because
    # if we are not going to create a vhost then getting the actual directory isn't necessary
    if [ "$drupal_dest" == '.' ]; then
      drupal_dest=$(pwd)
    fi

    # Get the contents of our vhost template file and assign it to a variable
    vhost_value=$(<$vhost_template)
    # Replace the first instance (there should only be one anyway) of {{DIRECTORY}} in the variable
    vhost_value="${vhost_value/\{\{DIRECTORY\}\}/$drupal_dest}"
    # Replace ALL instances of {{URL}} in the variable
    # NOTE: The double forward slash (//) in the line below dictates that we want to replace ALL occurances
    #       A single forward slash (/) like in the line above dictates that we want to replace only the first occurance
    vhost_value="${vhost_value//\{\{URL\}\}/$domain_name}"

    echo "The vhost record is now being recorded..."
    echo "$vhost_value" >>$vhost_file
    # su -c'service httpd restart'
  fi 
}

function display_help
{
  echo "This will eventually display help text ... yay!"
  exit;
}


# CHECK IF HELP IS REQUESTED FIRST THING SO THAT NOTHING ELSE GETS PROCESSED
if [ "$display_help" == "1" ]; then
  display_help
fi

# GATHER INFORMATION FROM THE USER

# If a --dbname parameter was not passed we need to ask for the name of the database to create
if [ "$db_name" == "" ]; then
  db_name=
  while [[ $db_name = "" ]]; do
    read -p "Name of database to create: " db_name
  done
fi
# Check the name of the database so that if the database already exists we don't go any further
check_database_exists

# Check to make sure that the user wants to use the root database user
if [ "$db_user" == "root" ]; then
  read -p "You are going to use the root database user for this site. Are you sure? (y/n) " yn
  case $yn in
    [!yY] )
      db_user=
      while [[ $db_user = "" ]]; do
        read -p "Name of database user: " db_user
      done
      check_database_user_exists
      ;;
  esac;
fi


# We need to check to see if the db_user was passed in.
# If so, we need to make sure that a password was sent in as well.
if [ "$db_user" != 'root' ]; then
  db_pass=
  while [[ $db_pass = "" ]]; do
    read -p "Password for database user $db_user: " db_pass
  done
fi


# Check for proper settings for drush make
### If drupal_dest equals the current directory (.)
### AND the user has not declared a path using --dest
### AND the user didn't set the --defaults flag to use all defaults
if [ "$drupal_dest" == '.' ] && [ "$user_dest" == "0" ] && [ "$all_defaults" == "0" ]; then
  read -p "You are going to install Drupal in the current directory. Are you sure? (y/n) " yn
  case $yn in
    [!yY] )
      drupal_dest=
      while [[ $drupal_dest = "" ]]; do
        read -p "Enter the full path of where to install Drupal: " drupal_dest
      done
      ;;
  esac;
fi


# Items to handle before we can run drush site-install
if [ "$site_name" == "" ]; then
  site_name=
  while [[ $site_name = "" ]]; do
    read -p "Enter the human-readable name for this site: " site_name
  done
fi


# Items to handle before we can setup a vhost record
# Ask for the domain name as long as we are supposed to be setting up a vhost
if [ "$no_vhost" == "0" ]; then
  # Prompt the user for the domain to use for the site
  domain_name=
  while [[ $domain_name = "" ]]; do
    read -p "Enter the domain name (WITHOUT TLD) for this site: " domain_name
  done
fi


##########################


# # CREATE A DATABASE
# create_database
# # RUN DRUSH MAKE
# drupal_download
# # INSTALL DRUPAL
# drupal_install
# CREATE VHOST RECORD
create_vhost