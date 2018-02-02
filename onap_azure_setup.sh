#!/bin/bash
while getopts :f:i:r: opt; do
	case $opt in
		f)
			fqdn="$OPTARG"
			;;
		i)
			ip="$OPTARG"
			;;
		r)
			branch="$OPTARG"
			;;
	esac
done

##/var/lib/waagent/custom-script/download/0

sudo su -
#copy onap-parmteters.yaml
#copy oom_rancher_setup.sh
#get prepull - curl https://jira.onap.org/secure/.... prepull_docker.sh
#copy cd.sh
#chmod 777
wget -O oom_rancher_setup_1.sh https://wiki.onap.org/download/attachments/8227431/oom_rancher_setup_1.sh?version=6&modificationDate=1516919271000&api=v2
#wget https://raw.githubusercontent.com/taranki/onap-azure/master/oom_rancher_setup.sh
chmod +x ./oom_rancher_setup_1.sh

wget -O ch.sh https://wiki.onap.org/download/attachments/8227431/cd.sh?version=6&modificationDate=1516857176000&api=v2
#wget https://raw.githubusercontent.com/taranki/onap-azure/master/cd.sh
chmod +x ./cd.sh

wget https://raw.githubusercontent.com/taranki/onap-azure/master/onap-parameters.yaml
wget https://raw.githubusercontent.com/taranki/onap-azure/master/aai-cloud-region-put.json
wget https://raw.githubusercontent.com/taranki/onap-azure/master/aaiapisimpledemoopenecomporg.cer


# install rancher
./oom_rancher_setup_1.sh

# install jq for json parsing
apt-get --assume-yes install jq

##--- Heavily borrowed from vagrant project: https://github.com/rancher/vagrant
echo "Create new Envrionment for Kube and delete Default"
# lookup orchestrator template id
orchestrator=kubernetes

while true; do
  ENV_TEMPLATE_ID=$(docker run \
    -v /tmp:/tmp \
    --rm \
    appropriate/curl \
      -sLk \
        "$fqdn:8880/v2-beta/projectTemplates?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

  # might've received 422 InvalidReference if the templates haven't populated yet
  if [[ "$ENV_TEMPLATE_ID" == 1pt* ]]; then
    break
  else
    sleep 5
  fi
done
echo "found template id $ENV_TEMPLATE_ID"

# create an environment with specified orchestrator template
docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -sLk \
    -X POST \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d "{\"description\":\"$orchestrator\",\"name\":\"$orchestrator\",\"projectTemplateId\":\"$ENV_TEMPLATE_ID\",\"allowSystemRole\":false,\"members\":[],\"virtualMachine\":false,\"servicesPortRange\":null}" \
      "$fqdn:8880/v2-beta/projects"

# lookup default environment id
DEFAULT_ENV_ID=$(docker run -v /tmp:/tmp --rm appropriate/curl -sLk "$fqdn:8880/v2-beta/project?name=Default" | jq '.data[0].id' | tr -d '"')

# delete default environment
docker run \
  --rm \
  appropriate/curl \
    -sLk \
    -X DELETE \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -d '{}' \
      "$fqdn:8880/v2-beta/projects/$DEFAULT_ENV_ID/?action=delete"


echo "Adding host to Rancher"
# get our new env id
while true; do
  ENV_ID=$(docker run \
    -v /tmp:/tmp \
    --rm \
    appropriate/curl \
      -sLk \
      "$fqdn:8880/v2-beta/project?name=$orchestrator" | jq '.data[0].id' | tr -d '"')

  if [[ "$ENV_ID" == 1a* ]]; then
    break
  else
    sleep 5
  fi
done

docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -sLk \
    -X POST \
    -H 'Content-Type: application/json' \
    -H 'accept: application/json' \
    -d "{\"type\":\"registrationToken\"}" \
      "$fqdn:8880/v2-beta/projects/$ENV_ID/registrationtoken"

docker run \
  -v /tmp:/tmp \
  --rm \
  appropriate/curl \
    -sLk \
    "$fqdn:8880/v2-beta/projects/$ENV_ID/registrationtokens/?state=active" |
      jq -r .data[].command |
      head -n1 |
      sh

#sleep for a few minutes to allow kube to come up properly and get config
sleep 5m

# get config for kube from rancher
echo "Creating api key for use in kube"
curl -o apikey.json -s -N -X POST -H "Content-Type: application/json; x-api-no-challenge: true"  -d '{"type":"apiKey","accountId":"1a1","name":"kubectl","description":"Provides workstation access to kubectl"}' "$fqdn:8880/v2-beta/apikey"

pv=$(jq ".publicValue" apikey.json)
sv=$(jq ".secretValue" apikey.json)
token=$(echo -n "Basic $(echo -n "$pv:$sv" | base64 -w 0)" | base64 -w 0)

#create kube config
echo "Creating kube config for $fqdn"
cd ~/.kube
curl -o config -s "https://raw.githubusercontent.com/taranki/onap-azure/master/config"
# mod the fqdn to use https
if [[ $fqdn != http* ]]
then
fqdns="https://${fqdn}"
else
fqdns=${fqdn//http:/https:}
fi
fqdns=${fqdns//\//\\\/}

# replace vars in config file template
sed -i -e "s/_fqdn_/$fqdns/g" config
sed -i -e "s/_tok_/$token/g" config

# go back to where our scripts are executing
cd -

# get docker images
docker pull aaionap/gremlin-server
docker pull aaionap/haproxy:1.1.0
docker pull aaionap/hbase:1.2.0
docker pull attos/dmaap:latest
docker pull busybox
docker pull consul:0.9.3
docker pull docker.elastic.co/beats/filebeat:5.5.0
docker pull docker.elastic.co/beats/filebeat:5.5.0
docker pull docker.elastic.co/beats/filebeat:5.5.0
docker pull docker.elastic.co/elasticsearch/elasticsearch:5.5.0
docker pull docker.elastic.co/kibana/kibana:5.5.0
docker pull docker.elastic.co/logstash/logstash:5.4.3
docker pull dorowu/ubuntu-desktop-lxde-vnc
docker pull elasticsearch:2.4.1
docker pull mysql/mysql-server:5.6
docker pull mysql/mysql-server:5.6
docker pull nexus3.onap.org:10001/library/cassandra:2.1.17
docker pull nexus3.onap.org:10001/library/mariadb:10
docker pull nexus3.onap.org:10001/mariadb:10.1.11
docker pull nexus3.onap.org:10001/onap/aaf/authz-service:latest
docker pull nexus3.onap.org:10001/onap/admportal-sdnc-image:v1.2.1
docker pull nexus3.onap.org:10001/onap/ccsdk-dgbuilder-image:v0.1.0
docker pull nexus3.onap.org:10001/onap/ccsdk-dgbuilder-image:v0.1.0
docker pull nexus3.onap.org:10001/onap/clamp:v1.1.0
docker pull nexus3.onap.org:10001/onap/cli:v1.1.0
docker pull nexus3.onap.org:10001/onap/data-router:v1.1.0
docker pull nexus3.onap.org:10001/onap/model-loader:v1.1.0
docker pull nexus3.onap.org:10001/onap/msb/msb_apigateway:1.0.0
docker pull nexus3.onap.org:10001/onap/msb/msb_discovery:1.0.0
docker pull nexus3.onap.org:10001/onap/multicloud/framework:v1.0.0
docker pull nexus3.onap.org:10001/onap/multicloud/openstack-ocata:v1.0.0
docker pull nexus3.onap.org:10001/onap/multicloud/openstack-windriver:v1.0.0
docker pull nexus3.onap.org:10001/onap/multicloud/vio:v1.0.0
docker pull nexus3.onap.org:10001/onap/oom/kube2msb
docker pull nexus3.onap.org:10001/onap/policy/policy-db:v1.1.1
docker pull nexus3.onap.org:10001/onap/policy/policy-drools:v1.1.1
docker pull nexus3.onap.org:10001/onap/policy/policy-nexus:v1.1.1
docker pull nexus3.onap.org:10001/onap/policy/policy-pe:v1.1.1
docker pull nexus3.onap.org:10001/onap/portal-apps:v1.3.0
docker pull nexus3.onap.org:10001/onap/portal-db:v1.3.0
docker pull nexus3.onap.org:10001/onap/portal-wms:v1.3.0
docker pull nexus3.onap.org:10001/onap/refrepo/postgres:latest
docker pull nexus3.onap.org:10001/onap/refrepo:1.0-STAGING-latest
docker pull nexus3.onap.org:10001/onap/sdnc-dmaap-listener-image:v1.2.1
docker pull nexus3.onap.org:10001/onap/sdnc-image:v1.2.1
docker pull nexus3.onap.org:10001/onap/sdnc-ueb-listener-image:v1.2.1
docker pull nexus3.onap.org:10001/onap/search-data-service:v1.1.0
docker pull nexus3.onap.org:10001/onap/sniroemulator:latest
docker pull nexus3.onap.org:10001/onap/sparky-be:v1.1.0
docker pull nexus3.onap.org:10001/onap/usecase-ui/usecase-ui-server:v1.0.1
docker pull nexus3.onap.org:10001/onap/usecase-ui:v1.0.1
docker pull nexus3.onap.org:10001/onap/vfc/catalog:v1.0.2
docker pull nexus3.onap.org:10001/onap/vfc/emsdriver:v1.0.1
docker pull nexus3.onap.org:10001/onap/vfc/gvnfmdriver:v1.0.1
docker pull nexus3.onap.org:10001/onap/vfc/jujudriver:v1.0.0
docker pull nexus3.onap.org:10001/onap/vfc/nfvo/svnfm/huawei:v1.0.2
docker pull nexus3.onap.org:10001/onap/vfc/nfvo/svnfm/nokia:v1.0.2
docker pull nexus3.onap.org:10001/onap/vfc/nslcm:v1.0.2
docker pull nexus3.onap.org:10001/onap/vfc/resmanagement:v1.0.0
docker pull nexus3.onap.org:10001/onap/vfc/vnflcm:v1.0.1
docker pull nexus3.onap.org:10001/onap/vfc/vnfmgr:v1.0.1
docker pull nexus3.onap.org:10001/onap/vfc/vnfres:v1.0.1
docker pull nexus3.onap.org:10001/onap/vfc/wfengine-activiti:v1.0.0
docker pull nexus3.onap.org:10001/onap/vfc/wfengine-mgrservice:v1.0.0
docker pull nexus3.onap.org:10001/onap/vfc/ztesdncdriver:v1.0.0
docker pull nexus3.onap.org:10001/onap/vfc/ztevmanagerdriver:v1.0.2
docker pull nexus3.onap.org:10001/openecomp/aai-resources:v1.1.0
docker pull nexus3.onap.org:10001/openecomp/aai-traversal:v1.1.0
docker pull nexus3.onap.org:10001/openecomp/appc-image:v1.2.0
docker pull nexus3.onap.org:10001/openecomp/dcae-collector-common-event:1.1-STAGING-latest
docker pull nexus3.onap.org:10001/openecomp/dcae-controller:1.1-STAGING-latest
docker pull nexus3.onap.org:10001/openecomp/dcae-dmaapbc:1.1-STAGING-latest
docker pull nexus3.onap.org:10001/openecomp/mso:v1.1.1
docker pull nexus3.onap.org:10001/openecomp/sdc-backend:v1.1.0
docker pull nexus3.onap.org:10001/openecomp/sdc-cassandra:v1.1.0
docker pull nexus3.onap.org:10001/openecomp/sdc-elasticsearch:v1.1.0
docker pull nexus3.onap.org:10001/openecomp/sdc-frontend:v1.1.0
docker pull nexus3.onap.org:10001/openecomp/sdc-kibana:v1.1.0
docker pull nexus3.onap.org:10001/openecomp/testsuite:1.2-STAGING-latest
docker pull nexus3.onap.org:10001/openecomp/vid:v1.1.1
docker pull nginx:stable
docker pull oomk8s/cdap:1.0.7
docker pull oomk8s/cdap-fs:1.0.0
docker pull oomk8s/config-init:1.1.6
docker pull oomk8s/mariadb-client-init:1.0.0
docker pull oomk8s/pgaas:1
docker pull oomk8s/readiness-check:1.0.0
docker pull oomk8s/readiness-check:1.0.0
docker pull oomk8s/readiness-check:1.0.0
docker pull oomk8s/readiness-check:1.0.0
docker pull oomk8s/readiness-check:1.0.0
docker pull oomk8s/ubuntu-init:1.0.0
docker pull ubuntu:16.04
docker pull ubuntu:xenial
docker pull wurstmeister/kafka:latest
docker pull wurstmeister/zookeeper:latest
docker pull rancher/server:v1.6.10

echo "Calling CD script"
./cd.sh -b $branch


