## Task 2

Create a nagios check that will detect if there are kafka topics that are not replicated on every kafka node. (If you don't know nagios, you could consider creating script that will output meaningful status)

## Task 3 (most important)

1. Set up (in kubernetes/minikube) 2 pods with a java example app:
https://github.com/TechPrimers/docker-mysql-spring-boot-example
In this example I've used helm as main templating solution, but i
  * clone this repo
    `git clone ...`
  * Build and push image  (Optional)
    ```
    cd docker
    docker build -t <your-tag> .
    docker push <your-tag>
    ```
  * Start minikube
    `$ minikube start`
  * Enable ingress addon
    `minikube addons enable ingress`
  * (Optional) Change minikube.values.yaml and update template
    ```
    cd k8s
    helm template -f minikube.values.yaml  helm --name sample  --namespace default > sample-app.yaml
    ```
  * Deploy app and DB to minikube
    `kubectl apply -f sample-app.yaml`
  * Get minikube ip for lb address
  `LB_IP=$(minikube ip)`
  * Check that everithin works
  ```curl --resolve sample-sample-app.local:80:$LB_IP http://sample-sample-app.local/all/create
  ```
  Output:
  ```[{"id":1,"name":"Sam","salary":3400,"teamName":"Development"}]
  ```

2. Load balance the traffic to the backends.
  * L-3 Traffic from clients is balanced by resource called service (only internal in this installation - type ClusterIP)
  * L-7 Traffic from external clients is balanced by resource called ingress (nginx-ingress contoroller)

3. Create policy to auto-heal or recreate the pod if it goes down or is unresponsive.
  * we should set strategy to `recreate` value.

4. Add a mysql.
  * Mysql added together with helm chart
  *minikube.values.yaml*
  ```
  ...
  mysql:
    enabled: true
    mysqlDatabase: test
    mysqlUser: sa
    mysqlPassword: password
  ```

(Points 5-8 are optional, you can pick any of them. You can write a description, or
actually implement a solution)
5. Can you do a HA of a database? Any way to keep the data persistent when pods are
recreated?
  1) Basically, you should use PV and PVC resources for persistent storages binds.
  2) Also StatefulSets is recommended mode for running this type of services.
  3) If you you need really HA cluster - you should use special solution as Percona Cluster or Galera Cluster with multi-master (danger setup) or just autopromotions followers to leaders. And if your DB is relatively big (~30 GB or more, IMHO), you should be careful with managing it in k8s.


6. Add CI to the deployment process.
  I haven't completed it, but this example is simple and don't require many changes from common pipelines implemented in any of CI-tools (Drone, Gitlab, Circle, etc).

  Just gitlab-ci.yml as an example:
```
image: alpine:latest

stages:
  - build
  - test
  - review
  - release
  - cleanup
  - deploy

trigger:
  stage: deploy
  script:
    - install_dependencies
    - curl -X POST -F token=$DEPLOY_JOB_TOKEN  -F ref=master -k http://gitlab-gitlab/api/v4/projects/7/trigger/pipeline
  only:
    - master

build:
  stage: build
  image: docker:git
  services:
    - docker:dind
  script:
    - setup_docker
    - build
  variables:
    DOCKER_DRIVER: overlay2
  only:
    - branches

test:
  stage: test
  script:
    - exit 0
  only:
    - branches

release:
  stage: release
  image: docker
  services:
    - docker:dind
  script:
    - setup_docker
    - release
  only:
    - master

review:
  stage: review
  script:
    - install_dependencies
    - ensure_namespace
    - install_tiller
    - deploy
  variables:
    KUBE_NAMESPACE: review
    host: $CI_PROJECT_PATH_SLUG-$CI_COMMIT_REF_SLUG
  environment:
    name: review/$CI_PROJECT_PATH/$CI_COMMIT_REF_NAME
    url: http://$CI_PROJECT_PATH_SLUG-$CI_COMMIT_REF_SLUG
    on_stop: stop_review
  only:
    refs:
      - branches
    kubernetes: active
  except:
    - master

stop_review:
  stage: cleanup
  variables:
    GIT_STRATEGY: none
  script:
    - install_dependencies
    - delete
  environment:
    name: review/$CI_PROJECT_PATH/$CI_COMMIT_REF_NAME
    action: stop
  when: manual
  allow_failure: true
  only:
    refs:
      - branches
    kubernetes: active
  except:
    - master

.auto_devops: &auto_devops |
  # Auto DevOps variables and functions
  [[ "$TRACE" ]] && set -x
  export CI_REGISTRY="index.docker.io"
  export CI_APPLICATION_REPOSITORY=$CI_REGISTRY/$CI_PROJECT_PATH
  export CI_APPLICATION_TAG=$CI_COMMIT_REF_SLUG
  export CI_CONTAINER_NAME=ci_job_build_${CI_JOB_ID}
  export TILLER_NAMESPACE="kube-system"

  function deploy() {
    track="${1-stable}"
    name="$CI_ENVIRONMENT_SLUG"

    if [[ "$track" != "stable" ]]; then
      name="$name-$track"
    fi

    git clone http://gitlab-gitlab/chromko/charts.git

    helm dep update charts/sample

    # cp -r chart sample/charts/$CI_PROJECT_NAME
    echo $CI_ENVIRONMENT_NAME
    helm upgrade --install \
      --wait \
      --set application.track="$track" \
      --set ui.ingress.host="$host" \
      --set $CI_PROJECT_NAME.image.tag=$CI_APPLICATION_TAG \
      --namespace="$KUBE_NAMESPACE" \
      --version="$CI_PIPELINE_ID-$CI_JOB_ID" \
      "$name" \
      charts/sample/
  }

  function install_dependencies() {

    apk add -U openssl curl tar gzip bash ca-certificates git
    wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/sgerrand.rsa.pub
    wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.23-r3/glibc-2.23-r3.apk
    apk add glibc-2.23-r3.apk
    rm glibc-2.23-r3.apk

    curl https://storage.googleapis.com/pub/gsutil.tar.gz | tar -xz -C $HOME
    export PATH=${PATH}:$HOME/gsutil

    curl https://kubernetes-helm.storage.googleapis.com/helm-v2.7.2-linux-amd64.tar.gz | tar zx

    mv linux-amd64/helm /usr/bin/
    helm version --client

    curl  -o /usr/bin/sync-repo.sh https://raw.githubusercontent.com/kubernetes/helm/master/scripts/sync-repo.sh
    chmod a+x /usr/bin/sync-repo.sh

    curl -L -o /usr/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
    chmod +x /usr/bin/kubectl
    kubectl version --client
  }

  function setup_docker() {
    if ! docker info &>/dev/null; then
      if [ -z "$DOCKER_HOST" -a "$KUBERNETES_PORT" ]; then
        export DOCKER_HOST='tcp://localhost:2375'
      fi
    fi
  }

  function ensure_namespace() {
    kubectl describe namespace "$KUBE_NAMESPACE" || kubectl create namespace "$KUBE_NAMESPACE"
  }

  function release() {

    echo "Updating docker images ..."

    if [[ -n "$CI_REGISTRY_USER" ]]; then
      echo "Logging to GitLab Container Registry with CI credentials..."
      docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD"
      echo ""
    fi

    docker pull "$CI_APPLICATION_REPOSITORY:$CI_APPLICATION_TAG"
    docker tag "$CI_APPLICATION_REPOSITORY:$CI_APPLICATION_TAG" "$CI_APPLICATION_REPOSITORY:$(cat VERSION)"
    docker push "$CI_APPLICATION_REPOSITORY:$(cat VERSION)"
    echo ""
  }

  function build() {

    echo "Building Dockerfile-based application..."
    echo `git show --format="%h" HEAD | head -1` > build_info.txt
    echo `git rev-parse --abbrev-ref HEAD` >> build_info.txt
    docker build -t "$CI_APPLICATION_REPOSITORY:$CI_APPLICATION_TAG" .

    if [[ -n "$CI_REGISTRY_USER" ]]; then
      echo "Logging to GitLab Container Registry with CI credentials..."
      docker login -u "$CI_REGISTRY_USER" -p "$CI_REGISTRY_PASSWORD"
      echo ""
    fi

    echo "Pushing to GitLab Container Registry..."
    docker push "$CI_APPLICATION_REPOSITORY:$CI_APPLICATION_TAG"
    echo ""
  }

  function install_tiller() {
    echo "Checking Tiller..."
    helm init --upgrade
    kubectl rollout status -n "$TILLER_NAMESPACE" -w "deployment/tiller-deploy"
    if ! helm version --debug; then
      echo "Failed to init Tiller."
      return 1
    fi
    echo ""
  }

  function delete() {
    track="${1-stable}"
    name="$CI_ENVIRONMENT_SLUG"

    if [[ "$track" != "stable" ]]; then
      name="$name-$track"
    fi

    helm delete "$name" || true
  }


before_script:
  - *auto_devops

```
7. Split your deployment into prd/qa/dev environment.

  Watch stages review/staging/production above

8. Please suggest a monitoring solution for your system. How would you notify an admin that the resources are scarce

  You should use those monitoring tool that fits for your needs. If it's an environment with very high velocity of changes, many boilerplaited nodes, applications and services than you definitely should label-based monitoring solutions like: Prometheus , Tick stack, Graphite. Of course, you should provide any Service-Discovery solution.

  If you just need to trigger that free space on your disk is scarced, than you can use any monitoring tool, that you know (Zabbix, Nagios)but why?

