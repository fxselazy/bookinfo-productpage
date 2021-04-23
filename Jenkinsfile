// Define variables
def scmVars

// Start Pipeline
pipeline {

  // Configure Jenkins Slave
  agent {
    // Use Kubernetes as dynamic Jenkins Slave
    kubernetes {
      // Kubernetes Manifest File to spin up Pod to do build
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: docker
    image: docker:19.03.5-dind
    command:
    - dockerd
    - --host=unix:///var/run/docker.sock
    - --host=tcp://0.0.0.0:2375
    - --storage-driver=overlay2
    tty: true
    securityContext:
        privileged: true
  - name: helm
    image: lachlanevenson/k8s-helm:v3.0.2
    command:
    - cat
    tty: true
  - name: skan
    image: alcide/skan:v0.9.0-debug
    command:
    - cat
    tty: true
  - name: java-node
    image: saroma/jdk11-python3:latest
    command:
    - cat
    tty: true
    volumeMounts:
    - mountPath: /home/jenkins/dependency-check-data
      name: dependency-check-data
  volumes:
  - name: dependency-check-data
    hostPath:
      path: /tmp/dependency-check-data
"""
    } // End kubernetes
  } // End agent
    environment {
    ENV_NAME = "${BRANCH_NAME == "master" ? "uat" : "${BRANCH_NAME}"}"
    SCANNER_HOME = tool 'sonarqube-scanner'
    PROJECT_KEY = "fuse-bookinfo-productpage"
    PROJECT_NAME = "fuse-bookinfo-productpage"
  }

  // Start Pipeline
  stages {

    // ***** Stage Clone *****
    stage('Clone productpage source code') {
      // Steps to run build
      steps {
        // Run in Jenkins Slave container
        container('jnlp') {
          // Use script to run
          script {
            // Git clone repo and checkout branch as we put in parameter
            scmVars = git branch: "${BRANCH_NAME}",
                          credentialsId: 'bookinfo-git-deploy-key',
                          url: 'git@github.com:fxselazy/bookinfo-productpage.git'
          } // End script
        } // End container
      } // End steps
    } // End stage

    // ***** Stage sKan *****
    stage('sKan') {
        steps {
            container('helm') {
                script {
                    // Generate k8s-manifest-deploy.yaml for scanning
                    sh "helm template -f k8s/helm-values/values-bookinfo-${ENV_NAME}-productpage.yaml \
                        --set extraEnv.COMMIT_ID=${scmVars.GIT_COMMIT} \
                        --namespace fuse-bookinfo-${ENV_NAME} fuse-productpage-${ENV_NAME} k8s/helm \
                        > k8s-manifest-deploy.yaml"
                }
            } // End container
            container('skan') {
                script {
                    // Scanning with sKan
                    sh "/skan manifest -f k8s-manifest-deploy.yaml"
                    // Keep report as artifacts
                    archiveArtifacts artifacts: 'skan-result.html'
                    sh "rm k8s-manifest-deploy.yaml"
                }
            } // End container
        }  // End steps
    } // End stage

    // ***** Stage Sonarqube *****
    stage('Sonarqube Scanner') {
        steps {
            container('java-node'){
                script {
                    // Authentiocation with http://sonarqube.hellodolphin.in.th
                    withSonarQubeEnv('sonarqube-scanner') {
                        // Run Sonar Scanner
                        sh '''${SCANNER_HOME}/bin/sonar-scanner \
                        -D sonar.projectKey=${PROJECT_KEY} \
                        -D sonar.projectName=${PROJECT_NAME} \
                        -D sonar.projectVersion=${BRANCH_NAME}-${BUILD_NUMBER} \
                        -D sonar.sources=./
                        '''
                    } // End withSonarQubeEnv
                    // Run Quality Gate
                    timeout(time: 1, unit: 'MINUTES') { 
                        def qg = waitForQualityGate()
                        if (qg.status != 'OK') {
                            error "Pipeline aborted due to quality gate failure: ${qg.status}"
                        }
                    } // End Timeout
                } // End script
            } // End container
        } // End steps
    } // End stage

    // ***** Stage OWASP *****
    stage('OWASP Dependency Check') {
        steps {
            container('java-node') {
                script {
                    sh '''pip3 install -r requirements.txt'''
                    // Start OWASP Dependency Check
                    dependencyCheck(
                        additionalArguments: "--data /home/jenkins/dependency-check-data --out dependency-check-report.xml",
                        odcInstallation: "dependency-check"
                    )
                    // Publish report to Jenkins
                    dependencyCheckPublisher(
                        pattern: 'dependency-check-report.xml'
                    )
                    // Remove application dependency
                    sh'''rm -rf src/node_modules src/package-lock.json'''
                } // End script
            } // End container
        } // End steps
    } // End stage

    // ***** Stage Build *****
    stage('Build productpage Docker Image and push') {
      steps {
        container('docker') {
          script {
            // Do docker login authentication
            docker.withRegistry('https://ghcr.io', 'github-registry') {
              // Do docker build and docker push
              docker.build('ghcr.io/fxselazy/bookinfo-productpage:${ENV_NAME}').push()
            } // End docker.withRegistry
          } // End script
        } // End container
      } // End steps
    } // End stage
    
    // ***** Stage Anchore *****
    stage('Anchore Engine') {
        steps {
            container('jnlp') {
                script {
                    // dend Docker Image to Anchore Analyzer
                    writeFile file: 'anchore_images' , text: "ghcr.io/fxselazy/bookinfo-productpage:${ENV_NAME}"
                    anchore name: 'anchore_images' , bailOnFail: false
                } // End script
            } // End container
        } // End steps
    } // End stages

    stage('Deploy productpage with Helm Chart') {
      steps {
        // Run on Helm container
        container('helm') {
          script {
            // Use kubeconfig from Jenkins Credential
            withKubeConfig([credentialsId: 'kubeconfig']) {
              // Run Helm upgrade
              sh "helm upgrade -i -f k8s/helm-values/values-bookinfo-${ENV_NAME}-productpage.yaml --wait \
                --set extraEnv.COMMIT_ID=${scmVars.GIT_COMMIT} \
                --namespace fuse-bookinfo-${ENV_NAME} fuse-productpage-${ENV_NAME} k8s/helm"
            } // End withKubeConfig
          } // End script
        } // End container
      } // End steps
    } // End stage


  } // End stages
} // End pipeline