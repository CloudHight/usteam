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
        terraform 'terraform'
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
                retry(3) {
                    git credentialsId: 'git-cred', url: 'https://github.com/Chijiokeproject/jenkinsfile1.git', branch: 'main'
                }
            }
        }

        // --- Terraform Stages ---
        stage('Terraform Init') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                dir('terraform') {
                    sh "terraform plan -out=tfplan"
                }
            }
        }

        stage('Terraform Apply or Destroy') {
            steps {
                dir('terraform') {
                    script {
                        if (params.action == 'apply') {
                            sh 'terraform apply -auto-approve tfplan'
                        } else if (params.action == 'destroy') {
                            sh 'terraform destroy -auto-approve'
                        }
                    }
                }
            }
        }

        // --- App Build & Security ---
        stage('Code Analysis') {
            steps {
                withSonarQubeEnv('Sonarqube') {
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
                    version: "${env.BUILD_NUMBER}"
                )
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $NEXUS_REPO/petclinicapps:${BUILD_NUMBER} .'
            }
        }

        stage('Login to Docker Registry') {
            steps {
                sh 'echo "$NEXUS_PASSWORD" | docker login --username "$NEXUS_USER" --password-stdin https://$NEXUS_REPO'
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh 'trivy image -f table $NEXUS_REPO/petclinicapps:${BUILD_NUMBER} > trivyfs.txt'
            }
        }

        stage('Push Docker Image') {
            steps {
                sh 'docker push $NEXUS_REPO/petclinicapps:${BUILD_NUMBER}'
            }
        }

        stage('Prune Docker Images') {
            steps {
                sh 'docker image prune -f'
            }
        }

        // --- Staging Deployment ---
        stage('Deploy to Staging') {
            steps {
                sshagent(['ansible-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no \
                          -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                          ec2-user@$ANSIBLE_IP 'mkdir -p ~/ansible'

                        scp -o StrictHostKeyChecking=no \
                          -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                          deployment.yml ec2-user@$ANSIBLE_IP:~/ansible/

                        ssh -tt -o StrictHostKeyChecking=no \
                          -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$BASTION_IP" \
                          ec2-user@$ANSIBLE_IP 'sudo mv ~/ansible/deployment.yml /etc/ansible/ && ansible-playbook /etc/ansible/deployment.yml'
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
                        slackSend(color: 'good', message: "✅ Staging site is live: HTTP ${response}", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "🚨 Staging site failed: HTTP ${response}", tokenCredentialId: 'slack')
                    }
                }
            }
        }

        // --- Production Deployment ---
        stage('Deploy to Prod') {
            steps {
                sshagent(['ansible-key']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no \
                          -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" \
                          ec2-user@$PROD_ANSIBLE_IP 'mkdir -p ~/ansible'

                        scp -o StrictHostKeyChecking=no \
                          -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" \
                          deployment.yml ec2-user@$PROD_ANSIBLE_IP:~/ansible/

                        ssh -tt -o StrictHostKeyChecking=no \
                          -o "ProxyCommand=ssh -W %h:%p -o StrictHostKeyChecking=no ec2-user@$PROD_BASTION_IP" \
                          ec2-user@$PROD_ANSIBLE_IP 'sudo mv ~/ansible/deployment.yml /etc/ansible/ && ansible-playbook /etc/ansible/deployment.yml'
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
                        slackSend(color: 'good', message: "✅ Prod site is live: HTTP ${response}", tokenCredentialId: 'slack')
                    } else {
                        slackSend(color: 'danger', message: "🚨 Prod site failed: HTTP ${response}", tokenCredentialId: 'slack')
                    }
                }
            }
        }
    }

    post {
        success {
            slackSend(color: 'good', message: "✅ Build #${env.BUILD_NUMBER} succeeded!", tokenCredentialId: 'slack')
        }
        failure {
            slackSend(color: 'danger', message: "❌ Build #${env.BUILD_NUMBER} failed.", tokenCredentialId: 'slack')
        }
        always {
            cleanWs()
        }
    }
}
