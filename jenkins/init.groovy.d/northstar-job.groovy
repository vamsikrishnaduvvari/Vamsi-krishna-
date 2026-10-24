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
