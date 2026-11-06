import hudson.plugins.git.GitSCM
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
import com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey
import com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey.DirectEntryPrivateKeySource

def jenkins = Jenkins.get()
def credentialStore = SystemCredentialsProvider.getInstance().getStore()
if (!credentialStore.getCredentials(com.cloudbees.plugins.credentials.domains.Domain.global()).any { it.id == 'ec2-deploy-key' }) {
  def keyFile = new File('/run/deploy-key/ec2-deploy-key.pem')
  if (!keyFile.exists()) {
    throw new IllegalStateException('Deployment key is not mounted at /run/deploy-key/ec2-deploy-key.pem')
  }
  credentialStore.addCredentials(
    com.cloudbees.plugins.credentials.domains.Domain.global(),
    new BasicSSHUserPrivateKey(
      com.cloudbees.plugins.credentials.CredentialsScope.GLOBAL,
      'ec2-deploy-key',
      'ec2-user',
      new DirectEntryPrivateKeySource(keyFile.text),
      '',
      'Python CI/CD deployment key'
    )
  )
  println('Created the EC2 deployment credential.')
}

def jobName = 'python-app-cicd'
def job = jenkins.getItem(jobName)
if (job == null) {
  job = jenkins.createProject(WorkflowJob, jobName)
  job.definition = new CpsScmFlowDefinition(
    new GitSCM('https://github.com/vamsikrishnaduvvari/Vamsi-krishna-.git'),
    'Jenkinsfile'
  )
  job.save()
  println("Created Jenkins Pipeline job: ${jobName}")
}
