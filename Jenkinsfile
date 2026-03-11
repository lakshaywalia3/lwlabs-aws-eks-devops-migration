pipeline {
    agent any
    
    environment {
        // IMPORTANT: Replace this with your actual 12-digit AWS Account ID
        AWS_ACCOUNT_ID = '<ADD_YOUR_AWS_ACCOUNT_ID_HERE>'
        AWS_REGION     = 'ap-south-1'
        ECR_REPO       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/lwlabs-app"
        IMAGE_TAG      = "v${BUILD_NUMBER}"
        CLUSTER_NAME   = "lwlabs-eks-cluster"
    }

    stages {
        stage('Checkout Code') {
            steps {
                echo "Pulling latest code from GitHub..."
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image for THE LW LABS..."
                    sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} ."
                    sh "docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_REPO}:latest"
                }
            }
        }
        
        stage('Push to AWS ECR') {
            steps {
                script {
                    echo "Authenticating and pushing to Elastic Container Registry..."
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                    sh "docker push ${ECR_REPO}:${IMAGE_TAG}"
                    sh "docker push ${ECR_REPO}:latest"
                }
            }
        }
        
        stage('Deploy to AWS EKS') {
            steps {
                script {
                    echo "Deploying to Kubernetes cluster..."
                    sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}"
                    sh "kubectl apply -f k8s/deployment.yaml"
                    
                    // This triggers a zero-downtime rolling restart of your pods with the new image
                    sh "kubectl rollout restart deployment lwlabs-app"
                }
            }
        }
    }
    
    post {
        success {
            echo "✅ Pipeline completed successfully! New version is live."
        }
        failure {
            echo "❌ Pipeline failed. Please check the Jenkins console logs."
        }
    }
}