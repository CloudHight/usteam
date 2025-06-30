pipeline {
    agent any

    environment {
        AWS_REGION = 'eu-west-3'
    }

    tools {
        terraform 'terraform'
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
                withSonarQubeEnv('sonarqube') {
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
                withCredentials([string(credentialsId: 'nvd-key', variable: 'NVD_API_KEY')]) {
                    script {
                        def args = "--scan ./ --disableYarnAudit --disableNodeAudit --nvdApiKey=${NVD_API_KEY}"
                        dependencyCheck(
                            additionalArguments: args,
                            odcInstallation: 'DP-Check'
                        )
                    }
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
                withCredentials([string(credentialsId: 'nexus-ip-port', variable: 'NEXUS_REPO')]) {
                    sh 'docker build -t $NEXUS_REPO/petclinicapps .'
                }
            }
        }

        stage('Login to Nexus Docker Repo') {
            steps {
                withCredentials([
                    usernamePassword(credentialsId: 'nexus-cred', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASSWORD'),
                    string(credentialsId: 'nexus-ip-port', variable: 'NEXUS_REPO')
                ]) {
                    sh '''
                        echo "$NEXUS_PASSWORD" | docker login --username "$NEXUS_USER" --password-stdin https://$NEXUS_REPO
                    '''
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                withCredentials([string(credentialsId: 'nexus-ip-port', variable: 'NEXUS_REPO')]) {
                    sh 'trivy image -f table $NEXUS_REPO/petclinicapps > trivyfs.txt'
                }
            }
        }

        stage('Push Docker Image to Nexus') {
            steps {
                withCredentials([string(credentialsId: 'nexus-ip-port', variable: 'NEXUS_REPO')]) {
                    sh 'docker push $NEXUS_REPO/petclinicapps'
                }
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
                    withCredentials([
                        string(credentialsId: 'bastion-ip', variable: 'BASTION_IP'),
                        string(credentialsId: 'ansible-ip', variable: 'ANSIBLE_IP')
                    ]) {
                        sh '''
                            set -e
                            echo 'Creating ansible dir on remote and transferring deployment file...'
                            ssh -o StrictHostKeyChecking=no \
                                -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                                ec2-user@$ANSIBLE_IP 'mkdir -p /home/ec2-user/ansible'

                            scp -o StrictHostKeyChecking=no \
                                -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                                deployment.yml ec2-user@$ANSIBLE_IP:/home/ec2-user/ansible/deployment.yml

                            ssh -tt -o StrictHostKeyChecking=no \
                                -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                                ec2-user@$ANSIBLE_IP 'sudo mkdir -p /etc/ansible && sudo mv /home/ec2-user/ansible/deployment.yml /etc/ansible/deployment.yml'

                            ssh -tt -o StrictHostKeyChecking=no \
                                -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                                ec2-user@$ANSIBLE_IP 'ansible-playbook /etc/ansible/deployment.yml'
                        '''
                    }
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

        stage('Request for Approval') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input message: 'Deploy to Production?', ok: 'Yes, Deploy'
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                sshagent(['ansible-key']) {
                    withCredentials([
                        string(credentialsId: 'bastion-ip', variable: 'BASTION_IP'),
                        string(credentialsId: 'ansible-ip', variable: 'ANSIBLE_IP')
                    ]) {
                        sh '''
                            set -e
                            echo 'Creating ansible dir on remote and transferring deployment file...'
                            ssh -o StrictHostKeyChecking=no \
                                -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                                ec2-user@$ANSIBLE_IP 'mkdir -p /home/ec2-user/ansible'

                            scp -o StrictHostKeyChecking=no \
                                -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                                deployment.yml ec2-user@$ANSIBLE_IP:/home/ec2-user/ansible/deployment.yml

                            ssh -tt -o StrictHostKeyChecking=no \
                                -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                                ec2-user@$ANSIBLE_IP 'sudo mkdir -p /etc/ansible && sudo mv /home/ec2-user/ansible/deployment.yml /etc/ansible/deployment.yml'

                            ssh -tt -o StrictHostKeyChecking=no \
                                -o ProxyCommand="ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                                ec2-user@$ANSIBLE_IP 'ansible-playbook /etc/ansible/deployment.yml'
                        '''
                    }
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

    post {
        success {
            slackSend(color: 'good',
