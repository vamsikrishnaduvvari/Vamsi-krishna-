# Python Flask CI/CD setup

This repository contains a complete delivery pipeline without provisioning cloud resources. It can be run entirely on a workstation with Docker.

## Pipeline

`GitHub push -> Jenkins -> validate Flask code -> build Docker image -> save image -> Ansible -> EC2 instance`

The Jenkinsfile deliberately defaults `DEPLOY` to `false`. A normal GitHub-triggered build validates and packages the app only; it never creates AWS resources or deploys. A deployment requires an explicit target host and the Jenkins SSH credential named `ec2-deploy-key`.

## Run Jenkins locally

From a Linux or WSL Docker host:

```sh
docker compose -f docker-compose.jenkins.yml up --build
```

Open `http://localhost:8081`, complete Jenkins setup, and create a Pipeline job from this repository. Install the plugins in `jenkins/plugins.txt` if Jenkins does not offer them during setup.

On the AWS controller, Jenkins receives the already-existing deployment key as a read-only container mount. For production, replace this lab shortcut with Jenkins SSH credentials. The provided example inventory is intentionally non-routable and cannot deploy anywhere.

## Test the application image locally

```sh
docker build -t python-flask-app:local -f python-app/Dockerfile .
docker run --rm -p 8080:8000 python-flask-app:local
```

Visit `http://localhost:8080/health`.

## Enable real deployment later

In Jenkins, create an SSH private-key credential named `ec2-deploy-key`. Then run `python-app-cicd` with `DEPLOY=true`, `TARGET_HOST` set to the EC2 public DNS/IP (or a reachable private IP), and `TARGET_USER` set to `ec2-user` or `ubuntu`.

The playbook installs Docker, loads the image built by Jenkins, starts the container on port 80, and checks `/health`. It never asks Ansible to create AWS resources.
