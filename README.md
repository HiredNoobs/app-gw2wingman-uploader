# app-gw2wingman-uploader

Uploader for arcdps logs to gw2wingman. Exists as an alternative uploader for Linux people.

Designed to be "compatible" with the official Wingman Uploader. In so far that it uses the same directories and same ``.mem`` files to avoid re-uploads. This means you should be able to swap between the two, if you wanted to do that for some reason.

The script does two things. The first, on start up, is checking all of the existing log files and uploading any that aren't already in wingman. The second is waiting for new files to appear in your log directory and uploading them immediately.

Depending on the number of logs you keep locally, the first run can take a few minutes. Once it has run once it will generate a ``.lastscan`` file, which is used by future runs to avoid wasting time checking old files. If you need to force the checking of older files, the easiest way is to delete this file and re-run the script.

If a ``.mem`` file exists a log will be skipped without checking if it exists upstream. If the ``.mem`` file for a log are deleted, the script will check if the log is already in Wingman and if not it will upload it.

## Usage

Install git, clone this repo, and cd into it:

```bash
# Debian based
$ apt-get update
$ apt-get install git

# Arch based
$ pacman -S git

# Clone the repo
$ git clone https://github.com/hirednoobs/app-gw2wingman-uploader.git
$ cd app-gw2wingman-uploader
```

Now follow the steps in the section relevant to how you want to use the uploader.

### Docker

Create a ``.env`` file at the top level of this repo (i.e. next to the docker-compose.yml file.) with the following vars:

```bash
ACCOUNT_NAME=YourGW2AccountName.1234

# For Linux:
ARCDPS_LOG_DIR=/path/on/host/arcdps.cbtlogs
WINGMAN_UPLOADED_DIR=/path/on/host/.wingmanUploaded

# For Windows:
ARCDPS_LOG_DIR="C:\\Users\\USERNAME\\Documents\\Guild Wars 2\\addons\\arcdps\\arcdps.cbtlogs"
WINGMAN_UPLOADED_DIR="C:\\Users\\USERNAME\\Documents\\Guild Wars 2\\addons\\arcdps\\.wingmanUploaded"
```

Then run ``docker compose up -d``. Optionally, use ``docker compose up --build -d`` to force a re-build (if you've updated the Elite Insights version for example.)

### Linux

The script can be setup and run on an adhoc basis fairly easily, but for convenience there is an installer script that sets everything up as a systemd service.

Populate ``./conf/installer.env``.

To install/update use ``./src/install_uploader.sh`` for Debian or Arch based distros.

To uninstall use ``./src/uninstall_uploader.sh``. Dependencies will be left alone to avoid breaking anything - check the install script for the list of installed packages if you want to clean them up.
