# app-gw2wingman-uploader

As of 02/04/26 the official Wingman uploader now has a Linux version available on the beta version of the Wingman site.

Uploader for arcdps logs to gw2wingman. Exists as an alternative uploader for Linux people.

Designed to be "compatible" with the official Wingman Uploader. In so far that it uses the same directories and same ``.mem`` files to avoid re-uploads. This means you should be able to swap between the two, if you wanted to do that for some reason. One minor difference, when a log can't be parsed by Elite Insights this uploader will create a ``.err`` file instead of the ``.mem`` file; this will lead to the official uploader attempting to re-parse that log if you were switching between the two uploaders. If a log fails to upload repeatedly it will also have a ``.err`` file created for it.

If a ``.mem``/``.err`` file exists a log will be skipped without checking if it exists upstream. If the ``.mem``/``.err`` file for a log is deleted, the script will check if the log is already in Wingman and if not it will upload it.

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
ARCDPS_LOG_DIR="~/.local/share/Guild Wars 2/addons/arcdps/arcdps.cbtlogs"
WINGMAN_UPLOADED_DIR="~/.local/share/Guild Wars 2/addons/arcdps/.wingmanUploaded"

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

## Configuration

The uploader is configured by environment variables. Default options for the available env vars are set in both the ``docker-compose.yml`` file and the ``conf/installer.env`` file (for Docker and Linux usage respectively.) If you're running the script on an adhoc basis, I would recommend creating an ``.env`` file and sourcing it before running the script (you could also do this with the ``conf/installer.env`` file.)

### Environment variables

#### Uploader config

``ACCOUNT_NAME``: Your GW2 account name. This must be set, you're uploads may fail if this is incorrectly set.

``ARCDPS_LOG_DIR``: The arcdps log directory.

``WINGMAN_UPLOADED_DIR``: Directory to store .mem files. This can be anywhere you want but the official uploader uses ``.wingmanUploaded`` next to the executable (IIRC.)

``IGNORE_OLD_LOGS``: Skip processing "older" logs on successive startups. After the very first run a file will be created in ``WINGMAN_UPLOADED_DIR`` to track the end of the last run, any files older than this file will be ignored on future runs. If enabled some logs could end up not getting uploaded. Recommended to keep as "false" but if you keep a lot of logs you might find some benefit in setting to "true".

``RETRY_FAILED_UPLOADS``: Creates a background process that will attempt to re-parse & uplaod logs that failed to be uploaded. If disabled, the script will only retry when it's next started. Recommended to leave enabled unless you know that the Wingman API isn't working correctly.

``RETRY_FREQUENCY``: If ``RETRY_FAILED_UPLOADS`` is true, this is the frequency at which ``.retry`` files will be checked for in seconds.

``MAX_RETRIES``: Maximum number of times to retry an upload. Some logs will repeatedly fail (or Wingman may claim they failed when they actually succeeded) this will prevent the uploader from retrying them repeatedly. Set to ``-1`` for infinite.

#### Installer script config

``CREATE_SYSTEMD_SERVICE``: If set to "false" the Systemd service won't be created at all. You will need to run the script yourself in whatever way you wish. One example for this: ``nohup /opt/scripts/wingman_uploader.sh &``.

``WINGMAN_SERVICE_ENABLED``: If enabled the Systemd service will be automatically enabled, this will make the service start automatically with your machine. If disabled, you will need to start/stop the service manually when required. This can be done with ``systemctl start/stop wingman-uploader``.
