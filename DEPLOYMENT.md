# Non-billable CI/CD setup

This repository contains a complete delivery pipeline without provisioning cloud resources. It can be run entirely on a workstation with Docker.

## Pipeline

`GitHub push -> Jenkins -> validate HTML -> build Docker image -> save image -> Ansible -> two web servers`

The Jenkinsfile deliberately defaults `DEPLOY` to `false`. No AWS resource, load balancer, registry, or instance is created by a build.

## Run Jenkins locally

From a Linux or WSL Docker host:

```sh
docker compose -f docker-compose.jenkins.yml up --build
```

Open `http://localhost:8081`, complete Jenkins setup, and create a Pipeline job from this repository. Install the plugins in `jenkins/plugins.txt` if Jenkins does not offer them during setup.

On the AWS controller, Jenkins receives the already-existing deployment key as a read-only container mount. For production, replace this lab shortcut with Jenkins SSH credentials. The provided example inventory is intentionally non-routable and cannot deploy anywhere.

## Test the site image locally

```sh
docker build -t northstar-web:local -f northstar-website/Dockerfile .
docker run --rm -p 8080:8080 northstar-web:local
```

Visit `http://localhost:8080`.

## Enable real deployment later

Create two servers only when you accept their provider costs. In Jenkins, run the `northstar-cicd` pipeline with `DEPLOY=true` and pass their comma-separated private IPs in `TARGETS`.

The playbook installs Docker, loads the image built by Jenkins, starts the container on port 80, and checks its HTTP response. It never asks Ansible to create AWS resources.
