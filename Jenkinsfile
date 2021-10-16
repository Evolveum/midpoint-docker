pipeline {
    agent any
    environment { 
        maintainer = "e"
        imagename = 'm'
        tag = 'l'
	imagetag = 'i'
    }
    stages {
        stage ('Setting build context') {
            steps {
                script {
                    maintainer = maintain()
                    imagename = imagename()
		    imagetag = imagetag()
//                    if (env.BRANCH_NAME == "master") {
//                       tag = "latest"
//                    } else {
                       tag = tag()
//                    }
                    if (!imagename) {
                        echo "You must define imagename in common.bash"
                        currentBuild.result = 'FAILURE'
                    }
                    if (!imagetag) {
                        echo "You must define imagetag in common.bash"
                        currentBuild.result = 'FAILURE'
                    }
                    if (!tag) {
                        echo "You must define tag in common.bash"
                        currentBuild.result = 'FAILURE'
                    }
                    // Build and test scripts expect that 'tag' is present in common.bash. This is necessary for both Jenkins and standalone testing.
                    // We don't care if there are more 'tag' assignments there. The latest one wins.
//                    sh "echo >> common.bash ; echo \"tag=\\\"${tag}\\\"\" >> common.bash ; echo common.bash ; cat common.bash"
                }  
            }
        }    
        stage ('Build') {
            steps {
                script {
                    try {
                        sh 'OUT=$(./build.sh -r); rc=$?; echo \"$OUT\" | tee -a debug; test $rc -eq 0'
                        //sh ' ./build.sh -r 2>&1 | tee -a debug ; test ${PIPESTATUS[0]} -eq 0 '
                    } catch (error) {
                        def error_details = readFile('./debug')
                        def message = "BUILD ERROR: There was a problem building ${imagename}:${imagetag} \n\n ${error_details}"
                        sh "rm -f ./debug"
                        handleError(message)
                    }
                }
            }
        }
        stage ('Test') {
            steps {
                script {
                    try {
                        sh 'echo Docker containers before root tests ; docker ps -a'		// temporary
                        sh 'OUT=$(bats tests); rc=$?; echo \"$OUT\" | tee -a debug; test $rc -eq 0'
                        //sh '(bats tests ) 2>&1 | tee debug ; test ${PIPESTATUS[0]} -eq 0'
                        sh 'echo Docker containers before compositions tests ; docker ps -a'		// temporary

                        sh 'cd demo/postgresql; OUT=$(bats tests); rc=$?; echo \"$OUT\" | tee -a debug; test $rc -eq 0'
                        //sh 'cd demo/clustering; OUT=$(bats tests); rc=$?; echo \"$OUT\" | tee -a debug; test $rc -eq 0'
                        //sh '(cd demo/postgresql ; bats tests ) 2>&1 | tee -a debug ; test ${PIPESTATUS[0]} -eq 0'
                        //sh '(cd demo/clustering ; bats tests ) 2>&1 | tee -a debug ; test ${PIPESTATUS[0]} -eq 0'
                    } catch (error) {
                        def error_details = readFile('./debug')
                        def message = "BUILD ERROR: There was a problem testing ${imagename}:${imagetag}. \n\n ${error_details}"
                        sh "rm -f ./debug"
                        handleError(message)
                    }
                }
            }
        }
	stage ('Push') {
            steps {
                script {
                    docker.withRegistry('https://registry.hub.docker.com/', "DockerHub") {
			def baseImg = docker.image("$maintainer/$imagename:${imagetag}")
                        baseImg.push("$imagetag")
                    }
                }
            }
        }
	stage ('CleanUp') {
            steps {
		script {
                    try {
                        sh 'docker stop $(docker ps -a -q)'
			sh 'docker rm -v -f $(docker ps -a -q)'
			sh 'docker volume prune -f'
			sh 'docker rmi $(docker images -a -q)'
			sh 'docker image prune -f'
                    } catch (error) {
                        def error_details = readFile('./debug')
                        def message = "CLEANUP ERROR: There was a problem cleaning up ${imagename}:${imagetag}. \n\n ${error_details}"
                        sh "rm -f ./debug"
                        echo "${message}"
                    }
		    
		}
            }
        }
    }
    post { 
        always { 
            echo 'Done Building.'
        }
        failure {
            handleError("BUILD ERROR: There was a problem building ${maintainer}/${imagename}:${tag}.")
        }
    }
}

def maintain() {
    def matcher = readFile('common.bash') =~ 'maintainer="(.+)"'
    matcher ? matcher[0][1] : 'evolveum'
}

def imagename() {
    def matcher = readFile('common.bash') =~ 'imagename="(.+)"'
    matcher ? matcher[0][1] : null
}

def tag() {
    def matcher = readFile('common.bash') =~ 'tag="(.+)"'
    matcher ? matcher[0][1] : latest
}

def imagetag() {
    def matcher = readFile('common.bash') =~ 'image_tag="(.+)"'
    matcher ? matcher[0][1] : latest
}

def handleError(String message) {
    echo "${message}"
    currentBuild.setResult("FAILED")
    sh 'exit 1'
}
