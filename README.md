## Make your OpenSSH fly on Alpine

### Overview

Docker container to provide a ready-to-go sshd-server for backintime.
Run this container on your backup target and no longer rely on the natively installed sshd-server and rsync.

This image is based on the work of [https://github.com/Hermsi1337/docker-sshd](https://github.com/Hermsi1337/docker-sshd).

### Dockerhub

For recent versions check [Dockerhub](https://hub.docker.com/repositories/caco3x/backintime-sshd/).

#### Docker Compose
See example in [docker-compose.yaml](docker-compose.yaml)


#### Environment variables

| Variable | Possible Values | Explanation |
|:-----------------:|:-----------------:|:------------------------------------------------------------------------------------------------------------------------------------:|
| USER_UID | any valid UID | User ID for the backintime user (should match the target system, run `id -u backintime` on the target system to get it) |
| USER_GID | any valid GID | Group ID for the backintime user (should match the target system, run `id -g backintime` on the target system to get it) |
| PUBLIC_KEY | SSH public key string | SSH public key for backintime user authentication (required) |
