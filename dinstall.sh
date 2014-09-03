#!/bin/bash

##   VERSION: 0.1

##### CONFIGURABLE DEFAULTS
# www root path
www_root=/var/www/html
# The location of the file that holds the template vhost configuration
vhost_template=/var/www/scripts/dinstall/vhost.txt
# The location of where vhost records are stored on the system
vhost_file=/etc/httpd/vhosts.d/sites.conf
# The location of the database (more than likely this will be localhost)
db_loc=localhost
# The root username for the database
db_root_user=root
# The root password for the database
db_root_pass=mysql
# The location of the drushmake file
drush_makefile="/Volumes/Home/Jacob/Web Development/Drush Makefiles/slate/slate.make"
# The name of the profile to use
profile_name=bedrock
# The default administration username to use for the Drupal site
site_admin_acct=admin
# The default administration password to use for the Drupal site
site_admin_pass=Jd4ms!


##########################################################################################
###############   YOU SHOULD NOT NEED TO EDIT ANYTHING BELOW THIS LINE!!   ###############
##########################################################################################

##### DEFAULTS
display_help=0
user_dest=0
all_defaults=0
drupal_dest=.


##### PARSE ARGUMENTS
# Make sure that an argument has been passed and it's not one that starts with - (i.e. -dbn or --dbname)
if [[ "$1" != "" ]] && [[ "${1:0:1}" != "-" ]]; then
  drupal_dest=${www_root}/${1}
  # We need to call shift so that we can get any other arguments sent in
  shift;
fi

while [ "$1" != "" ]; do
  case $1 in
    -h | --help )
      display_help=1
      ;;
    -dbn* | --dbname* )
      db_name=$(echo ${1}| cut -d'=' -f 2)
      ;;
    -dbu* | --dbuser* )
      db_user=$(echo ${1}| cut -d'=' -f 2)
      ;;
    -dbp* | --dbpass* )
      db_pass=$(echo ${1}| cut -d'=' -f 2)
      ;;
    -dm* | --drushmake* )
      drush_makefile=$(echo ${1}| cut -d'=' -f 2)
      ;;
    -sn* | --site-name* )
      site_name=$(echo ${1}| cut -d'=' -f 2)
      ;;
    -dom* | --domain* )
      domain_name=$(echo ${1}| cut -d'=' -f 2)
      ;;
    -sa* | --site-acct* )
      site_admin_acct=$(echo ${1}| cut -d'=' -f 2)
      ;;
    -sp* | --site-pass* )
      site_admin_pass=$(echo ${1}| cut -d'=' -f 2)
      ;;
    -nv | --no-vhost )
      create_vhost=0
      ;;
    -d | --defaults )
      all_defaults=1
      ;;
  esac;
  # We need to call shift so that we can get any other arguments sent in
  shift
done


##### FUNCTIONS
function color_coded_message() {
  normal=$(tput sgr0)
  if [[ "${2}" == "error" ]]; then
    status_color=$(tput setaf 1)
  elif [[ "${2}" == "warning" ]]; then
    status_color=$(tput setaf 3)
  else
    status_color=$(tput setaf 2)
  fi
  status_msg="${status_color}[${2}]${normal}"

  columns=$(tput cols)
  right_position=$(expr ${columns} - ${#1} + ${#2})
  printf "%s%${right_position}s\n" "$1" "$status_msg"
}

function check_database {
  # Assign our test for the given database to a variable
  database_present=$(mysql -u${db_root_user} -p${db_root_pass} -e "show databases like '$db_name'")
  # If there is already a database present with the given name, prompt the user for handling
  if [[ $database_present ]]; then
    color_coded_message "A database with the name '$db_name' already exists." "warning"
    read -p "You will be prompted to DROP the tables in the database later. Do you want to continue? (y/n) " yn
    case $yn in
      [!yY] )
        # Prompt for a new database name and assign it to the same variable
        db_name=
        while [[ $db_name = "" ]]; do
          read -p "Enter a new database name: " db_name
        done
        # Re-run this function to test the newly given database name
        check_database_exists
        ;;
    esac;
  fi
}

function database_password_prompt {
  read -p "Enter the password for user '$db_user': " db_pass
}

function check_database_user_password {

  # If the database password is blank then we need to immediately prompt for the user to enter the password
  if [[ "$db_pass" == "" ]]; then
    database_password_prompt
  fi

  # Check the given username and password (whether given when running the script or from the above prompt)
  # 2>/dev/null is added at the end so that no information is displayed to the user
  password_check=$(mysql -u$db_user -p$db_pass -e "show databases;" 2>/dev/null)
  # If the check above fails, then we need to tell the user and prompt them to enter the password again
  if [[ ! $password_check ]]; then
    color_coded_message "The password entered does not match the user." "error"
    database_password_prompt
    check_database_user_password
  fi
}

function check_database_user {
  # Check to see if the given database user already exists
  user_present=$(mysql -u${db_root_user} -p${db_root_pass} -e "use mysql; SELECT user FROM user WHERE user='$db_user';")
  if [[ $user_present != "" ]]; then
    # Prompt the user if the database user given already exists.
    read -p "The user $db_user already exists in the database. Do you want to continue? (y/n): " yn
    case $yn in
      [!yY] )
        db_user=
        while [[ $db_user = "" ]]; do
          read -p "Name of database user to create: " db_user
        done
        # Re-run this function to test the newly given user
        check_database_user
        ;;
      * )
        # Check the database password with the database user given
        check_database_user_password
    esac;
  else
    database_password_prompt
    echo "The database user '$db_user' has been created"
    # Create the database user with the name and password given
    $(mysql -u${db_root_user} -p${db_root_pass} -e "GRANT ALL PRIVILEGES ON ${db_name}.* TO ${db_user}@${db_loc} IDENTIFIED BY '${db_pass}'")
  fi
}

function pre_install_confirmation {
  # We want to print the real path that Drupal will be installed in if it is set to the current directory
  if [[ $drupal_dest == "." ]]; then
    display_drupal_dest=$(pwd);
  else
    display_drupal_dest=$drupal_dest
  fi

  echo ""
  echo "*******************************************************************"
  echo "Below are the settings that will be used to setup this installation"
  echo ""
  echo "DATABASE"
  echo "--------"
  echo "  User:     ${db_user}"
  echo "  Password: ${db_pass}"
  echo "  Location: ${db_loc}"
  echo ""
  echo "DRUPAL SITE"
  echo "-----------"
  echo "  Admin username: ${site_admin_acct}"
  echo "  Admin password: ${site_admin_pass}"
  echo "  Profile:        ${profile_name}"
  echo "  Site Name:      ${site_name}"
  echo ""
  echo "SYSTEM"
  echo "------"
  echo "  Path:     ${display_drupal_dest}"
  echo "  Makefile: ${drush_makefile}"
  echo ""
  echo "*******************************************************************"
  echo ""
  read -p "Do you want to continue the installation using these settings? (y/n) " yn

  case $yn in
    [!yY] )
      color_coded_message "The installation has aborted. No files or settings were altered!" "ok"
      exit;
      ;;
  esac;
}

function drupal_download {
  echo '*********************************'
  echo 'Drupal is now being downloaded...'
  $(drush make "$drush_makefile" "$drupal_dest")
}

function drupal_install {
  echo '********************************'
  echo 'Drupal is now being installed...'
  # We need to make sure that we are in the Drupal install directory
  cd ${drupal_dest}
  # For some reason using command substitution ($(...)) doesn't work here ... ??
  drush site-install $profile_name --db-url=mysql://$db_user:$db_pass@${db_loc}/$db_name --site-name="$site_name" --account-name=$site_admin_acct --account-pass=$site_admin_pass
}

function display_help {
  echo "This will eventually display help text ... yay!"
  exit;
}

function final_steps {
  # Make sure we are in the correct directory that Drupal was installed in
  cd ${drupal_dest}

  # For some reason the default permissions cause a 500 Internal Server Error
  # This is a quick fix until I find out if there is something setup wrong on my dev server
  $(find . -type f -exec chmod u=rw,g=r,o=r '{}' \;);
  $(find . -type d -exec chmod u=rwx,g=rx,o=rx '{}' \;)

  # For some reason drush site-install doesn't set the right username and password
  # so we are using this drush command to set it to what the user requested
  $(drush upwd ${site_admin_acct} --password=${site_admin_pass})
}

function post_install_confirmation {
  echo "************************************************************************"
  echo ""
  echo " You may now access your site!"
  echo ""
  echo "     Use this path when setting up AMPPS: $(pwd)"
  echo ""
  echo "     Username: ${site_admin_acct}"
  echo "     Password: ${site_admin_pass}"
  echo ""
  echo "****************************  JOSHUA 24:15  ****************************"
  echo ""
}



# CHECK IF HELP IS REQUESTED FIRST THING SO THAT NOTHING ELSE GETS PROCESSED
if [ "$display_help" == "1" ]; then
  display_help
fi



####################################
# GATHER INFORMATION FROM THE USER #
####################################

# If a --dbname parameter was not passed we need to ask for the name of the database to use
if [ "$db_name" == "" ]; then
  db_name=
  while [[ $db_name = "" ]]; do
    read -p "Name of database to use: " db_name
  done
fi
# Check to see if the database exists here so that we can prompt the user depending on the outcome
check_database

# If a db_user hasn't been set, then we will ask if the user wants to use root
if [ "$db_user" == "" ] || [ "$db_user" == "$db_root_user" ] && [ "$all_defaults" == "0" ]; then
  read -p "You are going to use the root database user for this site. Do you want to continue? (y/n): " yn
  case $yn in
    [!yY] )
      db_user=
      while [[ $db_user = "" ]]; do
        read -p "Name of database user: " db_user
      done
      check_database_user
      ;;
    * )
      # Set the user to the root user since we are going to be using the root user
      db_user=$db_root_user
      # and also set the password to the root password
      db_pass=$db_root_pass
  esac;
fi


# We need to make sure that we have a db_pass set
if [ "$db_pass" == "" ]; then
  db_pass=
  while [[ $db_pass = "" ]]; do
    read -p "Password for database user '$db_user': " db_pass
  done
fi


# Check for proper settings for drush make
### If drupal_dest equals the current directory (.)
### AND the user has not declared a path using --dest
### AND the user didn't set the --defaults flag to use all defaults
if [ "$drupal_dest" == '.' ] && [ "$user_dest" == "0" ] && [ "$all_defaults" == "0" ]; then
  read -p "You are going to install Drupal in the current directory. Do you want to continue? (y/n): " yn
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


###############################################

# CONFIRM SETTINGS GIVEN BY USER
pre_install_confirmation
# RUN DRUSH MAKE
drupal_download
# INSTALL DRUPAL
drupal_install
# FINAL STEPS TO GET EVERYTHING UP AND RUNNING!
final_steps
# DISPLAY USEFUL SETTINGS AFTER INSTALL
post_install_confirmation
