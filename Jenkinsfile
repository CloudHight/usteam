pipeline {
    agent any

    environment {
        NEXUS_REPO       = credentials('nexus-ip-port')
        NEXUS_USER       = credentials('nexus-username')
        NEXUS_PASSWORD   = credentials('nexus-password')
        NVD_API_KEY      = credentials('nvd-key')
        BASTION_IP       = credentials('bastion-ip')
        ANSIBLE_IP       = credentials('ansible-ip')
        BASTION_ID       = credentials('bastion-id')
        PROD_BASTION_IP  = credentials('prod-bastion-ip')
        PROD_ANSIBLE_IP  = credentials('prod-ansible-ip')
        AWS_REGION       = 'eu-west-3'
    }

    tools {
        terraform 'terraform'  // git removed here, since it's not a tool in this context
    }

    parameters {
        choice(name: 'action', choices: ['apply', 'destroy'], description: 'Select the action to perform')
    }

    triggers {
        pollSCM('* * * * *')
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Code Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh 'mvn sonar:sonar'
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Dependency Check') {
            steps {
                script {
                    def args = "--scan ./ --disableYarnAudit --disableNodeAudit --nvdApiKey=${env.NVD_API_KEY}"
                    dependencyCheck(
                        additionalArguments: args,
                        odcInstallation: 'DP-Check'
                    )
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
                nexusArtifactUploader(
                    artifacts: [[
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
                )
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $NEXUS_REPO/petclinicapps:latest .'
            }
        }

        stage('Login to Nexus Docker Repo') {
            steps {
                sh 'echo "$NEXUS_PASSWORD" | docker login --username "$NEXUS_USER" --password-stdin https://$NEXUS_REPO'
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh 'trivy image -f table $NEXUS_REPO/petclinicapps:latest > trivyfs.txt'
            }
        }

        stage('Push Docker Image to Nexus') {
            steps {
                sh 'docker push $NEXUS_REPO/petclinicapps:latest'
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
                    sh '''
                        set -e
                        ssh -o StrictHostKeyChecking=no \
                            -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                            ec2-user@$ANSIBLE_IP 'mkdir -p /home/ec2-user/ansible'

                        scp -o StrictHostKeyChecking=no \
                            -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                            deployment.yml ec2-user@$ANSIBLE_IP:/home/ec2-user/ansible/

                        ssh -tt -o StrictHostKeyChecking=no \
                            -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                            ec2-user@$ANSIBLE_IP 'sudo mv /home/ec2-user/ansible/deployment.yml /etc/ansible/ && ansible-playbook /etc/ansible/deployment.yml'
                    '''
                }
            }
        }

        stage('Check Stage Website Availability') {
            steps {
                sh 'sleep 90'
                script {
                    def response = sh(script: 'curl -s -o /dev/null -w "%{http_code}" https://stage.chijiokedevops.space', returnStdout: true).trim()
                    if (response == "200") {
                        slackSend(color: 'good', message: "✅ Stage Petclinic is up (HTTP ${response})", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "🚨 Stage Petclinic is down (HTTP ${response})", tokenCredentialId: 'slack')
                    }
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                sshagent(['ansible-key']) {
                    sh '''
                        set -e
                        ssh -o StrictHostKeyChecking=no \
                            -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" \
                            ec2-user@$PROD_ANSIBLE_IP 'mkdir -p /home/ec2-user/ansible'

                        scp -o StrictHostKeyChecking=no \
                            -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" \
                            deployment.yml ec2-user@$PROD_ANSIBLE_IP:/home/ec2-user/ansible/

                        ssh -tt -o StrictHostKeyChecking=no \
                            -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" \
                            ec2-user@$PROD_ANSIBLE_IP 'sudo mv /home/ec2-user/ansible/deployment.yml /etc/ansible/ && ansible-playbook /etc/ansible/deployment.yml'
                    '''
                }
            }
        }

        stage('Check Prod Website Availability') {
            steps {
                sh 'sleep 90'
                script {
                    def response = sh(script: 'curl -s -o /dev/null -w "%{http_code}" https://prod.chijiokedevops.space', returnStdout: true).trim()
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
