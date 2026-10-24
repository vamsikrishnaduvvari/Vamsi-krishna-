import hudson.plugins.git.GitSCM
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob
import jenkins.model.Jenkins

def jenkins = Jenkins.get()
def jobName = 'northstar-cicd'
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

if (job.nextBuildNumber == 1) {
  job.scheduleBuild2(10, new hudson.model.CauseAction(new hudson.model.Cause.RemoteCause('jenkins-bootstrap', 'Register Pipeline parameters')))
  println("Scheduled initial Jenkins Pipeline build: ${jobName}")
}

if (job.nextBuildNumber == 2) {
  def actions = [
    new hudson.model.CauseAction(new hudson.model.Cause.RemoteCause('jenkins-bootstrap', 'Deploy to both web servers')),
    new hudson.model.ParametersAction(
      new hudson.model.BooleanParameterValue('DEPLOY', true),
      new hudson.model.StringParameterValue('TARGETS', '172.31.38.155 ansible_user=ec2-user,172.31.9.39 ansible_user=ubuntu')
    )
  ] as hudson.model.Action[]
  job.scheduleBuild2(10, actions)
  println("Scheduled production Jenkins Pipeline build: ${jobName}")
}
