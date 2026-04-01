# app-gw2wingman-uploader

Uploader for arcdps logs to gw2wingman.

## Usage

### Docker

Create a ``.env`` file at the top level of this repo (i.e. next to the docker-compose.yml file.) with the following vars:

```bash
ACCOUNT_NAME=YourGW2AccountName.1234

# For Linux:
HOST_ARCDPS_LOG_DIR=/path/on/host/arcdps.cbtlogs
HOST_WINGMAN_UPLOADED_DIR=/path/on/host/.wingmanUploaded

# For Windows:
HOST_ARCDPS_LOG_DIR="C:\\Users\\USERNAME\\Documents\\Guild Wars 2\\addons\\arcdps\\arcdps.cbtlogs"
HOST_WINGMAN_UPLOADED_DIR="C:\\Users\\USERNAME\\Documents\\Guild Wars 2\\addons\\arcdps\\.wingmanUploaded"
```

Then run ``docker-compose up -d``.
