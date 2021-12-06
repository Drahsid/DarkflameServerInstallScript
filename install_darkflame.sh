#!/bin/bash

RED='\033[0;31m'
PURPLE='\033[0;35m'
NOCOLOR='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root!${NOCOLOR}"
    exit 1
fi

# $1 resource dir $2 sql user $3 database name $4 server dir $5 build dir

if [ -z $1 ] ; then
    echo -e "${RED}ERROR! YOU MUST PROVIDE THE RESOURCE DIRECTORY AS THE FIRST ARGUMENT!${NOCOLOR}"
    exit 1
fi
resDir=$(realpath $1)
echo -e "${PURPLE}using resource dir $resDir${NOCOLOR}"

if [ -z $2 ] ; then
    echo -e "${RED}no sql user defined, using root${NOCOLOR}"
    sqlUser=root
else
    sqlUser=$2
fi
echo -e "${PURPLE}using sql user $2${NOCOLOR}"

if [ -z $3 ] ; then
    echo -e "${RED}no database name defined, using dlu${NOCOLOR}"
    databaseName=dlu
else
    databaseName=$3
fi
echo -e "${PURPLE}using database name $databaseName${NOCOLOR}"

if [ -z $4 ] ; then
    serverDir=.
    echo -e "${RED}no server dir defined, using $serverDir${NOCOLOR}"
else
    serverDir=$4
fi
serverDir=$(realpath $serverDir)
echo -e "${PURPLE}using server dir $serverDir${NOCOLOR}"

echo -e "${PURPLE}installing required packages...${NOCOLOR}"
apt update
apt install gcc cmake build-essential zlib1g-dev python3 python3-pip unzip sqlite3
# potentially problematic
if [ apt install mariadb-server ] ; then
    echo -e "${NOCOLOR}"
else
    read -p 'installing mariadb-server failed, would you like CLEAN install them? (may be dangerous if you already have either set up and in-use.) If you select no, we will install mariadb-server-10.3 instead. [Y/n] ' -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]] ; then
        apt clean
        apt purge 'mysql*'
        apt purge 'mariadb*'
        apt update
        apt install -f
        if [ apt install mariadb-server ] ; then
            echo -e "${NOCOLOR}"
        else
            echo -e "${RED}failed! falling back to mariadb-server-10.3${NOCOLOR}"
            apt install mariadb-server-10.3
        fi
    else
        apt install mariadb-server-10.3
    fi

fi

echo -e "${PURPLE}setting up mysql...${NOCOLOR}"
service mysql start
mysql_secure_installation

if [ -z $5 ] ; then
    echo -e "${PURPLE}cloning repository...${NOCOLOR}"
    git clone https://github.com/DarkflameUniverse/DarkflameServer.git --recursive $serverDir
else
    echo -e "${PURPLE}copying prebuilt server files to $serverDir${NOCOLOR}"
    cp -r $5 $serverDir
fi

cd $serverDir
mkdir build
cd build

echo -e "${PURPLE}building server...${NOCOLOR}"
cmake ..  && make -j4

echo -e "${PURPLE}setting up mysql database${NOCOLOR}"
mysql -u $sqlUser -e "drop database $databaseName";
mysql -u $sqlUser -e "create database $databaseName";
mariadb $databaseName < $serverDir/migrations/dlu/0_initial.sql;

echo -e "${PURPLE}setting up resource folder${NOCOLOR}"
rm -rf $serverDir/build/
ln -s $resDir $serverDir/build/

echo -e "${PURPLE}setting up navmeshes${NOCOLOR}"
mkdir $serverDir/build/res/maps/navmeshes
unzip $serverDir/resources/navmeshes.zip -d $serverDir/build/res/maps/navmeshes

echo -e "${PURPLE}setting up locale${NOCOLOR}"
rm -rf $serverDir/build/locale
ln -s $serverDir/build/res/locale $serverDir/build/

echo -e "${PURPLE}setting up CDServer.sqlite${NOCOLOR}"
git clone https://github.com/lcdr/utils.git $serverDir/lcdrutils
python3 $serverDir/lcdrutils/utils/fdb_to_sqlite.py $serverDir/build/res/cdclient.fdb --sqlite_path $serverDir/build/res/CDServer.sqlite

sqlite3 $serverDir/build/res/CDServer.sqlite ".read $serverDir/migrations/cdserver/0_nt_footrace.sql"
sqlite3 $serverDir/build/res/CDServer.sqlite ".read $serverDir/migrations/cdserver/1_fix_overbuild_mission.sql"
sqlite3 $serverDir/build/res/CDServer.sqlite ".read $serverDir/migrations/cdserver/2_script_component.sql"

echo -e "${PURPLE}setting up configs (If your sql user has a password, make sure to edit the files and input the password after \`mysql_password=\`)${NOCOLOR}"
sed -i 's/mysql_host=/mysql_host=localhost/g' authconfig.ini
sed -i 's/mysql_database=/mysql_database=$databaseName/g' authconfig.ini
sed -i 's/mysql_username=/mysql_username=$sqlUser/g' authconfig.ini

sed -i 's/mysql_host=/mysql_host=localhost/g' chatconfig.ini
sed -i 's/mysql_database=/mysql_database=$databaseName/g' chatconfig.ini
sed -i 's/mysql_username=/mysql_username=$sqlUser/g' chatconfig.ini

sed -i 's/mysql_host=/mysql_host=localhost/g' masterconfig.ini
sed -i 's/mysql_database=/mysql_database=$databaseName/g' masterconfig.ini
sed -i 's/mysql_username=/mysql_username=$sqlUser/g' masterconfig.ini

sed -i 's/mysql_host=/mysql_host=localhost/g' worldconfig.ini
sed -i 's/mysql_database=/mysql_database=$databaseName/g' worldconfig.ini
sed -i 's/mysql_username=/mysql_username=$sqlUser/g' worldconfig.ini

