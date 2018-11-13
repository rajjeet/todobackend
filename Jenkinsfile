node {
    checkout scm
    
    try {
        stage 'Test'
        sh 'make test'
        
        stage 'Build'
        sh 'make build'
        
        stage 'Release'
        sh 'make release'
        
        stage 'Tag and Publish Release Image'
        sh 'make tag latest \$(git rev-parse --short HEAD) \$(git tag --points-at HEAD)'
        sh 'make buildtag master \$(git tag --points-at HEAD)'
        withEnv(["DOCKER_USER=${DOCKER_USER}", "DOCKER_PASSWORD=${DOCKER_PASSWORD}"]){
            sh 'make login'
        }
        sh 'make publish'

        
    } finally {
        
        stage 'Collect Test Reports'
        step([$class:'JUnitResultArchiver', testResults: '**/reports/*.xml'])
        
        stage 'Clean'
        sh 'make clean'
        sh 'make logout'
        
    }
}