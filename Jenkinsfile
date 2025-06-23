pipeline {
    agent any
    environment {
        NEXUS_USER      = credentials('nexus-username')
        NEXUS_PASSWORD  = credentials('nexus-password')
        NEXUS_REPO      = credentials('nexus-ip-port')
        BASTION_IP      = credentials('bastion-ip')
        ANSIBLE_IP      = credentials('ansible-ip')
        NVD_API_KEY     = credentials('nvd-key')
        BASTION_ID      = credentials('bastion-id')
        AWS_REGION      = 'eu-west-3'
    }
    
    tools {
        terraform 'terraform' // Make sure this matches the configured tool in Jenkins
    }
    triggers {
        pollSCM('* * * * *') // Polls Git every minute
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

        stage('Dependency Check') {
            steps {
                withCredentials([string(credentialsId: 'nvd-key', variable: 'NVD_API_KEY')]) {
                    dependencyCheck additionalArguments: "--scan ./ --disableYarnAudit --disableNodeAudit --nvdApiKey=$NVD_API_KEY",
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
                nexusArtifactUploader artifacts: [[
                    artifactId: 'spring-petclinic',
                    classifier: '',
                    file: 'target/spring-petclinic-2.4.2.war',
                    type: 'war'
                ]],
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

        stage('Login to Nexus Docker Repo') {
            steps {
                sh 'docker login --username $NEXUS_USER --password $NEXUS_PASSWORD $NEXUS_REPO'
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh "trivy image -f table $NEXUS_REPO/petclinicapps > trivyfs.txt"
            }
        }

        stage('Push Docker Image to Nexus') {
            steps {
                sh 'docker push $NEXUS_REPO/petclinicapps'
            }
        }

        stage('Prune Docker Images') {
            steps {
                sh 'docker image prune -f'
            }
        }

        stage('Deploy to Stage') {
            steps {
                sshagent(['ansible-key']) {
                    sh "ssh -t -t ec2-user@$ANSIBLE_IP -o StrictHostKeyChecking=no \"cd /etc/ansible && ansible-playbook /opt/docker/docker-container.yml\""
                    sh "ssh -t -t ec2-user@$ANSIBLE_IP -o StrictHostKeyChecking=no \"cd /etc/ansible && ansible-playbook /opt/docker/newrelic-container.yml\""
                }
            }
        }

        stage('Check Stage Website Availability') {
            steps {
                sh "sleep 90"
                script {
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://stage.chijiokedevops.space", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "✅ Stage Petclinic is up (HTTP ${response})", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "🚨 Stage Petclinic is down (HTTP ${response})", tokenCredentialId: 'slack')
                    }
                }
            }
        }

        stage('Request for Approval') {
            steps {
                timeout(activity: true, time: 10, unit: 'MINUTES') {
                    input message: 'Deploy to Production?', submitter: 'admin'
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                sshagent(['ansible-key']) {
                    sh "ssh -t -t ec2-user@$ANSIBLE_IP -o StrictHostKeyChecking=no \"cd /etc/ansible && ansible-playbook /opt/docker/docker-container.yml\""
                    sh "ssh -t -t ec2-user@$ANSIBLE_IP -o StrictHostKeyChecking=no \"cd /etc/ansible && ansible-playbook /opt/docker/newrelic-container.yml\""
                }
            }
        }

        stage('Check Prod Website Availability') {
            steps {
                sh "sleep 90"
                script {
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://prod.chijiokedevops.space", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "✅ Prod Petclinic is up (HTTP ${response})", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "🚨 Prod Petclinic is down (HTTP ${response})", tokenCredentialId: 'slack')
                    }
                }
            }
        }
    }
}
