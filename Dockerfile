# Use the official restic image as base
FROM alpine:latest

# Create data directory
RUN apk add --no-cache docker-cli rclone restic bash tzdata

# Copy backup script
COPY backup.sh /backup.sh
RUN chmod +x /backup.sh

# Set as entrypoint
ENTRYPOINT ["/backup.sh"]
