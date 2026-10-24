# AWS CI CD Website Deployment Project

**Student:** Vamsi Krishna  
**Submission date:** 24 October 2026

## Project objective

Build a static website, store the source in GitHub, package it in Docker, deploy it to two AWS web servers with Ansible, and use Jenkins as the continuous integration and delivery controller.

## Deliverables

| Component | Implementation |
|---|---|
| Website | Northstar static website in `northstar-website/` |
| Source control | GitHub repository with Jenkins and deployment files |
| Container | Nginx Alpine Docker image defined in `northstar-website/Dockerfile` |
| Automation | Jenkins Pipeline defined in `Jenkinsfile` |
| Configuration | Ansible playbook and role in `deploy/ansible/` |
| Web targets | Two EC2 instances running the Northstar container |

## Architecture

```text
GitHub repository
        |
        v
Jenkins controller on AWS EC2
        |
        | builds Docker image and runs Ansible
        v
Two AWS EC2 web servers
        |
        v
Docker container with Nginx and Northstar website
```

## Deployment workflow

1. Source code is pushed to GitHub.
2. Jenkins checks out the repository and validates the website files.
3. Jenkins builds a Docker image named `northstar-web`.
4. Jenkins saves the image as an archive.
5. Jenkins runs the Ansible playbook.
6. Ansible installs Docker where required, copies the image archive, loads it, and starts the website container on port 80.
7. Ansible verifies that the local web server responds with HTTP 200.

## Repository evidence

- GitHub repository: https://github.com/vamsikrishnaduvvari/Vamsi-krishna-
- Jenkins pipeline file: `Jenkinsfile`
- Docker configuration: `northstar-website/Dockerfile`
- Ansible playbook: `deploy/ansible/deploy.yml`
- Ansible role: `deploy/ansible/roles/northstar_web/`
- Deployment guide: `DEPLOYMENT.md`

## AWS deployment evidence

| Service | Address | Purpose |
|---|---|---|
| Jenkins | http://13.206.70.250:8080 | Build and deployment automation |
| Web server 1 | http://65.2.181.88 | Dockerized Northstar website |
| Web server 2 | http://65.2.37.20 | Dockerized Northstar website |

## Verification performed

- Website repository pushed to GitHub.
- Jenkins controller started and pipeline job created.
- Docker image successfully built by Jenkins.
- Ansible connected to both target servers.
- Docker installed on both target servers.
- Website image transferred to both servers.
- Website container started and local HTTP health checks were performed.

## Demonstration checklist

For the instructor demonstration, open the GitHub repository, Jenkins dashboard, and both web-server URLs. Show the `Jenkinsfile`, Dockerfile, Ansible playbook, and a completed Jenkins build log.

## Cost note

The AWS EC2 instances remain running for the demonstration. Stop the controller and both web instances after review to avoid unnecessary compute charges.
