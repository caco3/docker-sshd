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

| Variable | Explanation |
|:-----------------:|:------------------------------------------------------------------------------------------------------------------------------------:|
| USERNAME | Username on the host system and SSH, usually backintime |
| PUBLIC_KEY | SSH public key for user authentication |
