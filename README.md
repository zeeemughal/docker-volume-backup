# Docker Restic Backup Automation with MySQL

This Docker container automates MySQL database backups using Restic, with support for scheduled backups and Docker container management during the backup process.

## Features

- Automated MySQL database backup execution
- Cron-based scheduling support
- Docker container stop/start management during backups
- Automatic Restic repository initialization
- Configurable retention policy
- Support for backup restoration
- Integrated MySQL 8.0 database service

## Environment Variables

### Backup Service
Required:
- `RESTIC_REPOSITORY`: The repository location where backups will be stored (e.g., "rclone:gdrive:/backup")
- `RESTIC_PASSWORD`: Password for the Restic repository
- `DOCKER_CONTAINER_STOP`: Container to stop during backup process (e.g., "magical_ganguly")

Optional:
- `BACKUP_CRON`: Cron expression for scheduling backups (e.g., "* * * * *")
- `PRUNE_CRON`: Cron expression for scheduling pruning operations
- `DOCKER_STOP_CONTAINERS`: Container names to stop during backup (e.g., "mysql-container")
- `RESTIC_FORGET_ARGS`: Arguments for the `restic forget` command (e.g., "--prune --keep-last 2")
- `RUN_ON_STARTUP`: Set to "true" to run backup immediately on container start
- `CHECK_CRON`: Cron expression for scheduling repository health checks (e.g., "51 20 * * *")
- `RESTIC_CHECK_ARGS`: Arguments for the `restic check` command (e.g., "--read-data")
- `TZ`: Timezone for the container (e.g., "Asia/Karachi")

### Docker Compose

```yaml
services:
  backup:
    depends_on:
      - mysql
    image: zeeemughal/docker-volume-backup
    environment:
      - TZ=Asia/Karachi
      - DOCKER_CONTAINER_STOP=magical_ganguly
      - RESTIC_REPOSITORY=rclone:gdrive:/backup
      - BACKUP_CRON=* * * * *
      - PRUNE_CRON=* * * * *
      - RESTIC_FORGET_ARGS=--prune --keep-last 2
      - RUN_ON_STARTUP=true
      - CHECK_CRON=51 20 * * *
      - RESTIC_CHECK_ARGS=--read-data
      - DOCKER_STOP_CONTAINERS=mysql-container
      - RESTIC_PASSWORD=your_password
    volumes:
      - mysql_data:/data/backup
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.config/rclone:/root/.config/rclone

  mysql:
    image: mysql:8.0
    container_name: mysql-container
    restart: unless-stopped
    ports:
      - "3306:3306"
    environment:
      MYSQL_ROOT_PASSWORD: rootpassword
      MYSQL_DATABASE: mydatabase
      MYSQL_USER: myuser
      MYSQL_PASSWORD: mypassword
    volumes:
      - mysql_data:/var/lib/mysql
    networks:
      - mysql_network

volumes:
  mysql_data:
```

### Backup Restoration

To restore from backup, uncomment the following lines in your docker-compose.yml:

```yaml
services:
  backup:
    image: zeeemughal/docker-volume-backup
    environment:
      - TZ=Asia/Karachi
      - DOCKER_CONTAINER_STOP=magical_ganguly
      - RESTIC_REPOSITORY=rclone:gdrive:/backup
      - BACKUP_CRON=0 5 * * *
      - PRUNE_CRON=0 5 * * *
      - RESTIC_FORGET_ARGS=--prune --keep-last 2
      - RUN_ON_STARTUP=false
      - CHECK_CRON=51 20 * * *
      - RESTIC_CHECK_ARGS=--read-data
      - DOCKER_STOP_CONTAINERS=mysql-container
      - RESTIC_PASSWORD=your_password
    volumes:
      - mysql_data:/data/backup
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.config/rclone:/root/.config/rclone

    entrypoint:
      - "/bin/sh"
      - "-c"
      - "restic restore latest --target /"
    restart: "no"

volumes:
  mysql_data:
    external: true
```

Note: When using restore functionality, set `RUN_ON_STARTUP` to false.

## Behavior

1. On startup:
   - The container checks if the Restic repository exists and initializes it if necessary
   - If `RUN_ON_STARTUP` is set to true, executes a backup immediately
   - MySQL service starts and creates the specified database and user

2. Scheduled Operations:
   - Backup runs according to `BACKUP_CRON` schedule
   - Pruning operations run according to `PRUNE_CRON` schedule
   - Repository health checks run according to `CHECK_CRON` schedule

3. During backup:
   - Stops specified containers (`DOCKER_STOP_CONTAINERS` and `DOCKER_CONTAINER_STOP`)
   - Performs the backup of MySQL data
   - Restarts previously stopped containers

4. During pruning:
   - Executes forget command with specified `RESTIC_FORGET_ARGS`
   - Prunes the repository to remove deleted data

## Notes

- The Docker socket mount is required for container management
- MySQL data is persisted using a named volume `mysql_data`
- MySQL server is accessible on port 3306
- Configure RClone before using with cloud storage providers
- The RClone configuration file must be mounted at `/root/.config/rclone`
- Consider using environment files or secrets for sensitive variables
- All times are interpreted in the container's timezone (set via `TZ` variable)
- MySQL service includes automatic restart policy (unless-stopped)
