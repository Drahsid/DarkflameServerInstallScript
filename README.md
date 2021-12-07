# DarkflameServerInstallScript
A shell script that installs DarkflameServer locally

## Before you use
Make sure that nothing is binding the ports for mysql.

I highly suggest making a sql user instead of using root. If you already have mysql installed, you can simply run:
```sql
create user 'USERNAME'@'localhost' identified by 'PASSWORD';
grant all privilages on *.* to 'USERNAME'@'localhost';
```

otherwise, you will be promted to create the user during the mysql installation in the script.

## Usage
simply download [install_darkflame.sh](install_darkflame.sh) from this repository and run it with super-user privilages.
```shell
wget https://raw.githubusercontent.com/Drahsid/DarkflameServerInstallScript/master/install_darkflame.sh
sudo chmod +x ./install_darkflame.sh
sudo ./install_darkflame.sh
```

or as one command
```shell
wget https://raw.githubusercontent.com/Drahsid/DarkflameServerInstallScript/master/install_darkflame.sh && sudo chmod +x ./install_darkflame.sh && sudo ./install_darkflame.sh
```

Note that you can provide additional arguments for further automation of the installation process. If you don't provide these, the script will ask you for what it needs.

```
sudo ./install_darkflame.sh /path/to/res/folder sqlUsername databaseName path/to/download/server path/to/build/server
```

### Additional Contributors
DLU Team - DLU
Lass11 - Testing
