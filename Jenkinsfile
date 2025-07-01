pipeline {
    agent any

    environment {
        NEXUS_REPO        = credentials('nexus-ip-port')
        NEXUS_USER        = credentials('nexus-username')
        NEXUS_PASSWORD    = credentials('nexus-password')
        NVD_API_KEY       = credentials('nvd-key')
        BASTION_IP        = credentials('bastion-ip')
        ANSIBLE_IP        = credentials('ansible-ip')
        AWS_REGION        = 'eu-west-3'
    }

    tools {
        terraform 'terraform' // Make sure this matches your Jenkins global tool name
    }

    parameters {
        choice(name: 'action', choices: ['apply', 'destroy'], description: 'Terraform action to perform')
    }

    triggers {
        pollSCM('* * * * *')
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', credentialsId: 'git-cred', url: 'https://github.com/Chijiokeproject/jenkinsfile1.git'
            }
        }

        stage('Code Analysis') {
    steps {
        script {
            try {
                withSonarQubeEnv('Sonarqube') {
                    sh 'mvn sonar:sonar'
                }
            } catch (e) {
                echo "SonarQube scan failed: ${e}"
                currentBuild.result = 'FAILURE'
            }
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
                    dependencyCheck additionalArguments: args, odcInstallation: 'DP-Check'
                }
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }

        stage('Build Artifact') {
            steps {
                sh 'mvn clean package -DskipTests -Dcheckstyle.skip'
            }
        }

        stage('Upload Artifact to Nexus') {
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

        stage('Login to Docker Registry') {
            steps {
                sh 'echo "$NEXUS_PASSWORD" | docker login --username "$NEXUS_USER" --password-stdin https://$NEXUS_REPO'
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh 'trivy image -f table $NEXUS_REPO/petclinicapps:latest > trivyfs.txt'
            }
        }

        stage('Push Docker Image') {
            steps {
                sh 'docker push $NEXUS_REPO/petclinicapps:latest'
            }
        }

        stage('Prune Docker Images') {
            steps {
                sh 'docker image prune -f'
            }
        }

        stage('Deploy to Staging') {
            steps {
                sshagent(['ansible-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" ec2-user@$ANSIBLE_IP 'mkdir -p /home/ec2-user/ansible'

                        scp -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" deployment.yml ec2-user@$ANSIBLE_IP:/home/ec2-user/ansible/

                        ssh -tt -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" ec2-user@$ANSIBLE_IP 'sudo mv /home/ec2-user/ansible/deployment.yml /etc/ansible/ && ansible-playbook /etc/ansible/deployment.yml'
                    '''
                }
            }
        }

        stage('Check Stage Website') {
            steps {
                sh 'sleep 60'
                script {
                    def response = sh(script: 'curl -s -o /dev/null -w "%{http_code}" https://stage.chijiokedevops.space', returnStdout: true).trim()
                    if (response == '200') {
                        slackSend(color: 'good', message: "✅ Stage is UP (HTTP ${response})", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "🚨 Stage is DOWN (HTTP ${response})", tokenCredentialId: 'slack')
                    }
                }
            }
        }

        stage('Deploy to Prod') {
            steps {
                sshagent(['ansible-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" ec2-user@$PROD_ANSIBLE_IP 'mkdir -p /home/ec2-user/ansible'

                        scp -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" deployment.yml ec2-user@$PROD_ANSIBLE_IP:/home/ec2-user/ansible/

                        ssh -tt -o StrictHostKeyChecking=no -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" ec2-user@$PROD_ANSIBLE_IP 'sudo mv /home/ec2-user/ansible/deployment.yml /etc/ansible/ && ansible-playbook /etc/ansible/deployment.yml'
                    '''
                }
            }
        }

        stage('Check Prod Website') {
            steps {
                sh 'sleep 60'
                script {
                    def response = sh(script: 'curl -s -o /dev/null -w "%{http_code}" https://prod.chijiokedevops.space', returnStdout: true).trim()
                    if (response == '200') {
                        slackSend(color: 'good', message: "✅ Prod is UP (HTTP ${response})", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "🚨 Prod is DOWN (HTTP ${response})", tokenCredentialId: 'slack')
                    }
                }
            }
        }
    }

    post {
        success {
            slackSend(color: 'good', message: "✅ Jenkins build #${env.BUILD_NUMBER} succeeded!", tokenCredentialId: 'slack')
        }
        failure {
            slackSend(color: 'danger', message: "❌ Jenkins build #${env.BUILD_NUMBER} failed.", tokenCredentialId: 'slack')
        }
        always {
            cleanWs()
        }
    }
}
