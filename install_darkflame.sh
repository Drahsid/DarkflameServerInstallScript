#!/bin/bash

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root!"
    exit 1
fi

# $1 resource dir $2 sql user $3 database name $4 server dir

if [ -z $1 ] ; then
    echo ERROR! YOU MUST PROVIDE THE RESOURCE DIRECTORY AS THE FIRST ARGUMENT!
    exit 1
fi
resDir=$1
echo using resource dir $resDir

if [ -z $2 ] ; then
    echo no sql user defined, using root
    sqlUser=root
else
    sqlUser=$2
fi
echo using sql user $2

if [ -z $3 ] ; then
    echo no database name defined, using dlu
    databaseName=dlu
else
    databaseName=$3
fi
echo using database name $databaseName

if [ -z $4 ] ; then
    echo no server dir defined, using .
    serverDir=.
else
    serverDir=$4
fi
echo using server dir $serverDir

echo installing required packages...
apt update
apt install gcc cmake build-essential zlib1g-dev python3 pip3 unzip
# potentially problematic
if apt install mysql-server mariadb-server ; then
else
    read -p 'installing mysql-server or mariadb-server failed, would you like CLEAN install them? (may be dangerous if you already have either set up and in-use.) If you select no, we will install mysql-server-8.0 mariadb-server-10.3 instead. [Y/n]' -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]] then
        apt clean
        apt purge 'mysql*'
        apt update
        apt install -f
        if apt install mysql-server mariadb-server ; then
        else
            echo failed! falling back to mysql-server-8.0 mariadb-server-10.3
            apt install mysql-server-8.0 mariadb-server-10.3
        fi
    else
        apt install mysql-server-8.0 mariadb-server-10.3
    fi

fi

echo setting up mysql...
mysql_secure_installation

echo cloning repository...
git clone https://github.com/DarkflameUniverse/DarkflameServer.git --recursive $serverDir

cd $serverDir
mkdir build
cd build

echo building server...
cmake ..  && make -j4

echo setting up mysql database
mysql -u $sqlUser -e "create database $databaseName";
mariadb $databaseName < $serverDir/migrations/dlu/0_initial.sql;

echo setting up resource folder
ln -s $resDir .

echo setting up navmeshes
mkdir ./res/maps/navmeshes
unzip ../resources/navmeshes.zip -d ./res/maps/navmeshes

echo setting up locale
mkdir locale
ln -s ./res/locale/locale.xml ./locale/locale.xml

echo setting up CDServer.sqlite
git clone https://github.com/lcdr/utils
python3 ./utils/fdb_to_sqlite.py ./res/cdclient.fdb --sqlite_path ./res/CDServer.sqlite

sqlite3 ./res/CDServer.sqlite ".read $serverDir/migrations/cdserver/0_nt_footrace.sql"
sqlite3 ./res/CDServer.sqlite ".read $serverDir/migrations/cdserver/1_fix_overbuild_mission.sql"
sqlite3 ./res/CDServer.sqlite ".read $serverDir/migrations/cdserver/2_script_component.sql"

echo setting up configs (If your sql user has a password, make sure to edit the files and input the password after `mysql_password=`)
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

