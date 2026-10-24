pipeline {
  agent any

  environment {
    IMAGE_NAME = 'northstar-web'
    IMAGE_TAG = "${BUILD_NUMBER}"
    IMAGE_ARCHIVE = 'northstar-web.tar'
  }

  parameters {
    booleanParam(name: 'DEPLOY', defaultValue: false, description: 'Deploy only after two target servers are available.')
  }

  stages {
    stage('Validate website') {
      steps {
        sh '''#!/bin/sh
          set -eu
          test -f northstar-website/index.html
          test -f northstar-website/styles.css
          grep -q '<title>' northstar-website/index.html
        '''
      }
    }

    stage('Build Docker image') {
      steps {
        sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG -f northstar-website/Dockerfile .'
        sh 'docker save $IMAGE_NAME:$IMAGE_TAG -o $IMAGE_ARCHIVE'
      }
    }

    stage('Deploy with Ansible') {
      when { expression { return params.DEPLOY } }
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'northstar-deploy-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER'),
          file(credentialsId: 'northstar-deploy-inventory', variable: 'DEPLOY_INVENTORY')
        ]) {
          sh '''#!/bin/sh
            set -eu
            cp "$DEPLOY_INVENTORY" deploy/ansible/inventory/hosts.ini
            chmod 600 "$SSH_KEY"
            ANSIBLE_CONFIG=deploy/ansible/ansible.cfg ansible-galaxy collection install -r deploy/ansible/requirements.yml
            ANSIBLE_CONFIG=deploy/ansible/ansible.cfg ansible-playbook deploy/ansible/deploy.yml \\
              --private-key "$SSH_KEY" \\
              -e "ansible_user=$SSH_USER" \\
              -e "image_name=$IMAGE_NAME:$IMAGE_TAG" \\
              -e "image_archive=$WORKSPACE/$IMAGE_ARCHIVE"
          '''
        }
      }
    }
  }

  post {
    always { archiveArtifacts artifacts: 'northstar-web.tar', fingerprint: true, allowEmptyArchive: true }
  }
}
