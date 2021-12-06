# DarkflameServerInstallScript
A shell script that installs DarkflameServer locally

## Before you use
Make sure that nothing is binding the ports for mysql.

I highly suggest making a sql user instead of using root. You can do this by running these commands:
```sql
create user 'USERNAME'@'localhost' identified by 'PASSWORD';
grant all privilages on *.* to 'USERNAME'@'localhost';
```

This user will be the same user that is the "sqlUsername" below.

## Usage
simply download [install_darkflame.sh](install_darkflame.sh) from this repository and run it with super-user privilages.

```shell
wget https://raw.githubusercontent.com/Drahsid/DarkflameServerInstallScript/master/install_darkflame.sh

sudo chmod +x ./install_darkflame.sh

sudo ./install_darkflame.sh /path/to/res/folder
```

Note that you can provide additional arguments for further control of the installation process. If you don't provide these arguments, the script will ask you for them.

```
sudo ./install_darkflame.sh /path/to/res/folder sqlUsername databaseName path/to/install/server
```

### Additional Contributors
DLU Team - DLU
Lass11 - Testing
