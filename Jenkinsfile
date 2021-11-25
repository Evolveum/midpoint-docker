pipeline {
    agent { label slave01 }
    environment { 
        maintainer = "e"
        imagename = 'm'
        tag = 'l'
	imagetag = 'i'
	db = 'd'
    }
    stages {
        stage ('Setting build context') {
            steps {
                script {
		    sh '''
cat common.bash

sed -i "s/^tag=.*/tag=${B_TAG}/" common.bash

bi="$( echo -n "${B_BASE_IMAGE}" | cut -d : -f 1 )"
bit="$( echo -n "${B_BASE_IMAGE}" | cut -d : -f 2 )"
sed -i "s/^base_image=.*/base_image=\${bi}/" common.bash
sed -i "s/^base_image_tag=.*/base_image_tag=\${bit}/" common.bash

sed -i "s/^docker_image_tag=.*/docker_image_tag=${B_DOCKER_TAG}/" common.bash

sed -i "s/^db=.*/db=\"${B_DB}\"/" common.bash

cat common.bash

exit 1
'''
                    maintainer = maintain()
                    imagename = imagename()
		    imagetag = imagetag()
		    db = db()
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

			sh """
set +e
if [ \"${db}\" = \"native\" ]
then
	cp demo/postgresql/docker-compose-tests-native.yml demo/postgresql/docker-compose-tests.yml
	echo \"Going native...\"
else
	echo \"Continue with generic...\"
fi
echo \"DB structure check is done...\"
"""

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
            handleError("BUILD ERROR: There was a problem building ${maintainer}/${imagename}:${imagetag}.")
        }
    }
}

def db() {
    def matcher = readFile('common.bash') =~ 'db="(.+)"'
    matcher ? matcher[0][1] : generic
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
    def matcher = readFile('common.bash') =~ 'docker_image_tag="(.+)"'
    matcher ? matcher[0][1] : latest
}

def handleError(String message) {
    echo "${message}"
    currentBuild.setResult("FAILED")
    sh 'exit 1'
}
