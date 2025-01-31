# Docker Restic Backup Automation

This Docker container automates backups using Restic, with support for scheduled backups and Docker container management during the backup process.

## Features

- Automated Restic backup execution
- Cron-based scheduling support
- Docker container stop/start management during backups
- Automatic Restic repository initialization
- Configurable retention policy

## Environment Variables

Required:
- `RESTIC_REPOSITORY`: The repository location where backups will be stored (e.g., "rclone:gdrive:/backup")
- `RESTIC_PASSWORD`: Password for the Restic repository

Optional:
- `BACKUP_CRON`: Cron expression for scheduling backups (e.g., "0 2 * * *" for daily at 2 AM)
- `PRUNE_CRON`: Cron expression for scheduling pruning operations
- `DOCKER_STOP_CONTAINERS`: Comma-separated list of container names to stop during backup
- `RESTIC_FORGET_ARGS`: Arguments for the `restic forget` command to manage retention (e.g., "--prune --keep-last 2")
- `RUN_ON_STARTUP`: Set to "true" to run backup immediately on container start
- `CHECK_CRON`: Cron expression for scheduling repository health checks
- `RESTIC_CHECK_ARGS`: Arguments for the `restic check` command (e.g., "--read-data")
- `TZ`: Timezone for the container (e.g., "Asia/Karachi")

## Usage

### Docker Compose

```yaml
version: '3.8'
services:
  backup:
    image: sync:latest
    environment:
      - TZ=Asia/Karachi  # Set your timezone
      - RESTIC_REPOSITORY=rclone:gdrive:/backup  # RClone-specific repository path
      - RESTIC_PASSWORD=your_password
      - BACKUP_CRON=0 2 * * *  # Run at 2 AM daily
      - PRUNE_CRON=0 3 * * *  # Run pruning at 3 AM daily
      - RESTIC_FORGET_ARGS=--prune --keep-last 2
      - RUN_ON_STARTUP=true  # Run backup when container starts
      - CHECK_CRON=0 4 * * *  # Run health check at 4 AM daily
      - RESTIC_CHECK_ARGS=--read-data
      - DOCKER_STOP_CONTAINERS=container1,container2
    volumes:
      - ./backup:/data/backup  # Mount backup source
      - ~/.config/rclone:/root/.config/rclone  # Required for RClone configuration
      - /var/run/docker.sock:/var/run/docker.sock  # Required for Docker control
```

### Direct Docker Run

```bash
docker run -d \
  -e TZ="Asia/Karachi" \
  -e RESTIC_REPOSITORY="rclone:gdrive:/backup" \
  -e RESTIC_PASSWORD="your-password" \
  -e BACKUP_CRON="0 2 * * *" \
  -e PRUNE_CRON="0 3 * * *" \
  -e RESTIC_FORGET_ARGS="--prune --keep-last 2" \
  -e RUN_ON_STARTUP="true" \
  -e CHECK_CRON="0 4 * * *" \
  -e RESTIC_CHECK_ARGS="--read-data" \
  -e DOCKER_STOP_CONTAINERS="container1,container2" \
  -v ./backup:/data/backup \
  -v ~/.config/rclone:/root/.config/rclone \
  -v /var/run/docker.sock:/var/run/docker.sock \
  sync:latest
```

## Behavior

1. On startup:
   - The container checks if the Restic repository exists and initializes it if necessary
   - If `RUN_ON_STARTUP` is set to true, executes a backup immediately

2. Scheduled Operations:
   - Backup runs according to `BACKUP_CRON` schedule
   - Pruning operations run according to `PRUNE_CRON` schedule
   - Repository health checks run according to `CHECK_CRON` schedule

3. During backup:
   - Stops specified containers if `DOCKER_STOP_CONTAINERS` is set
   - Performs the backup
   - Restarts previously stopped containers

4. During pruning:
   - Executes forget command with specified `RESTIC_FORGET_ARGS`
   - Prunes the repository to remove deleted data

## Notes

- The Docker socket mount is required only if using `DOCKER_STOP_CONTAINERS`
- Ensure proper read permissions for backup source paths
- Configure RClone before using with cloud storage providers
- The RClone configuration file must be mounted at `/root/.config/rclone`
- Consider using environment files or secrets for sensitive variables
- All times are interpreted in the container's timezone (set via `TZ` variable)
