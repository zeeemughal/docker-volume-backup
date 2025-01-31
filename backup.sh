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
    mins=$(date +"%M")
    # mins=$((mins+1))
    hours=$(date +"%H")
    day=$(date +"%d")
    month=$(date +"%m")
    dayofweek=$(date +"%u")
    year=$(date +"%Y")

    if [[ ${CRON_FIELDS[0]} != "*" ]]; then
        mins=${CRON_FIELDS[0]}
        mins=$(printf "%02d" "$mins")
        
    fi
    if [[ ${CRON_FIELDS[1]} != "*" ]]; then
        hours=${CRON_FIELDS[1]}
    fi
    if [[ ${CRON_FIELDS[2]} != "*" ]]; then
        day=${CRON_FIELDS[2]}
    fi
    if [[ ${CRON_FIELDS[3]} != "*" ]]; then
        month=${CRON_FIELDS[3]}
    fi
    if [[ ${CRON_FIELDS[4]} != "*" ]]; then
        dayofweek=${CRON_FIELDS[4]}
    fi

    # Ensure cron syntax is valid (expecting 5 fields)
    if [[ ${#CRON_FIELDS[@]} -ne 5 ]]; then
        echo "Error: Cron expression must have exactly 5 fields (minute hour day month weekday)."
        exit 1
    fi
    #dayname=$(date -d "2025-01-26 +$((dayofweek)) days" +"%A")
    export crondt="$hours:$mins $day/$month/$year"
    # Check if current time matches the cron schedule
    if [[ $(date +"%M") == ${mins} ]] && \
       [[ $(date +"%H") == ${hours} ]] && \
       [[ $(date +"%d") == ${day} ]] && \
       [[ $(date +"%m") == ${month} ]] && \
       [[ $(date +"%u") == ${dayofweek} ]]; then
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
if [[  "$RUN_ON_STARTUP" == "true" ]]; then
    echo "RUN_ON_STARTUP is set, running jobs immediately."
if [[ -n "$BACKUP_CRON" ]]; then    
    run_backup
    fi
if [[ -n "$PRUNE_CRON" ]]; then
    run_forget
    fi
if [[ -n "$CHECK_CRON" ]]; then
    run_check
    fi
fi

# Only check cron and run backup if BACKUP_CRON is set
if [[ -n "$BACKUP_CRON" ]]; then
    echo "BACKUP_CRON is set, running backups on schedule."
    check_cron_match "$BACKUP_CRON"
    echo "Next backup will run at ${crondt}"
    while true; do
        # Check if current time matches the backup cron schedule
        if check_cron_match "$BACKUP_CRON"; then
            run_backup
        fi
        
        sleep 58  # Check the schedule every 30 seconds
    done
else
    echo "BACKUP_CRON is not set, not running backups."
    
fi

# Only check cron and run backup if BACKUP_CRON is set
if [[ -n "$PRUNE_CRON" ]]; then
    echo "PRUNE_CRON is set, running backups on schedule."
    check_cron_match "$PRUNE_CRON"
    echo "Next prune will run at ${crondt}"
    while true; do
        # Check if current time matches the prune cron schedule
        if check_cron_match "$PRUNE_CRON"; then
            run_forget
        fi
        
        sleep 58  # Check the schedule every 30 seconds
    done
else
    echo "PRUNE_CRON is not set, not running PRUNE."
    
fi

# Only check cron and run backup if BACKUP_CRON is set
if [[ -n "$CHECK_CRON" ]]; then
    echo "CHECK_CRON is set, running backups on schedule."
    check_cron_match "$CHECK_CRON"
    echo "Next check will run at ${crondt}"
    while true; do
        # Check if current time matches the prune cron schedule
        if check_cron_match "$CHECK_CRON"; then
            run_check
        fi
        
        sleep 58  # Check the schedule every 30 seconds
    done
else
    echo "CHECK_CRON is not set, not running CHECK_CRON."
    
fi
