def skipNativeTest = params.SKIP_NATIVE ?: false
def skipH2Test = params.SKIP_H2 ?: false
podTemplate(activeDeadlineSeconds: 7200, idleMinutes: 1, containers: [
    containerTemplate(
        name: "jnlp", 
        image: "jenkins/inbound-agent:4.13-2-alpine-jdk11", 
        runAsUser: '0', 
        resourceLimitCpu: '900m', 
        resourceLimitMemory: '1Gi', 
        resourceRequestCpu: '900m', 
        resourceRequestMemory: '1Gi'
    ),
    containerTemplate(
        name: "kubectl",
        image: "bitnami/kubectl:1.19.4",
        command: 'cat',
        runAsUser: '0',
        ttyEnabled: true,
    ),
  ]) {
    node(POD_LABEL) {
        stage ("create environment") {
            container ("kubectl") {
                withKubeConfig([credentialsId: '6a647093-716e-4e8f-90bd-a8007be37f0e',
                        serverUrl: 'https://10.100.1.42:6443',
                        contextName: 'jenkins',
                        clusterName: 'kubernetes',
                        namespace: 'jenkins'
                        ]) {
                    try {
                        sh """#!/bin/bash
#timestamp="\$(date +%s)-${JOB_NAME}-${BUILD_NUMBER}"
timestamp="${JOB_NAME}-${BUILD_NUMBER}"
echo \${timestamp} >timestamp
mkdir logs-\${timestamp}
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: docker-reg-\${timestamp}
  namespace: jenkins
spec:
  ports:
    - name: registry
      protocol: TCP
      port: 5000
      targetPort: 5000
  selector:
    app: docker-reg-\${timestamp}
  type: ClusterIP
  sessionAffinity: None
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: docker-registry-\${timestamp}
  namespace: jenkins
  annotations:
    kubernetes.io/ingress.class: haproxy
spec:
  tls:
    - hosts:
        - registry-\${timestamp}.lab.evolveum.com
      secretName: cert-lab-evolveum
  rules:
    - host: registry-\${timestamp}.lab.evolveum.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: docker-reg-\${timestamp}
                port:
                  number: 5000
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: docker-reg-\${timestamp}-config
  namespace: jenkins
data:
  config.yml: |-
    health:
      storagedriver:
        enabled: true
        interval: 10s
        threshold: 3
    http:
      addr: :5000
      headers:
        X-Content-Type-Options:
        - nosniff
    log:
      fields:
        service: registry
    storage:
      delete:
        enabled: true
      cache:
        blobdescriptor: inmemory
    version: 0.1
---
apiVersion: v1
kind: Secret
metadata:
  name: docker-reg-\${timestamp}-secret
  namespace: jenkins
data:
  haSharedSecret: Z2d5bnBzUWdwcXFWOXB2dw==
type: Opaque
---
apiVersion: v1
kind: Pod
metadata:
  name: docker-reg-\${timestamp}
  namespace: jenkins
  labels:
    app: docker-reg-\${timestamp}
spec:
  volumes:
    - name: data
      emptyDir: {}
    - name: docker-reg-\${timestamp}-config
      configMap:
        name: docker-reg-\${timestamp}-config
        defaultMode: 420
  containers:
    - name: docker-registry
      image: registry:2.8.1
      command:
        - /bin/registry
        - serve
        - /etc/docker/registry/config.yml
      ports:
        - containerPort: 5000
          protocol: TCP
      env:
        - name: REGISTRY_HTTP_SECRET
          valueFrom:
            secretKeyRef:
              name: docker-reg-\${timestamp}-secret
              key: haSharedSecret
        - name: REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY
          value: /var/lib/registry
      volumeMounts:
        - name: data
          mountPath: /var/lib/registry/
        - name: docker-reg-\${timestamp}-config
          mountPath: /etc/docker/registry
      livenessProbe:
        httpGet:
          path: /
          port: 5000
          scheme: HTTP
        timeoutSeconds: 1
        periodSeconds: 10
        successThreshold: 1
        failureThreshold: 3
      readinessProbe:
        httpGet:
          path: /
          port: 5000
          scheme: HTTP
        timeoutSeconds: 1
        periodSeconds: 10
        successThreshold: 1
        failureThreshold: 3
      imagePullPolicy: IfNotPresent
  securityContext:
    runAsUser: 1000
    fsGroup: 1000
EOF
echo "Waiting to get registry ready..."
http=\$(curl -I -L -s https://registry-\${timestamp}.lab.evolveum.com/v2/_catalog | head -n 1 | cut -d " " -f 2 )
while [ \${http} -eq 404 -o \${http} -eq 503 ]
do
    sleep 2
    http=\$(curl -I -L -s https://registry-\${timestamp}.lab.evolveum.com/v2/_catalog | head -n 1 | cut -d " " -f 2 )
done
echo "Registry is ready... (\${http})"
curl -s https://registry-\${timestamp}.lab.evolveum.com/v2/_catalog
                        """
                    } catch (err) {
                        echo "Caught: ${err}"
                        unstable 'Error during envvironment initialization'
                    }
                }
            }
        }
        stage ("build image") {
            container ("kubectl") {
                withKubeConfig([credentialsId: '6a647093-716e-4e8f-90bd-a8007be37f0e',
                        serverUrl: 'https://10.100.1.42:6443',
                        contextName: 'jenkins',
                        clusterName: 'kubernetes',
                        namespace: 'jenkins'
                        ]) {
                    try {
                        sh """#!/bin/bash
timestamp="\$(cat timestamp)"
#mkdir midpoint-docker
#curl -s -L https://github.com/Evolveum/midpoint-docker/tarball/master | tar -xzC ${WORKSPACE}/midpoint-docker --strip-components=1
osID=\$(echo "${IMAGEOS}" | cut -d "-" -f 1)
osVer=\$(echo "${IMAGEOS}" | cut -d "-" -f 2)
case \${osID} in
    alpine)
        javaPath="/usr/lib/jvm/default-jvm"
        ;;
    *)
        javaPath="/usr/lib/jvm/java-${JAVAVER}-openjdk-amd64"
        ;;
esac
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: kaniko-\${timestamp}
  namespace: jenkins
spec:
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:latest
      args:
        - "--dockerfile=Dockerfile"
        - "--context=git://github.com/Evolveum/midpoint-docker.git#refs/heads/master"
        - "--destination=registry-\${timestamp}.lab.evolveum.com/midpoint:build-${DOCKERTAG}-${IMAGEOS}-\${timestamp}"
        - --build-arg
        - base_image=\${osID}
        - --build-arg
        - base_image_tag=\${osVer}
        - --build-arg
        - java_home=\${javaPath}
        - --build-arg
        - MP_VERSION=${DOCKERTAG}
        - --build-arg
        - JAVA_VERSION=${JAVAVER}
  restartPolicy: Never
EOF
echo "Waiting to finish the process of the image build..."
status=\$(kubectl get -n jenkins pod/kaniko-\${timestamp} -o=jsonpath="{.status.phase}")
while [ "\${status}" == "Pending" -o "\${status}" == "Running" ]
do
    sleep 15
    status=\$(kubectl get -n jenkins pod/kaniko-\${timestamp} -o=jsonpath="{.status.phase}")
    echo "Log contain \$(kubectl logs -n jenkins kaniko-\${timestamp} | wc -l) lines..."
done
echo " - - - - partial log from the kaniko container - - - -"
kubectl logs -n jenkins kaniko-\${timestamp} |tee logs-\${timestamp}/kaniko.log | grep -B 1 "Applying\\|Downloading midPoint\\|Pushed"
echo " - - - - end of container's partial log - - - -"
echo -e "\\tFull log is available to download in the job build's artifact..."
kubectl delete -n jenkins pod/kaniko-\${timestamp}
                    """
                    } catch (err) {
                        echo "Caught: ${err}"
                        unstable 'Error during build phase'
                    }
                }
            }
        }
        stage ("test-H2") {
            container ("kubectl") {
                try {
                    if (skipH2Test) {
                        sh """#!/bin/bash
timestamp="\$(cat timestamp)"
echo 0 > logs-\${timestamp}/test-result-h2
"""
                        echo "H2 tests are not required"
                        return
                    } else {
                        echo "Processing the H2 test..."
                    }
                    sh """#!/bin/bash
timestamp="\$(cat timestamp)"

#In each cycle there is sleep time set to 5 seconds
waitCycle=120

mkdir logs-\${timestamp}/h2

function createPVC {
    cat <<EOF | kubectl apply -f - | grep created | sed "s|\\([^[:space:]]*\\) created|\\1|"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: \${2}
  namespace: \${1}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: \${3:-5}\${4:-G}i
  volumeMode: Filesystem
EOF

}

function createMPPod {
    if [ "\${4}" == "" ]
    then
        volDef="emptyDir: {}"
    else
        volDef="persistentVolumeClaim:
        claimName: \${4}"
    fi
    cat <<EOF | kubectl apply -f - | grep created | sed "s|\\([^[:space:]]*\\) created|\\1|"
apiVersion: v1
kind: Pod
metadata:
  name: \${2}-\${3}
  namespace: \${1}
  labels:
    app: \${2}-\${3}
    type: test
spec:
  volumes:
    - name: mpdata
      \${volDef}
  containers:
    - name: mp
      image: 'registry-\${3}.lab.evolveum.com/midpoint:build-${DOCKERTAG}-${IMAGEOS}-\${3}'
      ports:
        - name: gui
          containerPort: 8080
          protocol: TCP
      env:
        - name: MP_SET_midpoint_administrator_initialPassword
          value: Test5ecr3t
      volumeMounts:
        - name: mpdata
          mountPath: /opt/midpoint/var
      imagePullPolicy: IfNotPresent
  restartPolicy: Always
EOF
}

function checkApp {
    iteration=0
    logItemFound=0

    while [ \${iteration} -le \${waitCycle} -a \${logItemFound} -eq 0 ]
    do
        sleep 5
        kubectl logs -n \${1} \${2} > \${3}/pod-mp.log 2>\${3}/pod-mp.errlog
        [ \$(grep -c "INFO (com.evolveum.midpoint.web.boot.MidPointSpringApplication): Started MidPointSpringApplication in" \${3}/pod-mp.log) -gt 0 ] && logItemFound=1
        [ \$(grep -c "is waiting to start: image can't be pulled" \${3}/pod-mp.errlog) -gt 0 ] && logItemFound=2
        [ \$(grep -c "midPoint to start" \${3}/pod-mp.log) -gt 0 ] && logItemFound=3
        [ \$(grep -c "midPoint did not start" \${3}/pod-mp.log) -gt 0 ] && logItemFound=4
        iteration=\$(( \${iteration} + 1 ))
    done

    if [ -s \${3}/pod-mp.errlog ]
    then
        echo " - - - - error log - - - -"
        if [ \$(cat \${3}/pod-mp.errlog | wc -l) -gt 20 ]
        then
            head \${3}/pod-mp.errlog
            echo ". . ."
            tail \${3}/pod-mp.errlog
        else
            cat \${3}/pod-mp.errlog
        fi    
    fi
    if [ -s \${3}/pod-mp.log ]
    then
        echo " - - - - log - - - -"
        if [ \$(cat \${3}/pod-mp.log | wc -l) -gt 20 ]
        then
            head \${3}/pod-mp.log
            echo ". . ."
            tail \${3}/pod-mp.log
        else
            cat \${3}/pod-mp.log
        fi
    fi
    echo " - - - -"

    case \${logItemFound} in
        0)
            echo "-- : Time out happen..."
            return 1
            ;;
        1)
            echo "OK : Application is UP"
            ;;
        2)
            echo "ER : The image can't be pulled"
            return 1
            ;;
        *)
            echo "ER : Something is wrong..."
            return 1
            ;;
    esac
    return 0
}

function checkGenPass {
	if [ \$( grep -c "Please change administrator password  after first login." \${1} ) -gt 0 ]
	then
		mppw="\$(grep "Administrator initial password" \${1} | sed 's/[^"]*"\\(.*\\)"[^"]*/\\1/')"
		if [ -z "\${mppw}" ]
		then
			mppw="\${2:-Test5ecr3t}"
		fi
	else
		mppw="5ecr3t"
	fi
	echo "\${mppw}"
	return 0
}

function healthCheck {
    iteration=0
    status="\$(curl -s -f http://\${1}:\${2}/midpoint/actuator/health | tr -d '[:space:]' | sed "s|{\\"status\\":\\"\\([^\\"]*\\)\\"}|\\1|")"
    while [ \${iteration} -lt \${waitCycle} -a "\${status}" != "UP" ]
    do
        sleep 5
        status="\$(curl -s -f http://\${1}:\${2}/midpoint/actuator/health | tr -d '[:space:]' | sed "s|{\\"status\\":\\"\\([^\\"]*\\)\\"}|\\1|")"
        iteration=\$(( \${iteration} + 1 ))
    done
    if [ "\${status}" == "UP" ]
    then
        echo "OK : Health: \${status}"
    else
        echo "ER : Health: \${status}"
        return 1
    fi
    return 0
}

function addUser {
        curl -s --user "administrator:\${4:-5ecr3t}" -H "Content-Type: application/xml" -X POST -d "<user><name>\${3}</name></user>"  "http://\${1}:\${2}/midpoint/ws/rest/users"
}

function checkUserExists {
        suffix="-\$(ls -1 \${3}/pod-users*.lst 2>/dev/null | wc -l)"
        curl -s --user "administrator:\${7:-5ecr3t}" -H "Content-Type: application/xml" -X GET "http://\${1}:\${2}/midpoint/ws/rest/users" | grep "<apti\\|<name>" | paste - - | sed "s|.*oid=\\"\\([^\\"]*\\)\\".*<name>\\([^<]*\\)</name.*|\\1:\\2:|" > \${3}/pod-users\${suffix}.lst
        case \${4} in
            oid)
                if [ \$(grep "^\${5}:" \${3}/pod-users\${suffix}.lst | wc -l) -gt 0 ]
                then
                    if [ "\${6:-}" == "" ]
                    then
                        echo "OK : User with OID \${5} exists... (\$(grep "^\${5}:" \${3}/pod-users\${suffix}.lst | cut -d ":" -f 2))"
                    else
                        if [ \$(grep "^\${5}:\${6}" \${3}/pod-users\${suffix}.lst | wc -l) -gt 0 ]
                        then
                            echo "OK : User with OID \${5} and name \${6} exists... (\$(grep "^\${5}:\${6}" \${3}/pod-users\${suffix}.lst | tr ":" " "))"
                        else
                            echo "ER : User with OID \${5} and name \${6} does not exist..."
                            return 1
                        fi
                    fi
                else
                    echo "ER : User with OID \${5} does not exist..."
                    return 1
                fi
                ;;
            name)
                if [ \$(grep ":\${5}:" \${3}/pod-users\${suffix}.lst | wc -l) -gt 0 ]
                then
                    echo "OK : User \${5} exists... (\$(grep ":\${5}:" \${3}/pod-users\${suffix}.lst | cut -d ":" -f 1))"
                else
                    echo "ER : User \${5} does not exist..."
                    return 1
                fi
                ;;
        esac
        return 0
}

echo "1" > logs-\${timestamp}/test-result-h2
error=0
phase=1
mkdir logs-\${timestamp}/h2/\${phase}

echo
createPVC jenkins test-mp-\${timestamp} 1 | tee logs-\${timestamp}/h2/pvc
createMPPod jenkins test-mp \${timestamp} test-mp-\${timestamp} | tee logs-\${timestamp}/h2/\${phase}/pod
pvcname="\$(cat logs-\${timestamp}/h2/pvc)"
podname="\$(cat logs-\${timestamp}/h2/\${phase}/pod)"

podIPs="\$(kubectl get -n jenkins \${podname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
while [ "\${podIPs:0:1}" == ":" ]
do
    sleep 5
    podIPs="\$(kubectl get -n jenkins \${podname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
done
podIP="\$(echo -n \${podIPs} | cut -d : -f 1)"
hostIP="\$(echo -n \${podIPs} | cut -d : -f 2)"

echo

kubectl get -n jenkins \${podname} -o=jsonpath="{range .status.conditions[*]}{.type}{': '}{.status}{'\\n'}{end}"

echo -e  "\\nPod IP: \${podIP}\\nHost IP: \${hostIP}\\n"

echo -e "\\nWait to Application get up..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    checkApp jenkins \${podname} logs-\${timestamp}/h2/\${phase}
    error=\$?
fi

echo -e "\\nHealth Check Test..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    healthCheck \${podIP} 8080
    error=\$?
fi

mppw="\$(checkGenPass logs-\${timestamp}/h2/\${phase}/pod-mp.log Test5ecr3t)"
echo "Administrator Password: \\"\${mppw}\\""

echo -e "\\nGet 'administrator' Test..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    checkUserExists \${podIP} 8080 logs-\${timestamp}/h2/\${phase}/ oid 00000000-0000-0000-0000-000000000002 administrator "\${mppw}"
    error=\$?
fi

echo -e "\\nAdd and test 'test110' user Test..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    addUser \${podIP} 8080 test110 \${mppw}
    checkUserExists \${podIP} 8080 logs-\${timestamp}/h2/\${phase}/ name test110 - "\${mppw}"
    error=\$?
fi

echo " = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="
echo -e "\\nCheck repository preserved between restarts..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else

    echo
    kubectl logs -n jenkins \${podname} > logs-\${timestamp}/h2/\${phase}/pod-full.log
    kubectl exec -n jenkins \${podname} -- ls -lah /opt/midpoint/var/midpoint.mv.db
    kubectl delete -n jenkins \${podname}

    phase=\$(( \${phase} + 1 ))
    mkdir logs-\${timestamp}/h2/\${phase}

    createMPPod jenkins test-mp \${timestamp} test-mp-\${timestamp} | tee logs-\${timestamp}/h2/\${phase}/pod

    podIPs="\$(kubectl get -n jenkins \${podname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
    while [ "\${podIPs:0:1}" == ":" ]
    do
        sleep 5
        podIPs="\$(kubectl get -n jenkins \${podname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
    done
    podIP="\$(echo -n \${podIPs} | cut -d : -f 1)"
    hostIP="\$(echo -n \${podIPs} | cut -d : -f 2)"

    echo

    kubectl get -n jenkins \${podname} -o=jsonpath="{range .status.conditions[*]}{.type}{': '}{.status}{'\\n'}{end}"

    echo -e  "\\nPod IP: \${podIP}\\nHost IP: \${hostIP}\\n"

    echo -e "\\nWait to Application get up..."
    if [ \${error} -ne 0 ]
    then
        echo -e "\\tSkipped due to the previous error in the tests..."
    else
        checkApp jenkins \${podname} logs-\${timestamp}/h2/\${phase}
        error=\$?
    fi

    kubectl exec -n jenkins \${podname} -- ls -lah /opt/midpoint/var/midpoint.mv.db

    echo -e "\\nHealth Check Test..."
    if [ \${error} -ne 0 ]
    then
        echo -e "\\tSkipped due to the previous error in the tests..."
    else
        healthCheck \${podIP} 8080
        error=\$?
    fi

    echo -e "\\n'test110' user Test..."
    if [ \${error} -ne 0 ]
    then
        echo -e "\\tSkipped due to the previous error in the tests..."
    else
        checkUserExists \${podIP} 8080 logs-\${timestamp}/h2/\${phase}/ name test110 - "\${mppw}"
        error=\$?
    fi
    
fi
echo " = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="

[ \${error} -eq 0 ] && echo "OK : repository preserved between restarts"

if [ \${error} -eq 0 ]
then
    echo -e "\\n\\tALL tests were OK...\n"
else
    echo -e "\\n\\tThere were error during the test...\n"
fi

echo \${error} > logs-\${timestamp}/test-result-h2

kubectl logs -n jenkins \${podname} > logs-\${timestamp}/h2/\${phase}/pod-full.log
kubectl delete -n jenkins \${podname} \${pvcname}

grep -B 8 -A 4 "^  Version" logs-\${timestamp}/h2/\${phase}/pod-full.log

[ \${error} -ne 0 ] && exit 1
exit 0                    
                    """
                } catch (err) {
                    echo "Caught: ${err}"
                    unstable 'Error during H2 tests'
                }
            }
        }
        stage ("test-native") {
            container ("kubectl") {
                try {
                    if (skipNativeTest) {
                        sh """#!/bin/bash
timestamp="\$(cat timestamp)"
echo 0 > logs-\${timestamp}/test-result-native
"""
                        echo "Native tests are not required"
                        return
                    } else {
                        echo "Processing the Native test..."
                    }
                    sh """#!/bin/bash
#legacy check
docTag='${DOCKERTAG}'
if [ "\${docTag:0:3}" == "4.0" ]
then
    echo "Native test is not relevant in case of 4.0 branch..."
    exit 0
fi

timestamp="\$(cat timestamp)"

#In each cycle there is sleep time set to 5 seconds
waitCycle=120

echo "1" > logs-\${timestamp}/test-result-native
error=0

mkdir logs-\${timestamp}/native
phase=1
mkdir logs-\${timestamp}/native/\${phase}

function createPVC {
    cat <<EOF | kubectl apply -f - | grep created | sed "s|\\([^[:space:]]*\\) created|\\1|"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: \${2}
  namespace: \${1}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: \${3:-5}\${4:-G}i
  volumeMode: Filesystem
EOF
}

function createDBPod {
    cat <<EOF | kubectl apply -f - | grep created | sed "s|\\([^[:space:]]*\\) created|\\1|"
apiVersion: v1
kind: Pod
metadata:
  name: \${2}-\${3}
  namespace: \${1}
  labels:
    app: \${2}-\${3}
    type: test
spec:
  volumes:
    - name: pvc
      persistentVolumeClaim:
        claimName: \${4}
  containers:
    - name: postgresql
      image: 'postgres:\${5:-13}-alpine'
      ports:
        - name: db
          containerPort: 5432
          protocol: TCP
      env:
        - name: POSTGRES_INITDB_ARGS
          value: '--lc-collate=en_US.utf8 --lc-ctype=en_US.utf8'
        - name: POSTGRES_USER
          value: midpoint
        - name: POSTGRES_PASSWORD
          value: SuperSecretPassword007
      volumeMounts:
        - name: pvc
          mountPath: /var/lib/postgresql/data
          subPath: db-data
      imagePullPolicy: IfNotPresent
  restartPolicy: Always
EOF
}

function createMPPod {
    if [ "\${5}" == "" ]
    then
        volDef="emptyDir: {}"
    else
        volDef="persistentVolumeClaim:
        claimName: \${5}"
    fi
    cat <<EOF | kubectl apply -f - | grep created | sed "s|\\([^[:space:]]*\\) created|\\1|"
apiVersion: v1
kind: Pod
metadata:
  name: \${2}-\${3}
  namespace: \${1}
  labels:
    app: \${2}-\${3}
    type: test
spec:
  volumes:
    - name: mpdata
      \${volDef}
  initContainers:
    - name: mp-config-init
      image: 'registry-\${3}.lab.evolveum.com/midpoint:build-${DOCKERTAG}-${IMAGEOS}-\${3}'
      command: [ "/bin/bash", "-c" ]
      args:
        - cd /opt/midpoint ;
          bin/midpoint.sh init-native ;
          echo ' - - - < 4.8 ninja sh does not apply env var - - - ' ;
          sed -i "/jdbcUrl/c\\<jdbcUrl>jdbc:postgresql://\${4}:5432/midpoint</jdbcUrl>" /opt/midpoint/var/config.xml ;
          sed -i "/jdbcUsername/c\\<jdbcUsername>midpoint</jdbcUsername>" /opt/midpoint/var/config.xml ;
          sed -i "/jdbcPassword/c\\<jdbcPassword>SuperSecretPassword007</jdbcPassword>" /opt/midpoint/var/config.xml ;
          cat /opt/midpoint/var/config.xml ;
          echo ' - - - - - - ' ;
          bin/ninja.sh -B info >/dev/null 2>/tmp/ninja.log ;
          grep -q "ERROR" /tmp/ninja.log && (
          bin/ninja.sh -B run-sql --create --mode REPOSITORY  ;
          bin/ninja.sh -B run-sql --create --mode AUDIT
          ) ||
          echo -e '\\n Repository init is not needed...' ;
      env:
        - name: MP_INIT_CFG
          value: /opt/midpoint/var
        - name: MP_SET_midpoint_repository_database
          value: postgresql
        - name: MP_SET_midpoint_repository_jdbcUsername
          value: midpoint
        - name: MP_SET_midpoint_repository_jdbcPassword
          value: SuperSecretPassword007
        - name: MP_SET_midpoint_repository_jdbcUrl
          value: jdbc:postgresql://\${4}:5432/midpoint
      volumeMounts:
        - name: mpdata
          mountPath: /opt/midpoint/var
      imagePullPolicy: IfNotPresent
  containers:
    - name: mp
      image: 'registry-\${3}.lab.evolveum.com/midpoint:build-${DOCKERTAG}-${IMAGEOS}-\${3}'
      ports:
        - name: gui
          containerPort: 8080
          protocol: TCP
      env:
        - name: MP_SET_midpoint_repository_database
          value: postgresql
        - name: MP_SET_midpoint_repository_jdbcUsername
          value: midpoint
        - name: MP_SET_midpoint_repository_jdbcPassword
          value: SuperSecretPassword007
        - name: MP_SET_midpoint_repository_jdbcUrl
          value: jdbc:postgresql://\${4}:5432/midpoint
        - name: MP_SET_midpoint_administrator_initialPassword
          value: Test5ecr3t
        - name: MP_UNSET_midpoint_repository_hibernateHbm2ddl
          value: "1"
        - name: MP_NO_ENV_COMPAT
          value: "1"
      volumeMounts:
        - name: mpdata
          mountPath: /opt/midpoint/var
      imagePullPolicy: IfNotPresent
  restartPolicy: Always
EOF
}

function checkApp {
    iteration=0
    logItemFound=0

    while [ \${iteration} -le \${waitCycle} -a \${logItemFound} -eq 0 ]
    do
        sleep 5
        kubectl logs -n \${1} \${2} > \${3}/pod-mp.log 2>\${3}/pod-mp.errlog
        [ \$(grep -c "INFO (com.evolveum.midpoint.web.boot.MidPointSpringApplication): Started MidPointSpringApplication in" \${3}/pod-mp.log) -gt 0 ] && logItemFound=1
        [ \$(grep -c "is waiting to start: image can't be pulled" \${3}/pod-mp.errlog) -gt 0 ] && logItemFound=2
        [ \$(grep -c "midPoint to start" \${3}/pod-mp.log) -gt 0 ] && logItemFound=3
        [ \$(grep -c "midPoint did not start" \${3}/pod-mp.log) -gt 0 ] && logItemFound=4
        iteration=\$(( \${iteration} + 1 ))
    done

    if [ -s \${3}/pod-mp.errlog ]
    then
        echo " - - - - error log - - - -"
        if [ \$(cat \${3}/pod-mp.errlog | wc -l) -gt 20 ]
        then
            head \${3}/pod-mp.errlog
            echo ". . ."
            tail \${3}/pod-mp.errlog
        else
            cat \${3}/pod-mp.errlog
        fi
    fi
    if [ -s \${3}/pod-mp.errlog ]
    then
        echo " - - - - log - - - -"
        if [ \$(cat \${3}/pod-mp.log | wc -l) -gt 20 ]
        then
            head \${3}/pod-mp.log
            echo ". . ."
            tail \${3}/pod-mp.log
        else
            cat \${3}/pod-mp.log
        fi
    fi
    echo " - - - -"

    case \${logItemFound} in
        0)
            echo "-- : Time out happen..."
            return 1
            ;;
        1)
            echo "OK : Application is UP"
            ;;
        2)
            echo "ER : The image can't be pulled"
            return 1
            ;;
        *)
            echo "ER : Something is wrong..."
            return 1
            ;;
    esac
    return 0
}

function checkGenPass {
        if [ \$( grep -c "Please change administrator password  after first login." \${1} ) -gt 0 ]
        then
                mppw="\$(grep "Administrator initial password" \${1} | sed 's/[^"]*"\\(.*\\)"[^"]*/\\1/')"
                if [ -z "\${mppw}" ]
                then
                        mppw="\${2:-Test5ecr3t}"
                fi
        else
                mppw="5ecr3t"
        fi
        echo "\${mppw}"
        return 0
}

function checkDB {
        iteration=0
        logItemFound=0

        echo -n "Processed : 0 lines of log..."
        while [ \${iteration} -le \${waitCycle} -a \${logItemFound} -eq 0 ]
        do
                sleep 5
                kubectl logs -n \${1} \${2} > \${3}/pod-db.log 2>\${3}/pod-db.errlog
                echo -n -e "\rProcessed : \$(cat \${3}/pod-db.log | wc -l ) lines of log..."
                [ \$(grep -c "LOG:  database system is ready to accept connections" \${3}/pod-db.log) -gt \${4} ] && logItemFound=1
                iteration=\$(( \${iteration} + 1 ))
        done
        echo

        case \${logItemFound} in
                0)
                        echo "-- : Time out happen..."
                        return 1
                        ;;
                1)
                        echo "OK : repository is UP"
                        if [ \${4} -gt 0 ]
                        then
                                echo " stats:"
                                grep "psql:/docker-entrypoint-initdb.d" \${3}/pod-db.log | cut -d ":" -f 4 | sort | uniq -c
                        fi
                        ;;
                *)
                        echo "ER : Something is wrong..."
                        return 1
                        ;;
        esac
        return 0
}

function healthCheck {
    iteration=0
    status="\$(curl -s -f http://\${1}:\${2}/midpoint/actuator/health | tr -d '[:space:]' | sed "s|{\\"status\\":\\"\\([^\\"]*\\)\\"}|\\1|")"
    while [ \${iteration} -lt \${waitCycle} -a "\${status}" != "UP" ]
    do
        sleep 5
        status="\$(curl -s -f http://\${1}:\${2}/midpoint/actuator/health | tr -d '[:space:]' | sed "s|{\\"status\\":\\"\\([^\\"]*\\)\\"}|\\1|")"
        iteration=\$(( \${iteration} + 1 ))
    done
    if [ "\${status}" == "UP" ]
    then
        echo "OK : Health: \${status}"
    else
        echo "ER : Health: \${status}"
        return 1
    fi
    return 0
}

function addUser {
        curl -s --user "administrator:\${4:-5ecr3t}" -H "Content-Type: application/xml" -X POST -d "<user><name>\${3}</name></user>"  "http://\${1}:\${2}/midpoint/ws/rest/users"
}

function checkUserExists {
        suffix="-\$(ls -1 \${3}/pod-users*.lst 2>/dev/null | wc -l)"
        curl -s --user "administrator:\${7:-5ecr3t}" -H "Content-Type: application/xml" -X GET "http://\${1}:\${2}/midpoint/ws/rest/users" | grep "<apti\\|<name>" | paste - - | sed "s|.*oid=\\"\\([^\\"]*\\)\\".*<name>\\([^<]*\\)</name.*|\\1:\\2:|" > \${3}/pod-users\${suffix}.lst
        case \${4} in
            oid)
                if [ \$(grep "^\${5}:" \${3}/pod-users\${suffix}.lst | wc -l) -gt 0 ]
                then
                    if [ "\${6:-}" == "" ]
                    then
                        echo "OK : User with OID \${5} exists... (\$(grep "^\${5}:" \${3}/pod-users\${suffix}.lst | cut -d ":" -f 2))"
                    else
                        if [ \$(grep "^\${5}:\${6}" \${3}/pod-users\${suffix}.lst | wc -l) -gt 0 ]
                        then
                            echo "OK : User with OID \${5} and name \${6} exists... (\$(grep "^\${5}:\${6}" \${3}/pod-users\${suffix}.lst | tr ":" " "))"
                        else
                            echo "ER : User with OID \${5} and name \${6} does not exist..."
                            return 1
                        fi
                    fi
                else
                    echo "ER : User with OID \${5} does not exist..."
                    return 1
                fi
                ;;
            name)
                if [ \$(grep ":\${5}:" \${3}/pod-users\${suffix}.lst | wc -l) -gt 0 ]
                then
                    echo "OK : User \${5} exists... (\$(grep ":\${5}:" \${3}/pod-users\${suffix}.lst | cut -d ":" -f 1))"
                else
                    echo "ER : User \${5} does not exist..."
                    return 1
                fi
                ;;
        esac
        return 0
}

echo
createPVC jenkins test-db-\${timestamp} 5 | tee logs-\${timestamp}/native/dbpvc
createDBPod jenkins test-db \${timestamp} test-db-\${timestamp} 13 | tee logs-\${timestamp}/native/\${phase}/dbpod
pvcdbname="\$(cat logs-\${timestamp}/native/dbpvc)"
poddbname="\$(cat logs-\${timestamp}/native/\${phase}/dbpod)"

podIPs="\$(kubectl get -n jenkins \${poddbname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
while [ "\${podIPs:0:1}" == ":" ]
do
    sleep 5
    podIPs="\$(kubectl get -n jenkins \${poddbname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
done
poddbIP="\$(echo -n \${podIPs} | cut -d : -f 1)"
hostdbIP="\$(echo -n \${podIPs} | cut -d : -f 2)"

echo

kubectl get -n jenkins \${poddbname} -o=jsonpath="{'initContainer exitCode: '}{.status.initContainerStatuses[0].state.terminated.exitCode}{'\\n\\n'}{range .status.conditions[*]}{.type}{': '}{.status}{'\\n'}{end}"

echo -e  "\\nPod IP: \${poddbIP}\\nHost IP: \${hostdbIP}\\n"

echo -e "\\nWait to DB repository get up..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    checkDB jenkins \${poddbname} logs-\${timestamp}/native/\${phase} 1
    error=\$?
fi

createPVC jenkins test-mp-\${timestamp} 1 | tee logs-\${timestamp}/native/pvc
createMPPod jenkins test-mp \${timestamp} \${poddbIP} test-mp-\${timestamp} | tee logs-\${timestamp}/native/\${phase}/pod
pvcname="\$(cat logs-\${timestamp}/native/pvc)"
podname="\$(cat logs-\${timestamp}/native/\${phase}/pod)"

podIPs="\$(kubectl get -n jenkins \${podname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
while [ "\${podIPs:0:1}" == ":" ]
do
    sleep 5
    podIPs="\$(kubectl get -n jenkins \${podname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
done
podIP="\$(echo -n \${podIPs} | cut -d : -f 1)"
hostIP="\$(echo -n \${podIPs} | cut -d : -f 2)"

echo

kubectl get -n jenkins \${podname} -o=jsonpath="{'initContainer exitCode: '}{.status.initContainerStatuses[0].state.terminated.exitCode}{'\\n\\n'}{range .status.conditions[*]}{.type}{': '}{.status}{'\\n'}{end}"

echo -e  "\\nPod IP: \${podIP}\\nHost IP: \${hostIP}\\n"

echo -e "\\nWait to Application get up..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    checkApp jenkins \${podname} logs-\${timestamp}/native/\${phase}
    error=\$?
fi

echo -e "\\nHealth Check Test..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    healthCheck \${podIP} 8080
    error=\$?
fi

mppw="\$(checkGenPass logs-\${timestamp}/native/\${phase}/pod-mp.log Test5ecr3t)"
echo "Administrator Password: \\"\${mppw}\\""

echo -e "\\nGet 'administrator' Test..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    checkUserExists \${podIP} 8080 logs-\${timestamp}/native/\${phase}/ oid 00000000-0000-0000-0000-000000000002 administrator "\${mppw}"
    error=\$?
fi

echo -e "\\nAdd and test 'test110' user Test..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    addUser \${podIP} 8080 test110 \${mppw}
    checkUserExists \${podIP} 8080 logs-\${timestamp}/native/\${phase}/ name test110 - "\${mppw}"
    error=\$?
fi

echo " = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="
echo -e "\\nCheck repository preserved between restarts..."
if [ \${error} -ne 0 ]
then
    echo -e "\\tSkipped due to the previous error in the tests..."
else
    echo
    kubectl logs -n jenkins \${podname} -c mp-config-init > logs-\${timestamp}/native/\${phase}/pod-mp-init-full.log
    kubectl logs -n jenkins \${podname} -c mp > logs-\${timestamp}/native/\${phase}/pod-mp-mp-full.log
    kubectl delete -n jenkins \${podname}
    kubectl logs -n jenkins \${poddbname} -c postgresql > logs-\${timestamp}/native/\${phase}/pod-db-postgresql-full.log
    kubectl delete -n jenkins \${poddbname}

    phase=\$(( \${phase} + 1 ))
    mkdir logs-\${timestamp}/native/\${phase}

    createDBPod jenkins test-db \${timestamp} test-db-\${timestamp} 13 | tee logs-\${timestamp}/native/\${phase}/dbpod
    poddbname="\$(cat logs-\${timestamp}/native/\${phase}/dbpod)"

    podIPs="\$(kubectl get -n jenkins \${poddbname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
    while [ "\${podIPs:0:1}" == ":" ]
    do
        sleep 5
        podIPs="\$(kubectl get -n jenkins \${poddbname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
    done
    poddbIP="\$(echo -n \${podIPs} | cut -d : -f 1)"
    hostdbIP="\$(echo -n \${podIPs} | cut -d : -f 2)"

    echo

    kubectl get -n jenkins \${poddbname} -o=jsonpath="{'initContainer exitCode: '}{.status.initContainerStatuses[0].state.terminated.exitCode}{'\\n\\n'}{range .status.conditions[*]}{.type}{': '}{.status}{'\\n'}{end}"

    echo -e  "\\nPod IP: \${poddbIP}\\nHost IP: \${hostdbIP}\\n"

    echo -e "\\nWait to DB repository get up..."
    if [ \${error} -ne 0 ]
    then
        echo -e "\\tSkipped due to the previous error in the tests..."
    else
        checkDB jenkins \${poddbname} logs-\${timestamp}/native/\${phase} 0
        error=\$?
    fi

    createMPPod jenkins test-mp \${timestamp} \${poddbIP} test-mp-\${timestamp} | tee logs-\${timestamp}/native/\${phase}/pod
    podname="\$(cat logs-\${timestamp}/native/\${phase}/pod)"

    podIPs="\$(kubectl get -n jenkins \${podname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
    while [ "\${podIPs:0:1}" == ":" ]
    do
        sleep 5
        podIPs="\$(kubectl get -n jenkins \${podname} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
    done
    podIP="\$(echo -n \${podIPs} | cut -d : -f 1)"
    hostIP="\$(echo -n \${podIPs} | cut -d : -f 2)"

    echo

    kubectl get -n jenkins \${podname} -o=jsonpath="{'initContainer exitCode: '}{.status.initContainerStatuses[0].state.terminated.exitCode}{'\\n\\n'}{range .status.conditions[*]}{.type}{': '}{.status}{'\\n'}{end}"

    echo -e  "\\nPod IP: \${podIP}\\nHost IP: \${hostIP}\\n"

    echo -e "\\nWait to Application get up..."
    if [ \${error} -ne 0 ]
    then
        echo -e "\\tSkipped due to the previous error in the tests..."
    else
        checkApp jenkins \${podname} logs-\${timestamp}/native/\${phase}
        error=\$?
    fi

    echo -e "\\nHealth Check Test..."
    if [ \${error} -ne 0 ]
    then
        echo -e "\\tSkipped due to the previous error in the tests..."
    else
        healthCheck \${podIP} 8080
        error=\$?
    fi

    echo -e "\\n'test110' user Test..."
    if [ \${error} -ne 0 ]
    then
        echo -e "\\tSkipped due to the previous error in the tests..."
    else
        checkUserExists \${podIP} 8080 logs-\${timestamp}/native/\${phase}/ name test110 - "\${mppw}"
        error=\$?
    fi
    
fi
echo " = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = ="

[ \${error} -eq 0 ] && echo "OK : repository preserved between restarts"

if [ \${error} -eq 0 ]
then
    echo -e "\\n\\tALL tests were OK...\n"
else
    echo -e "\\n\\tThere were error during the test...\n"
fi

echo "\${error}" > logs-\${timestamp}/test-result-native

kubectl logs -n jenkins \${podname} -c mp-config-init > logs-\${timestamp}/native/\${phase}/pod-mp-init-full.log
kubectl logs -n jenkins \${podname} -c mp > logs-\${timestamp}/native/\${phase}/pod-mp-mp-full.log

kubectl delete -n jenkins \${podname} \${pvcname}

kubectl logs -n jenkins \${poddbname} -c postgresql > logs-\${timestamp}/native/\${phase}/pod-db-postgresql-full.log

kubectl delete -n jenkins \${poddbname} \${pvcdbname}

grep -B 8 -A 4 "^  Version" logs-\${timestamp}/native/\${phase}/pod-mp-mp-full.log

[ \${error} -ne 0 ] && exit 1
exit 0
                        """
                } catch (err) {
                    echo "Caught: ${err}"
                    unstable 'Error during native tests...'
                }
            }
        }
        stage ("push") {
            container ("kubectl") {
                try {
                    withCredentials([usernamePassword(credentialsId: 'DockerHub', passwordVariable: 'dockerPw', usernameVariable: 'dockerUser')]) {
                        sh """#!/bin/bash
timestamp="\$(cat timestamp)"

#In each cycle there is sleep time set to 5 seconds
waitCycle=120

curl -s https://registry-\${timestamp}.lab.evolveum.com/v2/_catalog
curl -s https://registry-\${timestamp}.lab.evolveum.com/v2/midpoint/tags/list
echo
error=0
while read line
do
    echo "Partial error status: \${line}"
    [ "\$(echo "\${line}" | tr -d [[:space:]])" != "0" ] && error=1
done < <(cat logs-\${timestamp}/test-result*)
echo \${error} > logs-\${timestamp}/test-result
echo "Overall error status is : \${error}"

if [ "${ALTDOCTAG}" == "NO_PUSH" ]
then
	echo "There is request to skip the Image PUSH. Skipping..."
	exit 0
fi

if [ \${error} -ne 0 ]
then
    echo "The image will not be pushed due to the previous error during the test..."
else
    distInfo="\$(grep "^Nexus:" logs-\${timestamp}/kaniko.log)"
    osSuffix="-\$(echo "${IMAGEOS}" | cut -d "-" -f 1)"
    autotag=""
    [ "\${osSuffix}" == "-ubuntu" ] && autotag="${DOCKERTAG}"
    [ "${DOCKERTAG}\${osSuffix}" == "4.0-support-alpine" ] && autotag="4.0support-alpine"
    finalTags=""
    echo " - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    for pushTag in ${DOCKERTAG}\${osSuffix} ${ALTDOCTAG} \${autotag}
    do
        [ "\${pushTag}" == "-" -o \${pushTag} == "" ] && continue
	if [ \${#pushTag} -gt \$(echo -n "\${pushTag}" | tr -d ":" | wc -c) ]
	then
		echo "Processing docker tag : \${pushTag}"
		finalTags="\${finalTags}\n        - \"--destination=\${pushTag}\""
	else
        	echo "Processing docker tag : evolveum/midpoint:\${pushTag}"
	        finalTags="\${finalTags}\n        - \"--destination=evolveum/midpoint:\${pushTag}\""
	fi
    done
    if [ "\${finalTags}" == "" ]
    then
	echo "No tag for push is available..."
	exit 1
    fi
    cat <<EOF | kubectl apply -f - | grep created | sed "s|\\([^[:space:]]*\\) created|\\1|"
apiVersion: v1
kind: Pod
metadata:
  name: kaniko-push-\${timestamp}
  namespace: jenkins
  labels:
    app: kaniko-push-\${timestamp}
    type: push
spec:
  volumes:
    - name: data
      emptyDir: {}
  initContainers:
    - name: kaniko-init
      image: 'alpine:latest'
      command: ["/bin/sh","-c"]
      args: ["nc -l -p 10123 | tee /opt/workspace/Dockerfile; nc -l -p 10124 >/opt/docker/config.json"]
      volumeMounts:
        - name: data
          mountPath: /opt/workspace
          subPath: workspace
        - name: data
          mountPath: /opt/docker
          subPath: docker
      imagePullPolicy: IfNotPresent
  containers:
    - name: kaniko
      image: gcr.io/kaniko-project/executor:latest
      args:
        - "--dockerfile=Dockerfile"
        - "--context=dir:///workspace"\${finalTags}
      volumeMounts:
        - name: data
          mountPath: /workspace
          subPath: workspace
        - name: data
          mountPath: /kaniko/.docker
          subPath: docker
  restartPolicy: Never
EOF
    
    podIPs="\$(kubectl get -n jenkins pod/kaniko-push-\${timestamp} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
    while [ "\${podIPs:0:1}" == ":" ]
    do
        sleep 5
        podIPs="\$(kubectl get -n jenkins pod/kaniko-push-\${timestamp} -o=jsonpath="{.status.podIP}{':'}{.status.hostIP}")"
    done
    podIP="\$(echo -n \${podIPs} | cut -d : -f 1)"

    echo "Pushing Dockerfile..."
    ret=1
    iteration=0
    while [ \${ret} -eq 1 -a \${iteration} -lt \${waitCycle} ] 
    do
        sleep 5
        cat <<EOF 2>/dev/null >/dev/tcp/\${podIP}/10123
FROM registry-\${timestamp}.lab.evolveum.com/midpoint:build-${DOCKERTAG}-${IMAGEOS}-\${timestamp}
LABEL AppBuildID="\${distInfo:-N/A}"
EOF
    	    ret=\$?
    	    iteration=\$(( \${iteration} + 1 ))
        done
        [ \${ret} -eq 0 ] && echo "Dockerfile has been pushed..."

        echo "Pushing docker creds..."
        ret=1
        iteration=0
        while [ \${ret} -eq 1 -a \${iteration} -lt \${waitCycle} ] 
        do
            sleep 5
	        cat <<EOF 2>/dev/null >/dev/tcp/\${podIP}/10124
{
	"auths": {
		"https://index.docker.io/v1/": {
			"auth": "\$(echo -n '${dockerUser}:${dockerPw}' | base64)"
		}
	}
}
EOF
    	ret=\$?
    	iteration=\$(( \${iteration} + 1 ))
    done
    [ \${ret} -eq 0 ] && echo "Docker creds have been pushed..."

    status=\$(kubectl get -n jenkins pod/kaniko-push-\${timestamp} -o=jsonpath="{.status.phase}")
    while [ "\${status}" == "Pending" -o "\${status}" == "Running" ]
    do
        sleep 15
        status=\$(kubectl get -n jenkins pod/kaniko-push-\${timestamp} -o=jsonpath="{.status.phase}")
    done
    echo "Downloading the log..."
    kubectl logs -n jenkins kaniko-push-\${timestamp} -c kaniko-init > logs-\${timestamp}/kaniko-push-\${pushTag}-init.log
    kubectl logs -n jenkins kaniko-push-\${timestamp} -c kaniko | tee logs-\${timestamp}/kaniko-push-\${pushTag}.log | grep "Applying\\|ush"
    kubectl delete -n jenkins pod/kaniko-push-\${timestamp}
fi

[ \${error} -ne 0 ] && exit 1
exit 0
                        """
                    }
                } catch (err) {
                    echo "Caught: ${err}"
                    unstable 'Error during push...'
                }
            }
        }
         stage ("cleanup environment") {
            container ("kubectl") {
                withKubeConfig([credentialsId: '6a647093-716e-4e8f-90bd-a8007be37f0e',
                        serverUrl: 'https://10.100.1.42:6443',
                        contextName: 'jenkins',
                        clusterName: 'kubernetes',
                        namespace: 'jenkins'
                        ]) {
                    try {
                        sh """#!/bin/bash
timestamp="\$(cat timestamp)"

kubectl delete -n jenkins \\
    ingress.networking.k8s.io/docker-registry-\${timestamp} \\
    service/docker-reg-\${timestamp} \\
    pod/docker-reg-\${timestamp} \\
    configmap/docker-reg-\${timestamp}-config \\
    secret/docker-reg-\${timestamp}-secret
    
echo "Preparing the archive with the logs..."
tar -cvzf logs.tgz logs-\${timestamp}
                    """
                    } catch (err) {
                        echo "Caught: ${err}"
                    }
                }
                archiveArtifacts allowEmptyArchive: true, artifacts: 'logs.tgz', followSymlinks: false                
            }
        }
    }
}
