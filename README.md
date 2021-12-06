# DarkflameServerInstallScript
A shell script that installs DarkflameServer.

## Usage
simply download [install_darkflame.sh](install_darkflame.sh) from this repository and run it with super-user privilages.

```shell
wget https://raw.githubusercontent.com/Drahsid/DarkflameServerInstallScript/master/install_darkflame.sh

sudo chmod +x ./install_darkflame.sh

sudo ./install_darkflame.sh /path/to/res/folder
```

Note that you can provide additional arguments for further control of the installation process.

```
sudo ./install_darkflame.sh /path/to/res/folder sqlUsername databaseName path/to/install/server
```

