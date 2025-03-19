pipeline{
    agent {
        label "jenkins-node"
    }
    environment {
        NEXUS_USER = credentials('nexus-username')
        NEXUS_PASSWORD = credentials('nexus-password')
        NEXUS_REPO = credentials('nexus-repo')
        NVDKEY  = credentials('nvd-key')
        ANSIBLE_IP  = credentials('ansible-ip')
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
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit --nvdApiKey ${NVDKEY}', odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }
        stage('STAST report slack notification') {
            steps {
                slackSend channel: '24th-february-auto-discovery-project', message: 'Security Scan report generated and waiting for review before approval ', teamDomain: 'Cloudhight', tokenCredentialId: 'slack-cred'
            }
        }
        stage('Security cleared Approval') {
            steps {
                timeout(activity: true, time: 10) {
                    input message: 'Needs Approval ', submitter: 'admin'
                }
            }
        }
        // stage('Test Code') {
        //     steps {
        //         sh 'mvn test -Dcheckstyle.skip'
        //     }
        // }
        stage('Build Artifact') {
            steps {
                sh 'mvn clean package -DskipTests -Dcheckstyle.skip'
            }
        }
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $NEXUS_REPO/petclinicapps .'
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
                nexusUrl: 'nexus.hullerdata.com',
                nexusVersion: 'nexus3',
                protocol: 'https',
                repository: 'nexus-repo',
                version: '1.0'
            }
        }
        stage('Trivy fs Scan') {
            steps {
                sh "trivy fs . > trivyfs.json"
            }
        }

        stage('Log Into Nexus Docker Repo') {
            steps {
                sh 'docker login --username $NEXUS_USER --password $NEXUS_PASSWORD $NEXUS_REPO'
            }
        }
        stage('Push to Nexus Docker Repo') {
            steps {
                sh 'docker push $NEXUS_REPO/petclinicapps'
            }
        }
        stage('Trivy image Scan') {
            steps {
                sh "trivy image $NEXUS_REPO/petclinicapps > trivyfs_image.json"
            }
        }
        stage('Trivy report slack notification') {
            steps {
                slackSend channel: '24th-february-auto-discovery-project', message: 'Image Security Scan report generated and waiting for review before approval ', teamDomain: 'Cloudhight', tokenCredentialId: 'slack-cred'
            }
        }
        stage('Security cleared Approval (trivy)') {
            steps {
                timeout(activity: true, time: 10) {
                    input message: 'Needs Approval ', submitter: 'admin'
                }
            }
        }
        stage('Deploy to stage') {
            steps {
                sshagent(['ssh-node']) {
                    sh 'ssh -t -t ec2-user@$ANSIBLE_IP -o strictHostKeyChecking=no "ansible-playbook -i /etc/ansible/stage-hosts /etc/ansible/stage-playbook.yml"'
                }
            }
        }
        stage('check stage website availability') {
            steps {
                 sh "sleep 90"
                 sh "curl -s -o /dev/null -w \"%{http_code}\" https://stage.hullerdata.com"
                script {
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://stage.hullerdata.com", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "The stage petclinic java application is up and running with HTTP status code ${response}.", tokenCredentialId: 'slack-cred')
                    } else {
                        slackSend(color: 'danger', message: "The stage petclinic java application appears to be down with HTTP status code ${response}.", tokenCredentialId: 'slack-cred')
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
                sshagent(['ssh-node']) {
                    sh 'ssh -t -t ec2-user@$ANSIBLE_IP -o strictHostKeyChecking=no "ansible-playbook -i /etc/ansible/prod-hosts /etc/ansible/prod-playbook.yml"'
                }
            }
        }
        stage('check prod website availability') {
            steps {
                 sh "sleep 90"
                 sh "curl -s -o /dev/null -w \"%{http_code}\" https://prod.hullerdata.com"
                script {
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://prod.hullerdata.com", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "The prod petclinic java application is up and running with HTTP status code ${response}.", tokenCredentialId: 'slack-cred')
                    } else {
                        slackSend(color: 'danger', message: "The prod petclinic java application appears to be down with HTTP status code ${response}.", tokenCredentialId: 'slack-cred')
                    }
                }
            }
        }
    }
}
    
