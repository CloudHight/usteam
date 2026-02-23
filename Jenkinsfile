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
       

    // stage ('Deploying to Stage Environment') {

            steps {

               script {

                  // Start SSM session to bastion with port forwarding

                  sh '''

                    aws ssm start-session \

                      --target ${BASTION_ID} \

                      --region ${AWS_REGION} \

                      --document-name AWS-StartPortForwardingSession \

                      --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \

                      &

                    sleep 5

                  '''



                  // SSH into Bastion (via local port 9999), then hop to Ansible server

                  sshagent(['bastion-key', 'ansible-key']) {

                    sh '''

                      ssh -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \

                        "ssh -o StrictHostKeyChecking=no ec2-user@${ANSIBLE_IP} \

                          'ansible-playbook -i /etc/ansible/stage_hosts /etc/ansible/deployment.yml'"

                    '''

                  }

                   Kill the SSM session after deploy

                  sh 'pkill -f "aws ssm start-session"'

                }

              }

            }


//         stage('Deploying to Stage Environment') {
//   steps {
//     script {

      // Suspend ASG
//       sh '''
//         aws autoscaling suspend-processes \
//           --auto-scaling-group-name petclinicapp-stage-asg \
//           --scaling-processes AlarmNotification ScheduledActions \
//           --region ${AWS_REGION}
//       '''

       // Start SSM tunnel
//       sh '''
//         aws ssm start-session \
//           --target ${BASTION_ID} \
//           --region ${AWS_REGION} \
//           --document-name AWS-StartPortForwardingSession \
//           --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
//           &
//         sleep 5
//       '''

       // Bastion → Ansible → Deploy
//       sshagent(['bastion-key', 'ansible-key']) {
//         sh '''
//           ssh -A -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \
//             "ssh -A -o StrictHostKeyChecking=no ec2-user@${ANSIBLE_IP} \
//               'ansible-playbook -i /etc/ansible/stage_hosts /etc/ansible/deployment.yml'"
//         '''
//       }

      // Cleanup SSM
//       sh 'pkill -f "aws ssm start-session" || true'

     // Resume ASG
//       sh '''
//         aws autoscaling resume-processes \
//           --auto-scaling-group-name petclinicapp-stage-asg \
//           --region ${AWS_REGION}
//       '''
//     }
//   }
// }
//         stage('Deploying to Stage Environment') {
//     steps {
//         script {

            // Start SSM session in background (non-blocking)
//             sh '''
//               aws ssm start-session \
//                 --target $BASTION_ID \
//                 --region $AWS_REGION \
//                 --document-name AWS-StartPortForwardingSession \
//                 --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
//                 > /tmp/ssm-stage.log 2>&1 &

//               echo "Waiting for port forwarding to be ready..."
//               for i in {1..15}; do
//                 nc -z localhost 9999 && break
//                 sleep 1
//               done
//             '''

//             // SSH into Bastion (via port 9999), then hop to Ansible server
//             sshagent(['bastion-key', 'ansible-key']) {
//                 sh '''
//                   ssh -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \
//                     "ssh -o StrictHostKeyChecking=no ec2-user@$ANSIBLE_IP \
//                       'ansible-playbook -i /etc/ansible/stage_hosts /etc/ansible/deployment.yml'"
//                 '''
//             }

            // Clean up SSM session
//             sh '''
//               pkill -f "aws ssm start-session" || true
//             '''
//         }
//     }
// }
        
//       stage ('Deploying to Stage Environment') {
// steps {
// script {
 // Start SSM session to bastion with port forwarding
// sh '''
//                    aws ssm start-session \
//                      --target ${BASTION_ID} \
//                      --region ${AWS_REGION} \
//                      --document-name AWS-StartPortForwardingSession \
//                      --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
//                      &
//                    sleep 5
//                  '''

 // SSH into Bastion (via local port 9999), then hop to Ansible server
// sshagent(['bastion-key', 'ansible-key']) {
// sh '''
//                      ssh -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \
//                        "ssh -o StrictHostKeyChecking=no ec2-user@${ANSIBLE_IP} \
//                          'ansible-playbook -i /etc/ansible/stage_hosts /etc/ansible/deployment.yml'"
//                    '''
// }
 // Kill the SSM session after deploy
// sh 'pkill -f "aws ssm start-session"'
// }
// }
// }


//        stage ('Deploying to Stage Environment') {
//             steps {
//                script {
                  // Start SSM session to bastion with port forwarding
//                   sh '''
//                     aws ssm start-session \
//                       --target ${BASTION_ID} \
//                       --region ${AWS_REGION} \
//                       --document-name AWS-StartPortForwardingSession \
//                       --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
//                       &
//                    # Wait until port 9999 is ready
// while ! nc -z localhost 9999; do
//   sleep 1
// done
//                   '''

                  // SSH into Bastion (via local port 9999), then hop to Ansible server
//                   sshagent(['bastion-key', 'ansible-key']) {
//                     sh '''
//                       ssh -o StrictHostKeyChecking=no -p 9999 ubuntu@localhost \
//                         "ssh -o StrictHostKeyChecking=no ec2-user@${ANSIBLE_IP} \
//                           'ansible-playbook -i /etc/ansible/stage_hosts /etc/ansible/deployment.yml'"
//                     '''
//                   }
//                   // Kill the SSM session after deploy
//                   sh 'pkill -f "aws ssm start-session"'
//                 }
//               }
//             }
        stage('Check Stage Website Availability') {
            steps {
                script {
                    sh 'sleep 90'
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://stage.odochidevops.space", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "Stage Petclinic is UP with HTTP ${response}", tokenCredentialId: 'slack-bot-token')
                    } else {
                        slackSend(color: 'danger', message: "Stage Petclinic is DOWN with HTTP ${response}", tokenCredentialId: 'slack-bot-token')
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
        
        stage ('Deploying to prod Environment') {
    steps {
        script {
            sh """
                aws ssm start-session \
                  --target ${env.BASTION_ID} \
                  --region ${env.AWS_REGION} \
                  --document-name AWS-StartPortForwardingSession \
                  --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' &
                sleep 5
            """

            sshagent(['bastion-key', 'ansible-key']) {
                sh """
                    ssh -o StrictHostKeyChecking=no \
                        -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ubuntu@localhost -p 9999" \
                        ec2-user@${env.ANSIBLE_IP} \
                        "ansible-playbook -i /etc/ansible/prod_hosts /etc/ansible/deployment.yml"
                """
            }

            sh 'pkill -f "aws ssm start-session"'
        }
    }
}
        // stage ('Deploying to prod Environment') {
        //   steps {
        //       script {
                 // Start SSM session to bastion with port forwarding for SSH (port 22)
        //         sh '''
        //           aws ssm start-session \
        //             --target ${BASTION_ID} \
        //             --region ${AWS_REGION} \
        //             --document-name AWS-StartPortForwardingSession \
        //             --parameters '{"portNumber":["22"],"localPortNumber":["9999"]}' \
        //             &
        //           sleep 5  # Wait for port forwarding to establish
        //         '''
                 // SSH through the tunnel to Ansible server on port 22
        //         sshagent(['bastion-key', 'ansible-key']) {
        //           sh '''
        //             ssh -o StrictHostKeyChecking=no \
        //                 -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ubuntu@localhost -p 9999" \
        //                 ec2-user@${ANSIBLE_IP} \
        //                 "ansible-playbook -i /etc/ansible/prod_hosts /etc/ansible/deployment.yml"
        //           '''
        //         }
                 // Terminate the SSM session
        //         sh 'pkill -f "aws ssm start-session"'
        //       }
        //   }
        // }
        stage('Check Prod Website Availability') {
            steps {
                script {
                    sh 'sleep 90'
                    def response = sh(script: "curl -s -o /dev/null -w \"%{http_code}\" https://prod.odochidevops.space", returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "Prod Petclinic is UP with HTTP ${response}", tokenCredentialId: 'slack-bot-token')
                    } else {
                        slackSend(color: 'danger', message: "Prod Petclinic is DOWN with HTTP ${response}", tokenCredentialId: 'slack-bot-token')
                    }
                }
            }
        }
    }
}
         