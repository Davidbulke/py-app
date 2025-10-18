pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  namespace: jenkins
spec:
  containers:
    - name: jnlp
      image: jenkins/inbound-agent:3206.vb_15dcf73f6a_9-2-jdk17
      resources:
        requests:
          memory: "512Mi"
          cpu: "500m"
        limits:
          memory: "1Gi"
          cpu: "1000m"
    - name: python
      image: python:3.12-slim
      command: [sleep]
      args: [99d]
      resources:
        requests:
          memory: "1Gi"
          cpu: "500m"
        limits:
          memory: "2Gi"
          cpu: "1000m"
    - name: sonar-scanner
      image: sonarsource/sonar-scanner-cli:latest
      command: [sleep]
      args: [99d]
      resources:
        requests:
          memory: "512Mi"
          cpu: "250m"
        limits:
          memory: "1Gi"
          cpu: "500m"
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.19.0-debug
      command: ['/busybox/cat']
      tty: true
      resources:
        requests:
          memory: "2Gi"
          cpu: "1000m"
        limits:
          memory: "4Gi"
          cpu: "2000m"
    - name: trivy
      image: aquasec/trivy:0.48.3
      command: ['sleep']
      args: ['99d']
      resources:
        requests:
          memory: "512Mi"
          cpu: "250m"
        limits:
          memory: "1Gi"
          cpu: "500m"
'''
        }
    }


    environment {
        DOCKER_USERNAME = 'davidbulke'
        IMAGE_NAME = 'py-app'
        GIT_COMMIT_SHORT = sh(script: "git rev-parse --short=8 HEAD", returnStdout: true).trim()
        GIT_BRANCH = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
        IMAGE_TAG = "${GIT_COMMIT_SHORT}-${BUILD_NUMBER}"
        FULL_IMAGE_NAME = "${DOCKER_USERNAME}/${IMAGE_NAME}:${IMAGE_TAG}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo "Pipeline starting for branch ${GIT_BRANCH} commit ${GIT_COMMIT_SHORT}"
                sh 'ls -la'
            }
        }


        stage('Trivy Security Scan - Source Code') {
            steps {
                container('trivy') {
                    sh '''
                        trivy fs --exit-code 0 --severity HIGH,CRITICAL --no-progress . 
                        echo "Source code security scan completed!"
                    '''
                }
            }
        }
        
        stage('Install Dependencies') {
            steps {
                container('python') {
                    sh 'pip install -r requirements.txt'
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                container('python') {
                    sh 'pytest --junitxml=pytest-results.xml'
                    junit 'pytest-results.xml'
                }
            }
        }


        stage('SonarQube Code Analysis') {
            steps {
                withVault([
                    vaultSecrets: [
                        [
                            path: 'secret/jenkins/sonarqube',
                            engineVersion: 2,
                            secretValues: [
                                [envVar: 'SONAR_TOKEN', vaultKey: 'token'],
                                [envVar: 'SONAR_URL', vaultKey: 'url']
                            ]
                        ]
                    ]
                ]) {
                    container('sonar-scanner') {
                        sh '''
                            sonar-scanner \
                              -Dsonar.projectKey=python-app \
                              -Dsonar.projectName="Python Flask Application" \
                              -Dsonar.projectVersion=${GIT_COMMIT_SHORT} \
                              -Dsonar.sources=helloworld \
                              -Dsonar.python.version=3.12 \
                              -Dsonar.sourceEncoding=UTF-8 \
                              -Dsonar.exclusions=**/*test*/**,**/__pycache__/**,**/venv/**,.git/** \
                              -Dsonar.host.url=${SONAR_URL} \
                              -Dsonar.token=${SONAR_TOKEN}
                        '''
                        echo "✅ SonarQube code quality analysis completed!"
                    }
                }
            }
        }
        
        stage('Build and Push Docker Image') {
            steps {
                withVault([
                    vaultSecrets: [
                        [
                            path: 'secret/jenkins/dockerhub',
                            engineVersion: 2,
                            secretValues: [
                                [envVar: 'DOCKER_USER', vaultKey: 'username'],
                                [envVar: 'DOCKER_PASS', vaultKey: 'token']
                            ]
                        ]
                    ]
                ]) {
                    container('kaniko') {
                        script {
                            echo "🔐 Fetching DockerHub credentials from Vault..."
                            
                            sh '''
                                mkdir -p /kaniko/.docker
                                echo "{\\"auths\\":{\\"https://index.docker.io/v1/\\":{\\"username\\":\\"${DOCKER_USER}\\",\\"password\\":\\"${DOCKER_PASS}\\"}}}" > /kaniko/.docker/config.json
                            '''
                            
                            def tags = [
                                "--destination=${FULL_IMAGE_NAME}"
                            ]
                            if (env.GIT_BRANCH == 'main') {
                                tags.add("--destination=${DOCKER_USERNAME}/${IMAGE_NAME}:latest")
                            }
                            def tagString = tags.join(' ')
                            
                            echo "🐳 Building and pushing image with Kaniko..."
                            sh """
                                /kaniko/executor \
                                    --context=\${PWD} \
                                    --dockerfile=\${PWD}/Dockerfile \
                                    ${tagString} \
                                    --cache=true \
                                    --cache-ttl=24h \
                                    --compressed-caching=false \
                                    --snapshot-mode=redo \
                                    --log-format=text \
                                    --verbosity=info
                            """
                            
                            echo "✅ Image successfully pushed: ${FULL_IMAGE_NAME}"
                        }
                    }
                }
            }
        }


        stage('Trivy Security Scan - Docker Image') {
            steps {
                container('trivy') {
                    sh """
                        trivy image --exit-code 0 --severity CRITICAL --no-progress ${FULL_IMAGE_NAME}
                        echo "Docker image security scan finished!"
                    """
                }
            }
        }
    }

        stage('Update GitOps Manifests') {
            steps {
                withVault([
                    vaultSecrets: [
                        [
                            path: 'secret/jenkins/github',
                            engineVersion: 2,
                            secretValues: [
                                [envVar: 'GITHUB_TOKEN', vaultKey: 'token'],
                                [envVar: 'GITHUB_USER', vaultKey: 'username']
                            ]
                        ]
                    ]
                ]) {
                    script {
                        echo "📝 Updating Kubernetes manifests in GitOps repository..."
                        
                        sh '''
                            # Configure git
                            git config --global user.email "jenkins@ci.local"
                            git config --global user.name "Jenkins CI"
                            
                            # Clone manifests repo
                            rm -rf python-app-manifests || true
                            git clone https://${GITHUB_TOKEN}@github.com/davidbulke/python-app-manifests.git
                            cd python-app-manifests
                            
                            # Update image tag in deployment
                            sed -i "s|image: davidbulke/py-app:.*|image: ${FULL_IMAGE_NAME}|g" k8s/base/deployment.yaml
                            
                            # Check if anything changed
                            if git diff --quiet; then
                                echo "No changes to manifests"
                            else
                                # Commit and push changes
                                git add k8s/base/deployment.yaml
                                git commit -m "Update image to ${FULL_IMAGE_NAME}

        Build: #${BUILD_NUMBER}
        Commit: ${GIT_COMMIT_SHORT}
        Branch: ${GIT_BRANCH}"
                                
                                git push https://${GITHUB_TOKEN}@github.com/davidbulke/python-app-manifests.git main
                                
                                echo "✅ GitOps manifests updated successfully!"
                            fi
                            
                            cd ..
                            rm -rf python-app-manifests
                        '''
                    }
                }
            }
        }



    post {
        success {
            script {
                def latestInfo = (env.GIT_BRANCH == 'main') ? 
                    "\n   - ${DOCKER_USERNAME}/${IMAGE_NAME}:latest" : 
                    ""
                    
                echo """
                    
                        CI/CD PIPELINE SUCCESS! 🎉        
                    
                    ✅ All Stages Completed:
                    - Source code security scanned (Trivy)
                    - Python dependencies installed
                    - Unit tests executed (pytest)
                    - Code quality analyzed (SonarQube)
                    - Docker image built (Kaniko)
                    - Image security validated (Trivy)
                    - Image pushed to Docker Hub

                    🔐 Security & Quality:
                    - All credentials from HashiCorp Vault
                    - SonarQube scans
                    - Zero secrets in code or logs

                    🐳 Docker Images Published:
                    - ${FULL_IMAGE_NAME}${latestInfo}

                    📊 Build Info:
                    - Build: #${BUILD_NUMBER}
                    - Branch: ${GIT_BRANCH}
                    - Commit: ${GIT_COMMIT_SHORT}
                    - Tag: ${IMAGE_TAG}
                    
                    🔗 Pull Command:
                    docker pull ${FULL_IMAGE_NAME}
                """
            }
        }
        
        failure {
            echo """
            
                ❌ PIPELINE FAILED
            
            Stage: ${env.STAGE_NAME}
            Build: #${BUILD_NUMBER}
            Branch: ${GIT_BRANCH}
            Commit: ${GIT_COMMIT_SHORT}
            
            Check logs above for error details.
            
            """
        }
        
        always {
            echo "Pipeline execution completed for build #${BUILD_NUMBER}"
        }
    }
}
