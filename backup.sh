#!/bin/bash

# Ensure RESTIC_REPOSITORY and RESTIC_PASSWORD are set
if [[ -z "$RESTIC_REPOSITORY" || -z "$RESTIC_PASSWORD" ]]; then
    echo "Error: RESTIC_REPOSITORY and RESTIC_PASSWORD must be set."
    exit 1
fi

# Check if the Restic repository is initialized, if not, initialize it
if ! restic snapshots > /dev/null 2>&1; then
    echo "Restic repository not initialized. Initializing now..."
    restic init $RESTIC_INIT_ARGS
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to initialize Restic repository."
        exit 1
    fi
    echo "Restic repository initialized successfully."
fi

check_cron_match() {
    local cron_expr=$1
    IFS=' ' read -ra CRON_FIELDS <<< "$cron_expr"

    # Ensure cron syntax is valid (expecting 5 fields)
    if [[ ${#CRON_FIELDS[@]} -ne 5 ]]; then
        echo "Error: Cron expression must have exactly 5 fields (minute hour day month weekday)."
        exit 1
    fi

    # Check if current time matches the cron schedule
    if [[ $(date +"%M") == ${CRON_FIELDS[0]} || ${CRON_FIELDS[0]} == "*" ]] && \
       [[ $(date +"%H") == ${CRON_FIELDS[1]} || ${CRON_FIELDS[1]} == "*" ]] && \
       [[ $(date +"%d") == ${CRON_FIELDS[2]} || ${CRON_FIELDS[2]} == "*" ]] && \
       [[ $(date +"%m") == ${CRON_FIELDS[3]} || ${CRON_FIELDS[3]} == "*" ]] && \
       [[ $(date +"%u") == ${CRON_FIELDS[4]} || ${CRON_FIELDS[4]} == "*" ]]; then
        return 0  # True (matches)
    else
        return 1  # False (doesn't match)
    fi
}

# Function to run backup immediately
run_backup() {
    echo "Starting backup process at $(date)"
    
    # Stop specified Docker containers if set
    if [[ -n "$DOCKER_STOP_CONTAINERS" ]]; then
        IFS=',' read -ra CONTAINERS <<< "$DOCKER_STOP_CONTAINERS"
        for CONTAINER in "${CONTAINERS[@]}"; do
            echo "Stopping container: $CONTAINER"
            docker stop "$CONTAINER"
        done
        sleep 10  # Wait for 10 seconds after stopping the container
    fi
    
    echo "Starting Restic backup at $(date)"
    # Include RESTIC_JOB_ARGS in the backup command
    restic backup /data/backup $RESTIC_JOB_ARGS  # Change this to your backup path
    echo "Backup completed at $(date)"
    restic snapshots

    # Start specified Docker containers if set
    if [[ -n "$DOCKER_STOP_CONTAINERS" ]]; then
        IFS=',' read -ra CONTAINERS <<< "$DOCKER_STOP_CONTAINERS"
        for CONTAINER in "${CONTAINERS[@]}"; do
            echo "Starting container: $CONTAINER"
            docker start "$CONTAINER"
        done
    fi
}

# Function to run forget command (prune)
run_forget() {
    if [[ -n "$RESTIC_FORGET_ARGS" ]]; then
        echo "Running restic forget with arguments: $RESTIC_FORGET_ARGS"
        restic forget $RESTIC_FORGET_ARGS
        echo "Restic forget completed at $(date)"
    fi
}

run_check() {
    if [[ -n "$RESTIC_CHECK_ARGS" ]]; then
        echo "Running restic check with arguments: $RESTIC_CHECK_ARGS"
        restic check $RESTIC_CHECK_ARGS
        echo "Restic check completed at $(date)"
    fi
}

# Run backup and forget immediately if RUN_ON_STARTUP is set
if [[ -n "$RUN_ON_STARTUP" ]]; then
    echo "RUN_ON_STARTUP is set, running backup and forget immediately."
if [[ -n "$RESTIC_BACKUP_CRON" ]]; then    
    run_backup
    fi
if [[ -n "$PRUNE_CRON" ]]; then
    run_forget
    fi
if [[ -n "$CHECK_CRON" ]]; then
    run_forget
    fi
fi

# Only check cron and run backup if RESTIC_BACKUP_CRON is set
if [[ -n "$RESTIC_BACKUP_CRON" ]]; then
    while true; do
        # Check if current time matches the backup cron schedule
        if check_cron_match "$RESTIC_BACKUP_CRON"; then
            run_backup
        fi
        
        sleep 30  # Check the schedule every 30 seconds
    done
else
    echo "RESTIC_BACKUP_CRON is not set, not running backups."
    exit 0
fi

# Only check cron and run backup if RESTIC_BACKUP_CRON is set
if [[ -n "$PRUNE_CRON" ]]; then
    while true; do
        # Check if current time matches the prune cron schedule
        if [[ -n "$PRUNE_CRON" && check_cron_match "$PRUNE_CRON" ]]; then
            run_forget
        fi
        
        sleep 30  # Check the schedule every 30 seconds
    done
else
    echo "PRUNE_CRON is not set, not running PRUNE."
    exit 0
fi

# Only check cron and run backup if RESTIC_BACKUP_CRON is set
if [[ -n "$CHECK_CRON" ]]; then
    while true; do
        # Check if current time matches the prune cron schedule
        if [[ -n "$CHECK_CRON" && check_cron_match "$CHECK_CRON" ]]; then
            run_forget
        fi
        
        sleep 30  # Check the schedule every 30 seconds
    done
else
    echo "CHECK_CRON is not set, not running CHECK_CRON."
    exit 0
fi