    
pipeline{
    agent any
    environment {
        NEXUS_USER = credentials('nexus-username')
        NEXUS_PASSWORD = credentials('nexus-password')
        NEXUS_REPO = credentials('nexus-ip-port')
        BASTION_IP = credentials('bastion-ip')
        ANSIBLE_IP = credentials('ansible-ip')
        NVD_API_KEY= credentials('nvd-key')
        BASTION_ID= credentials('bastion-id')
        AWS_REGION= 'eu-west-3'
    }
    triggers {
        pollSCM('* * * * *') // Runs every minute
    }
    stages {
        stage('Code Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh 'mvn sonar:sonar'
                }   
            }
        }
        stage('Quality Gate') {
            steps {
                timeout(time: 2, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }
        stage('Dependency check') {
            steps {
                withCredentials([string(credentialsId: 'nvd-key', variable: 'NVD_API_KEY')]) {
                    dependencyCheck additionalArguments: "--scan ./ --disableYarnAudit --disableNodeAudit --nvdApiKey $NVD_API_KEY",
                        odcInstallation: 'DP-Check'
                }
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('Build Artifact') {
            steps {
                sh 'mvn clean package -DskipTests -Dcheckstyle.skip'
            }
        }
        stage('Push Artifact to Nexus Repo') {
            steps {
                nexusArtifactUploader artifacts: [[artifactId: 'spring-petclinic',
                classifier: '',
                file: 'target/spring-petclinic-2.4.2.war',
                type: 'war']],
                credentialsId: 'nexus-cred',
                groupId: 'Petclinic',
                nexusUrl: 'nexus.chijiokedevops.space',
                nexusVersion: 'nexus3',
                protocol: 'https',
                repository: 'nexus-repo',
                version: '1.0'
            }
        }
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $NEXUS_REPO/petclinicapps .'
            }
        }
        stage('Log Into Nexus Docker Repo') {
            steps {
                sh 'docker login --username $NEXUS_USER --password $NEXUS_PASSWORD $NEXUS_REPO'
            }
        }
        stage('Trivy image Scan') {
            steps {
                sh "trivy image -f table $NEXUS_REPO/petclinicapps > trivyfs.txt"
            }
        }
        stage('Push to Nexus Docker Repo') {
            steps {
                sh 'docker push $NEXUS_REPO/petclinicapps'
            }
        }
        stage('prune docker images') {
            steps {
                sh 'docker image prune -f'
            }
        }
       stage('Deploy to stage') {
    steps {
        sshagent(['ansible-key']) {
            sh "ssh -t -t ec2-user@10.0.3.20 -o StrictHostKeyChecking=no \"cd /etc/ansible && ansible-playbook /opt/docker/docker-container.yml\""
            sh "ssh -t -t ec2-user@10.0.3.20 -o StrictHostKeyChecking=no \"cd /etc/ansible && ansible-playbook /opt/docker/newrelic-container.yml\""
        }
    }
}
        stage('check stage website availability') {
            steps {
                 sh "sleep 90"
                 sh "curl -s -o /dev/null -w \"%{http_code}\" https://stage.chijiokedevops.space"
                script {
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://stage.chijiokedevops.space", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "The stage petclinic java application is up and running with HTTP status code ${response}.", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "The stage petclinic java application appears to be down with HTTP status code ${response}.", tokenCredentialId: 'slack')
                    }
                }
            }
        }
        stage('Request for Approval') {
            steps {
                timeout(activity: true, time: 10) {
                    input message: 'Needs Approval ', submitter: 'admin'
                }
            }
        }
        stage('Deploy to prod') {
    steps {
        sshagent(['ansible-key']) {
            sh "ssh -t -t ec2-user@10.0.3.20 -o StrictHostKeyChecking=no \"cd /etc/ansible && ansible-playbook /opt/docker/docker-container.yml\""
            sh "ssh -t -t ec2-user@10.0.3.20 -o StrictHostKeyChecking=no \"cd /etc/ansible && ansible-playbook /opt/docker/newrelic-container.yml\""
        }
    }
}
        stage('check prod website availability') {
            steps {
                 sh "sleep 90"
                 sh "curl -s -o /dev/null -w \"%{http_code}\" https://prod.chijiokedevops.space"
                script {
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://prod.chijiokedevops.space", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "The prod petclinic java application is up and running with HTTP status code ${response}.", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "The prod petclinic java application appears to be down with HTTP status code ${response}.", tokenCredentialId: 'slack')
                    }
                }
            }
        }
    }
}
    

