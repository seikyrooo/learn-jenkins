pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }

  environment {
    // --- Repo & Image ---
    GIT_URL          = 'https://gitlab.com/afifheryanto/dkp-go.git'
    GIT_BRANCH       = 'main'
    REGISTRY         = '192.168.7.75:5000'
    IMAGE_NAME       = 'testing-go'              // nama repo image di registry
    // --- K8s ---
    KUBE_NAMESPACE   = 'default'
    DEPLOYMENT_NAME  = 'go-api'                  // nama Deployment
    CONTAINER_NAME   = 'go-api'                  // nama container di Deployment
    // --- Credentials IDs (ubah jika namanya berbeda) ---
    GIT_CRED_ID      = 'dkp-go-pipeline'
    DOCKER_CRED_ID   = 'dkp-docker-registry'
    KUBEFILE_CRED_ID = 'kubeconfig-prod'
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

    stage('Unit Test (Dockerized)') {
      steps {
        // jalankan go test di container golang agar agent tidak wajib punya Go
        sh '''
          set -euxo pipefail
          docker run --rm -v "$PWD":/src -w /src golang:1.22 go test ./...
        '''
      }
    }

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
        withCredentials([file(credentialsId: "${KUBEFILE_CRED_ID}", variable: 'KCFG')]) {
          script {
            try {
              sh '''
                set -euxo pipefail
                # apply dulu supaya objek ada (first time) / sync manifest lain (svc, configmap, dsb)
                kubectl --kubeconfig="$KCFG" -n ${KUBE_NAMESPACE} apply -f k8s/

                # update image dengan tag unik (SHA) untuk rolling update
                kubectl --kubeconfig="$KCFG" -n ${KUBE_NAMESPACE} \
                  set image deploy/${DEPLOYMENT_NAME} ${CONTAINER_NAME}=${REGISTRY}/${IMAGE_NAME}:${SHORT_SHA} --record

                # tunggu rollout selesai
                kubectl --kubeconfig="$KCFG" -n ${KUBE_NAMESPACE} \
                  rollout status deploy/${DEPLOYMENT_NAME} --timeout=180s
              '''
            } catch (err) {
              // rollback otomatis jika rollout gagal
              sh '''
                set -euxo pipefail
                kubectl --kubeconfig="$KCFG" -n ${KUBE_NAMESPACE} rollout undo deploy/${DEPLOYMENT_NAME} || true
              '''
              throw err
            }
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
    success {
      echo "✅ Deployed ${REGISTRY}/${IMAGE_NAME}:${SHORT_SHA} to namespace ${KUBE_NAMESPACE}"
    }
    failure {
      echo "❌ Deployment failed. Check logs above."
    }
  }
}