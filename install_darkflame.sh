#!/bin/bash

RED='\033[0;31m'
PURPLE='\033[0;35m'
NOCOLOR='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root!${NOCOLOR}"
    exit 1
fi

# $1 resource dir $2 sql user $3 database name $4 server dir $5 build dir

if [ -z $1 ]; then
    read -p 'please input the path to the res folder: ' -n 1 -r
    resDir=$(realpath $REPLY)
    if [ -z $resDir ]; then
        echo -e "${RED}ERROR! YOU MUST PROVIDE THE RESOURCE DIRECTORY!${NOCOLOR}"
        exit 1
    fi
fi
resDir=$(realpath $1)
echo -e "${PURPLE}using resource dir $resDir${NOCOLOR}"

if [ -z $2 ]; then
    read -p 'sql user not provided, would you like to provide one? if no, default will be root. make sure this user exists! [y/n] ' -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        read -p 'input sql username now: ' -n 1 -r
        sqlUser=$REPLY
    else
        echo -e "${RED}no sql user defined, using root${NOCOLOR}"
        sqlUser=root
    fi
else
    sqlUser=$2
fi
echo -e "${PURPLE}using sql user $2${NOCOLOR}"

if [ -z $3 ]; then
    read -p 'database name not provided, would you like to provdie one? if no, default will be dlu [y/n] ' -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        read -p 'input database name now: ' -n 1 -r
        databaseName=$REPLY
    else
        echo -e "${RED}no database name defined, using dlu${NOCOLOR}"
        databaseName=dlu
    fi
else
    databaseName=$3
fi
echo -e "${PURPLE}using database name $databaseName${NOCOLOR}"

if [ -z $4 ]; then
    read -p 'server files dir not provided, would you like to provide one? if no, default will be . [y/n] ' -n 1 -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        read -p 'input server files dir: ' -n 1 -r
        serverDir = $(realpath $REPLY)
    else
        serverDir=$(realpath .)
        echo -e "${RED}no server dir defined, using ${serverDir}${NOCOLOR}"
    fi
else
    serverDir=$(realpath $4)
fi
serverDir=$(realpath $serverDir)
echo -e "${PURPLE}using server dir $serverDir${NOCOLOR}"

usingBuildDir=0
if [ -z $5 ]; then
    read -p 'if you have already built the server files, put the path to them here (otherwise leave this blank): '
    if [ -z $REPLY ]; then
        buildDir=$serverDir/build
    else
        buildDir=$REPLY
        usingBuildDir=1
    fi
else
    buildDir=$5
    usingBuildDir=1
fi
echo -e "${PURPLE}using build dir $buildDir${NOCOLOR}"

echo -e "${PURPLE}installing required packages...${NOCOLOR}"
apt update
apt install gcc cmake build-essential zlib1g-dev python3 python3-pip unzip sqlite3

read -p 'do you want to install mysql and mariadb? (you can choose N if you have already installed these!) [y/n] ' -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    # potentially problematic
    if [ apt install mariadb-server ]; then
        echo -e "${NOCOLOR}"
    else
        read -p 'installing mariadb-server failed, would you like CLEAN install them? (may be dangerous if you already have either set up and in-use.) If you select no, we will install mariadb-server-10.3 instead. [y/n] ' -n 1 -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            apt clean
            apt purge 'mysql*'
            apt purge 'mariadb*'
            apt update
            apt install -f
            if [ apt install mariadb-server ]; then
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
fi

if [ $usingBuildDir -eq "0" ]; then
    echo -e "${PURPLE}cloning repository...${NOCOLOR}"
    git clone https://github.com/DarkflameUniverse/DarkflameServer.git --recursive $serverDir
else
    echo -e "${PURPLE}using server build files $buildDir${NOCOLOR}"
fi

cd $serverDir
mkdir -p $buildDir
cd $buildDir

echo -e "${PURPLE}building server...${NOCOLOR}"
cmake ..  && make -j4

echo -e "${PURPLE}setting up mysql database${NOCOLOR}"
mysql -u $sqlUser -e "drop database $databaseName";
mysql -u $sqlUser -e "create database $databaseName";
mariadb $databaseName < $serverDir/migrations/dlu/0_initial.sql;

echo -e "${PURPLE}setting up resource folder${NOCOLOR}"
rm -rf $buildDir/res
ln -s $resDir $buildDir/

echo -e "${PURPLE}setting up navmeshes${NOCOLOR}"
mkdir $buildDir/res/maps/navmeshes
unzip $serverDir/resources/navmeshes.zip -d $buildDir/res/maps/navmeshes

echo -e "${PURPLE}setting up locale${NOCOLOR}"
rm -rf $buildDir/locale
ln -s $buildDir/res/locale $buildDir/

echo -e "${PURPLE}setting up CDServer.sqlite${NOCOLOR}"
git clone https://github.com/lcdr/utils.git $serverDir/lcdrutils
python3 $serverDir/lcdrutils/utils/fdb_to_sqlite.py $buildDir/res/cdclient.fdb --sqlite_path $buildDir/res/CDServer.sqlite

sqlite3 $buildDir/res/CDServer.sqlite ".read $serverDir/migrations/cdserver/0_nt_footrace.sql"
sqlite3 $buildDir/res/CDServer.sqlite ".read $serverDir/migrations/cdserver/1_fix_overbuild_mission.sql"
sqlite3 $buildDir/res/CDServer.sqlite ".read $serverDir/migrations/cdserver/2_script_component.sql"

echo -e "${PURPLE}setting up configs (If your sql user has a password, make sure to edit the files and input the password after \`mysql_password=\`)${NOCOLOR}"
sed -i "s/mysql_host=/mysql_host=localhost/g" $buildDir/authconfig.ini
sed -i "s/mysql_database=/mysql_database=$databaseName/g" $buildDir/authconfig.ini
sed -i "s/mysql_username=/mysql_username=$sqlUser/g" $buildDir/authconfig.ini

sed -i "s/mysql_host=/mysql_host=localhost/g" $buildDir/chatconfig.ini
sed -i "s/mysql_database=/mysql_database=$databaseName/g" $buildDir/chatconfig.ini
sed -i "s/mysql_username=/mysql_username=$sqlUser/g" $buildDir/chatconfig.ini

sed -i "s/mysql_host=/mysql_host=localhost/g" $buildDir/masterconfig.ini
sed -i "s/mysql_database=/mysql_database=$databaseName/g" $buildDir/masterconfig.ini
sed -i "s/mysql_username=/mysql_username=$sqlUser/g" $buildDir/masterconfig.ini

sed -i "s/mysql_host=/mysql_host=localhost/g" $buildDir/worldconfig.ini
sed -i "s/mysql_database=/mysql_database=$databaseName/g" $buildDir/worldconfig.ini
sed -i "s/mysql_username=/mysql_username=$sqlUser/g" $buildDir/worldconfig.ini

