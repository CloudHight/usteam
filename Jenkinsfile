pipeline {
    agent any
    environment {
        NEXUS_USER = credentials('nexus-docker-username')
        NEXUS_PASSWORD = credentials('nexus-docker-password')
        NEXUS_REPO = credentials('nexus-docker-url')
        ANSIBLE_IP = credentials('ansible-ip')
        NVD_API_KEY = credentials('nvd-key')
        BASTION_ID = credentials('bastion-id')
        AWS_REGION = 'eu-west-3'
    }
    triggers {
        pollSCM('* * * * *') // every minute
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
                dependencyCheck(
                    additionalArguments: "--scan ./ --disableYarnAudit --disableNodeAudit",
                    odcInstallation: 'DP-Check'
                )
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
                credentialsId: 'nexus-maven-cred',
                groupId: 'Petclinic',
                nexusUrl: 'nexus.odochidevops.space',
                nexusVersion: 'nexus3',
                protocol: 'https',
                repository: 'nexus-maven-repo',
                version: '1.0'
            }
        }
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $NEXUS_REPO/nexus-docker-repo/apppetclinic .'
            }
        }
        stage('Log Into Nexus Docker Repo') {
            steps {
                sh 'docker login --username $NEXUS_USER --password $NEXUS_PASSWORD $NEXUS_REPO'
            }
        }
        stage('Trivy image Scan') {
            steps {
                sh "trivy image -f table $NEXUS_REPO/nexus-docker-repo/apppetclinic > trivyfs.txt"
            }
        }
        stage('Push to Nexus Docker Repo') {
            steps {
                sh 'docker push $NEXUS_REPO/nexus-docker-repo/apppetclinic'
            }
        }
        stage('Prune Docker Images') {
            steps {
                sh 'docker image prune -a -f'
            }
        }
        stage('Deploying to Stage Environment') {
    steps {
        script {

            // 1️⃣ Suspend Auto Scaling (CRITICAL FIX)
            sh '''
              aws autoscaling suspend-processes \
                --auto-scaling-group-name petclinicapp-stage-asg \
                --scaling-processes AlarmNotification ScheduledActions \
                --region ${AWS_REGION}
            '''

            // 2️⃣ Start SSM session to bastion with port forwarding
            sh '''
              aws ssm start-session \
                --target ${BASTION_ID} \
                --region ${AWS_REGION} \
                --document-name AWS-StartPortForwardingSession \
                --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
                &
              sleep 5
            '''

            // 3️⃣ SSH into Bastion → Ansible server (UNCHANGED tutor logic)
            sshagent(['bastion-key', 'ansible-key']) {
                sh '''
                  ssh -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \
                    "ssh -o StrictHostKeyChecking=no ec2-user@${ANSIBLE_IP} \
                      'ansible-playbook -i /etc/ansible/stage_hosts /etc/ansible/deployment.yml'"
                '''
            }

            // 4️⃣ Kill SSM session (cleanup)
            sh 'pkill -f "aws ssm start-session" || true'

            // 5️⃣ Resume Auto Scaling
            sh '''
              aws autoscaling resume-processes \
                --auto-scaling-group-name petclinicapp-stage-asg \
                --region ${AWS_REGION}
            '''
        }
    }
}

        //  stage ('Deploying to Stage Environment') {
        //     steps {
        //        script {
        //           // Start SSM session to bastion with port forwarding
        //           sh '''
        //             aws ssm start-session \
        //               --target ${BASTION_ID} \
        //               --region ${AWS_REGION} \
        //               --document-name AWS-StartPortForwardingSession \
        //               --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
        //               &
        //             sleep 5
        //           '''

                  // SSH into Bastion (via local port 9999), then hop to Ansible server
        //           sshagent(['bastion-key', 'ansible-key']) {
        //             sh '''
        //               ssh -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \
        //                 "ssh -o StrictHostKeyChecking=no ec2-user@${ANSIBLE_IP} \
        //                   'ansible-playbook -i /etc/ansible/stage_hosts /etc/ansible/deployment.yml'"
        //             '''
        //           }
        //        }
        //     }
        // }
               
        // stage('Deploying to Stage Environment') {
        //     steps {
        //         script {
        //             sh """
        //                 nohup aws ssm start-session \
        //                     --target ${BASTION_ID} \
        //                     --region ${AWS_REGION} \
        //                     --document-name AWS-StartPortForwardingSession \
        //                     --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
        //                 > ssm.log 2>&1 &
        //             """
        //             sh 'sleep 15'
        //             sh """
        //                 ssh -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \
        //                     "ssh -o StrictHostKeyChecking=no ec2-user@${ANSIBLE_IP} \
        //                         'ansible-playbook -i /etc/ansible/stage_hosts /etc/ansible/deployment.yml'"
        //             """
        //             sh 'pkill -f "aws ssm start-session" || true'
        //         }
        //     }
        // }
        stage('Check Stage Website Availability') {
            steps {
                script {
                    sh 'sleep 90'
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://stage.odochidevops.space", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "Stage Petclinic is UP with HTTP ${response}", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "Stage Petclinic is DOWN with HTTP ${response}", tokenCredentialId: 'slack')
                    }
                }
            }
        }
        stage('Request for Approval') {
            steps {
                timeout(activity: true, time: 10) {
                    input message: 'Needs Approval', submitter: 'admin'
                }
            }
        }
        stage('Deploying to Prod Environment') {
            steps {
                script {
                    sh """
                        nohup aws ssm start-session \
                            --target ${BASTION_ID} \
                            --region ${AWS_REGION} \
                            --document-name AWS-StartPortForwardingSession \
                            --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
                        > ssm.log 2>&1 &
                    """
                    sh 'sleep 15'
                    sh """
                        ssh -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \
                            "ssh -o StrictHostKeyChecking=no ec2-user@${ANSIBLE_IP} \
                                'ansible-playbook -i /etc/ansible/prod_hosts /etc/ansible/deployment.yml'"
                    """
                    sh 'pkill -f "aws ssm start-session" || true'
                }
            }
        }
        stage('Check Prod Website Availability') {
            steps {
                script {
                    sh 'sleep 90'
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://prod.odochidevops.space", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "Prod Petclinic is UP with HTTP ${response}", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "Prod Petclinic is DOWN with HTTP ${response}", tokenCredentialId: 'slack')
                    }
                }
            }
        }
    }
}
         