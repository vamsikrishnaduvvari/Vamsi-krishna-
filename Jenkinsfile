pipeline {
  agent any

  triggers {
    pollSCM('H/5 * * * *')
  }

  environment {
    IMAGE_NAME = 'python-flask-app'
    IMAGE_TAG = "${BUILD_NUMBER}"
    IMAGE_ARCHIVE = 'python-flask-app.tar'
  }

  parameters {
    booleanParam(name: 'DEPLOY', defaultValue: false, description: 'Deploy only when a target EC2 instance is intentionally supplied.')
    string(name: 'TARGET_HOST', defaultValue: '', description: 'EC2 public DNS name, public IP, or reachable private IP.')
    string(name: 'TARGET_USER', defaultValue: 'ec2-user', description: 'SSH user for the target, such as ec2-user or ubuntu.')
  }

  stages {
    stage('Validate Python application') {
      steps {
        sh '''#!/bin/sh
          set -eu
          test -f python-app/app.py
          test -f python-app/requirements.lock
          python3 -m py_compile python-app/app.py
        '''
      }
    }

    stage('Build Docker image') {
      steps {
        sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG -f python-app/Dockerfile .'
        sh 'docker save $IMAGE_NAME:$IMAGE_TAG -o $IMAGE_ARCHIVE'
      }
    }

    stage('Deploy with Ansible') {
      when { expression { return params.DEPLOY && params.TARGET_HOST.trim() } }
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-deploy-key', keyFileVariable: 'SSH_KEY')]) {
          sh '''#!/bin/sh
            set -eu
            case "$TARGET_HOST" in *[!A-Za-z0-9.-]*) echo 'TARGET_HOST contains unsupported characters' >&2; exit 2;; esac
            case "$TARGET_USER" in *[!A-Za-z0-9_-]*) echo 'TARGET_USER contains unsupported characters' >&2; exit 2;; esac
            printf '[web]\\n%s ansible_user=%s\\n' "$TARGET_HOST" "$TARGET_USER" > deploy/ansible/inventory/hosts.ini
            ANSIBLE_CONFIG=deploy/ansible/ansible.cfg ansible-galaxy collection install -r deploy/ansible/requirements.yml
            ANSIBLE_CONFIG=deploy/ansible/ansible.cfg ansible-playbook deploy/ansible/python-app.yml \\
              --private-key "$SSH_KEY" \\
              -e "image_name=$IMAGE_NAME:$IMAGE_TAG" \\
              -e "image_archive=$WORKSPACE/$IMAGE_ARCHIVE"
          '''
        }
      }
    }
  }

  post {
    always { archiveArtifacts artifacts: 'python-flask-app.tar', fingerprint: true, allowEmptyArchive: true }
  }
}
