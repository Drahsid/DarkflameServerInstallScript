#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
PURPLE='\033[0;35m'
NOCOLOR='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}this script must be run as root!${NOCOLOR}"
    exit 1
fi

# $1 resource dir $2 sql user $3 database name $4 server dir $5 build dir

if [ -z $1 ]; then
    read -p "please input the path to the res folder$(echo \n)this directory should be the the folder titles res in the client: " -r
    resDir=${REPLY}
    if [ -z ${resDir} ]; then
        echo -e "${RED}ERROR! YOU MUST PROVIDE THE RESOURCE DIRECTORY!${NOCOLOR}"
        exit 1
    fi
else
    resDir=$1
fi
resDir=$(realpath ${resDir})
echo -e "${PURPLE}using resource dir ${GREEN}${resDir}${NOCOLOR}\n"

if [ -z $2 ]; then
    read -p "sql user not provided, would you like to provide one? if no, default will be $(echo -e ${GREEN}root${NOCOLOR}). make sure this user exists! [y/n] " -n 1 -r
    if [[ ! ${REPLY} =~ ^[Nn]$ ]]; then
        echo \n
        read -p 'input sql username now: ' -r
        sqlUser=${REPLY}
    else
        echo -e "\n${RED}no sql user defined, using ${GREEN}root${NOCOLOR}"
        sqlUser=root
    fi
else
    sqlUser=$2
fi
echo -e "${PURPLE}using sql user ${GREEN}${sqlUser}${NOCOLOR}\n"

if [ -z $3 ]; then
    read -p "database name not provided, would you like to provdie one? if no, default will be $(echo -e ${GREEN}dlu${NOCOLOR}) [y/n] " -n 1 -r
    if [[ ! ${REPLY} =~ ^[Nn]$ ]]; then
        read -p '\ninput database name now: ' -r
        databaseName=${REPLY}
    else
        echo -e "\n${RED}no database name defined, using ${GREEN}dlu${NOCOLOR}"
        databaseName=dlu
    fi
else
    databaseName=$3
fi
echo -e "${PURPLE}using database name ${GREEN}${databaseName}${NOCOLOR}\n"

if [ -z $4 ]; then
    read -p "server files dir not provided, would you like to provide one? if no, default will be $(echo -e ${GREEN}.${NOCOLOR})$(echo \n)this directory is the one which contains the files that are used to build the server. [y/n] " -n 1 -r
    if [[ ! ${REPLY} =~ ^[Nn]$ ]]; then
        echo \n
        read -p 'input server files dir: ' -r
        mkdir -p ${REPLY} # premake dir
        serverDir=${REPLY}
    else
        serverDir=.
        echo -e "\n${RED}no server dir defined, using ${GREEN}${serverDir}${NOCOLOR}"
    fi
else
    serverDir=$4
fi
serverDir=$(realpath ${serverDir})
echo -e "${PURPLE}using server dir ${GREEN}${serverDir}${NOCOLOR}\n"

usingBuildDir=0
if [ -z $5 ]; then
    read -p "if you have already built the server files, put the path to them here $(echo -e ${GREEN}\(otherwise leave this blank\)${NOCOLOR}): " -r

    if [ -z ${REPLY} ]; then
        buildDir=${serverDir}/build
    else
        buildDir=${REPLY}
        usingBuildDir=1
    fi
else
    buildDir=$5
    usingBuildDir=1
fi
echo -e "${PURPLE}using build dir ${GREEN}${buildDir}${NOCOLOR}\n"

echo -e "${PURPLE}installing required packages${NOCOLOR}\n"
apt update
apt install gcc cmake build-essential zlib1g-dev python3 python3-pip unzip sqlite3

read -p 'do you want to install mysql and mariadb? (you can choose N if you have already installed these!) [y/n] ' -n 1 -r
if [[ ! ${REPLY} =~ ^[Nn]$ ]]; then
    # potentially problematic
    if [ apt install mariadb-server ]; then
        echo -e "${NOCOLOR}"
    else
        read -p "installing mariadb-server failed, would you like CLEAN install them?$(echo \n)doing so may be dangerous if you already have either mysql or mariadb set up and in-use, this purges the relevant packages.\nif you select no, we will install mariadb-server-10.3 instead [y/n] " -n 1 -r
        if [[ ! ${REPLY} =~ ^[Nn]$ ]]; then
            apt clean
            apt purge 'mysql*'
            apt purge 'mariadb*'
            apt update
            apt install -f
            if [ apt install mariadb-server ]; then
                echo -e "${NOCOLOR}"
            else
                echo -e "${RED}warning: failed! falling back to mariadb-server-10.3 (this should be OK!)${NOCOLOR}"
                apt install mariadb-server-10.3
            fi
        else
            apt install mariadb-server-10.3
        fi
    fi

    echo -e "${PURPLE}setting up mysql${NOCOLOR}"
    service mysql start
    mysql_secure_installation
fi
echo \n

if [ ${usingBuildDir} -eq "0" ]; then
    echo -e "${PURPLE}cloning DarkflameServer repository${NOCOLOR}"
    git clone https://github.com/DarkflameUniverse/DarkflameServer.git --recursive ${serverDir}
else
    echo -e "${PURPLE}using server build files ${GREEN}${buildDir}${NOCOLOR}"
fi

cd ${serverDir}
mkdir -p ${buildDir}
cd ${buildDir}

echo -e "${PURPLE}building server${NOCOLOR}\n"
cmake ..  && make -j4

echo -e "${PURPLE}setting up mysql database${NOCOLOR}\n"

if [ "${sqlUser}" != "root" ]; then
    read -p "do you want to create the sqlUser ${sqlUser} now? (select N if you have already created the user!) [y/n] " -n 1 -r
    if [[ ! ${REPLY} =~ ^[Nn]$ ]]; then
        echo \n
        read -p "input desired password for sql user ${sqlUser}: " -r
        sqlUserPW=${REPLY}
        mysql -e "create user '${sqlUser}'@'localhost' identified by '${sqlUserPW}'";
        mysql -e "grant all privileges on *.* to '${sqlUser}'@'localhost'";
    fi
else
    echo -e ${RED}sqlUser is root, no need to create${NOCOLOR}
fi

mysql -e "drop database ${databaseName}"; # hopefully noone loses any data because of this
mysql -e "create database ${databaseName}";
mariadb ${databaseName} < ${serverDir}/migrations/dlu/0_initial.sql;

echo -e "${PURPLE}setting up resource folder${NOCOLOR}\n"
rm -rf ${buildDir}/res
ln -s ${resDir} ${buildDir}/

echo -e "${PURPLE}setting up navmeshes${NOCOLOR}\n"
mkdir ${buildDir}/res/maps/navmeshes
unzip ${serverDir}/resources/navmeshes.zip -d ${buildDir}/res/maps

echo -e "${PURPLE}setting up locale${NOCOLOR}\n"
rm -rf ${buildDir}/locale
ln -s ${resDir}/../locale ${buildDir}/

echo -e "${PURPLE}setting up CDServer.sqlite${NOCOLOR}\n"
git clone https://github.com/lcdr/utils.git ${serverDir}/lcdrutils
python3 ${serverDir}/lcdrutils/utils/fdb_to_sqlite.py ${buildDir}/res/cdclient.fdb --sqlite_path ${buildDir}/res/CDServer.sqlite

sqlite3 ${buildDir}/res/CDServer.sqlite ".read ${serverDir}/migrations/cdserver/0_nt_footrace.sql"
sqlite3 ${buildDir}/res/CDServer.sqlite ".read ${serverDir}/migrations/cdserver/1_fix_overbuild_mission.sql"
sqlite3 ${buildDir}/res/CDServer.sqlite ".read ${serverDir}/migrations/cdserver/2_script_component.sql"

echo -e "${PURPLE}setting up configs (If your sql user has a password, make sure to edit the files and input the password after \`mysql_password=\`)${NOCOLOR}\n"
sed -i "s/mysql_host=/mysql_host=localhost/g" ${buildDir}/authconfig.ini
sed -i "s/mysql_database=/mysql_database=${databaseName}/g" ${buildDir}/authconfig.ini
sed -i "s/mysql_username=/mysql_username=${sqlUser}/g" ${buildDir}/authconfig.ini

sed -i "s/mysql_host=/mysql_host=localhost/g" ${buildDir}/chatconfig.ini
sed -i "s/mysql_database=/mysql_database=${databaseName}/g" ${buildDir}/chatconfig.ini
sed -i "s/mysql_username=/mysql_username=${sqlUser}/g" ${buildDir}/chatconfig.ini

sed -i "s/mysql_host=/mysql_host=localhost/g" ${buildDir}/masterconfig.ini
sed -i "s/mysql_database=/mysql_database=${databaseName}/g" ${buildDir}/masterconfig.ini
sed -i "s/mysql_username=/mysql_username=${sqlUser}/g" ${buildDir}/masterconfig.ini

sed -i "s/mysql_host=/mysql_host=localhost/g" ${buildDir}/worldconfig.ini
sed -i "s/mysql_database=/mysql_database=${databaseName}/g" ${buildDir}/worldconfig.ini
sed -i "s/mysql_username=/mysql_username=${sqlUser}/g" ${buildDir}/worldconfig.ini

if [ -z ${sqlUserPW} ]; then
    echo -e "${RED}Since you did not create the sql user using this script, be sure to fill out its password in authconfig.ini chatconfig.ini masterconfig.ini worldconfig.ini!${NOCOLOR}"
else
    sed -i "s/mysql_password=/mysql_password=${sqlUserPW}/g" ${buildDir}/authconfig.ini
    sed -i "s/mysql_password=/mysql_password=${sqlUserPW}/g" ${buildDir}/chatconfig.ini
    sed -i "s/mysql_password=/mysql_password=${sqlUserPW}/g" ${buildDir}/masterconfig.ini
    sed -i "s/mysql_password=/mysql_password=${sqlUserPW}/g" ${buildDir}/worldconfig.ini
fi

echo -e "${PURPLE}Done! Should be OK!${NOCOLOR}\n"
echo -e "${PURPLE}You can make the admin account by navigating to ${buildDir} and running \`./MasterServer -a\`, and you can start the server by running \`./MasterServer\` in that same directory${NOCOLOR}\n"
echo -e "${PURPLE}If you want external connections, make sure to change the \`external_ip\` property in the ini files to be your front-facing domain or ip!${NOCOLOR}\n"
echo -e "${PURPLE}Consider chowning and chmoding the files in ${buildDir} so that you don't need to use sudo on everything${NOCOLOR}"
