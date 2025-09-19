pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }

  environment {
    // --- Repo & Image ---
    GIT_URL        = 'https://github.com/seikyrooo/learn-jenkins.git'
    GIT_BRANCH     = 'main'
    REGISTRY       = '192.168.7.75:5000'
    IMAGE_NAME     = 'jenkins-tes2'
    // --- K8s ---
    KUBE_NAMESPACE = 'default'
    DEPLOYMENT_NAME= 'go-api'
    CONTAINER_NAME = 'go-api'
    // --- Credentials (ubah kalau perlu) ---
    GIT_CRED_ID    = 'none'            // kalau repo public, bisa kosongkan & pilih "- none -"
    DOCKER_CRED_ID = 'dkp-docker-registry'
    KUBE_CONFIG    = '/var/lib/jenkins/.kube/config' // kubeconfig sudah ada di host
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: "${GIT_BRANCH}", url: "${GIT_URL}", credentialsId: "${GIT_CRED_ID}"
        script {
          env.SHORT_SHA = sh(returnStdout: true, script: "git rev-parse --short HEAD").trim()
          currentBuild.displayName = "#${env.BUILD_NUMBER} ${env.SHORT_SHA}"
        }
      }
    }

    // stage('Unit Test (Dockerized)') {
    //   steps {
    //     sh '''
    //       set -euxo pipefail
    //       docker run --rm -v "$PWD":/src -w /src golang:1.22 go test ./...
    //     '''
    //   }
    // }

    stage('Docker Login') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${DOCKER_CRED_ID}", usernameVariable: 'REG_USER', passwordVariable: 'REG_PASS')]) {
          sh 'echo "$REG_PASS" | docker login "$REGISTRY" -u "$REG_USER" --password-stdin'
        }
      }
    }

    stage('Build Image') {
      steps {
        sh '''
          set -euxo pipefail
          docker build --pull -t ${REGISTRY}/${IMAGE_NAME}:${SHORT_SHA} .
          docker tag ${REGISTRY}/${IMAGE_NAME}:${SHORT_SHA} ${REGISTRY}/${IMAGE_NAME}:latest
        '''
      }
    }

    stage('Push Image') {
      steps {
        sh '''
          set -euxo pipefail
          docker push ${REGISTRY}/${IMAGE_NAME}:${SHORT_SHA}
          docker push ${REGISTRY}/${IMAGE_NAME}:latest
        '''
      }
    }

    stage('Deploy to Kubernetes') {
      steps {
        script {
          try {
            sh '''
              set -euxo pipefail
              # apply dulu (pertama kali) / sync resource lain
              kubectl --kubeconfig=${KUBE_CONFIG} -n ${KUBE_NAMESPACE} apply -f k8s/
              # update image ke tag unik -> trigger rolling update
              kubectl --kubeconfig=${KUBE_CONFIG} -n ${KUBE_NAMESPACE} \
                set image deploy/${DEPLOYMENT_NAME} ${CONTAINER_NAME}=${REGISTRY}/${IMAGE_NAME}:${SHORT_SHA} --record
              # tunggu rollout selesai
              kubectl --kubeconfig=${KUBE_CONFIG} -n ${KUBE_NAMESPACE} \
                rollout status deploy/${DEPLOYMENT_NAME} --timeout=180s
            '''
          } catch (err) {
            sh '''
              set -euxo pipefail
              kubectl --kubeconfig=${KUBE_CONFIG} -n ${KUBE_NAMESPACE} rollout undo deploy/${DEPLOYMENT_NAME} || true
            '''
            throw err
          }
        }
      }
    }
  }

  post {
    always {
      sh 'docker logout ${REGISTRY} || true'
      archiveArtifacts artifacts: 'k8s/*.yaml', onlyIfSuccessful: false
    }
    success { echo "✅ Deployed ${REGISTRY}/${IMAGE_NAME}:${SHORT_SHA} to ${KUBE_NAMESPACE}" }
    failure { echo "❌ Deployment failed. Check logs above." }
  }
}