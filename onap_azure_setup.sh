#!/bin/bash
while getopts :f:i:r opt; do
	case $opt in
		f)
			fqdn="$OPTARG"
			;;
		i)
			ip="$OPTARG"
			;;
		r)
			BRANCH="$OPTARG"
			;;
	esac
done


#sudo su -
#copy onap-parmteters.yaml
#copy oom_rancher_setup.sh
#get prepull - curl https://jira.onap.org/secure/.... prepull_docker.sh
#copy cd.sh
#chmod 777

wget https://raw.githubusercontent.com/taranki/onap-azure/master/oom_rancher_setup.sh
chmod 777 oom_rancher.sh

wget https://raw.githubusercontent.com/taranki/onap-azure/master/cd.sh
chmod 777 cd.sh

wget https://raw.githubusercontent.com/taranki/onap-azure/master/onap-parameters.yaml
wget https://raw.githubusercontent.com/taranki/onap-azure/master/aai-cloud-region-put.json
wget https://raw.githubusercontent.com/taranki/onap-azure/master/aaiapisimpledemoopenecomporg.cer

# install rancher
./oom_rancher_setup.sh

# install jq for json parsing
sudo apt install jq



# add onap environtment to rancher
newenv=$(curl -X POST -H "Content-Type: application/json" -b "PL=rancher; CSRF=AEF0B17B2F" -d '{"allowSystemRole":false,"virtualMachine":false,"type":"project","name":"onap","description":"onap","projectTemplateId":"1pt1","projectMembers":[],"created":null,"healthState":null,"kind":null,"removeTime":null,"removed":null,"uuid":null,"version":null,"hostRemoveDelaySeconds":null,"members":[]}' "$fqdn:8880/v2-beta/project" | jq '.data[1].id')

# set default environment
curl -X PUT -H "Content-Type: application/json" -b "PL=rancher; CSRF=AEF0B17B2F" -d '{"type":"userPreference","name":"defaultProjectId","value":"\"$newenv\"","id":"1up3","baseType":"userPreference","state":"registering","accountId":"1a1","all":false,"created":"2018-01-28T05:45:13Z","createdTS":1517118313000,"data":{},"description":null,"kind":"userPreference","removeTime":null,"removed":null,"transitioning":"yes","transitioningMessage":"In Progress","uuid":"08debe39-02b6-4b08-bca5-cb50646404c7"}'  "$fqdn:8880/v2-beta/userpreferences/1up3"

# add host
sudo docker run --rm --privileged -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/rancher:/var/lib/rancher rancher/agent:v1.2.6 $fqdn:8880/v1/scripts/4779672C535852CC8442:1514678400000:8dYgVDQp4Ax91XwceA75CL1gazA

#sleep for a few minutes to allow kube to come up properly and get config
sleep 5m

#apikey=$(curl -X POST -H "Content-Type: application/json" -d '{"type":"apiKey","accountId":"1a1","name":"kubectl","description":"Provides workstation access to kubectl"}' "$fqdn:8880/v2-beta/apikey"
# get config for kube from rancher
curl -o apikey.json -s -N -X POST -H "Content-Type: application/json;x-api-csrf: AEF0B17B2F; x-api-no-challenge: true"  -d '{"type":"apiKey","accountId":"1a1","name":"kubectl","description":"Provides workstation access to kubectl"}' "$fqdn:8880/v2-beta/apikey" | jq '.id')
id=jq ".data[1].id" apikey.json
pv=jq ".publicValue" apikey.json
sv=jq ".secretValue" apikey.json

token=$(echo -n "Basic $(echo -n "$pv:$sv" | base64 -w 0)" | base64 -w 0)

#create kube config
mkdir .kube
cd .kube
curl -o config -s "https://raw.githubusercontent.com/taranki/onap-azure/master/config"
# mod the fqdn to use https
fqdn=${fqdn//http:/https:}

# replace vars in config file template
sed -i -e 's/_fqdn_/$fqdn/g' config
sed -i -e 's/_tok_/$token/g' config

cd ..

# get docker images
sudo docker pull aaionap/gremlin-server
sudo docker pull aaionap/haproxy:1.1.0
sudo docker pull aaionap/hbase:1.2.0
sudo docker pull attos/dmaap:latest
sudo docker pull busybox
sudo docker pull consul:0.9.3
sudo docker pull docker.elastic.co/beats/filebeat:5.5.0
sudo docker pull docker.elastic.co/beats/filebeat:5.5.0
sudo docker pull docker.elastic.co/beats/filebeat:5.5.0
sudo docker pull docker.elastic.co/elasticsearch/elasticsearch:5.5.0
sudo docker pull docker.elastic.co/kibana/kibana:5.5.0
sudo docker pull docker.elastic.co/logstash/logstash:5.4.3
sudo docker pull dorowu/ubuntu-desktop-lxde-vnc
sudo docker pull elasticsearch:2.4.1
sudo docker pull mysql/mysql-server:5.6
sudo docker pull mysql/mysql-server:5.6
sudo docker pull nexus3.onap.org:10001/library/cassandra:2.1.17
sudo docker pull nexus3.onap.org:10001/library/mariadb:10
sudo docker pull nexus3.onap.org:10001/mariadb:10.1.11
sudo docker pull nexus3.onap.org:10001/onap/aaf/authz-service:latest
sudo docker pull nexus3.onap.org:10001/onap/admportal-sdnc-image:v1.2.1
sudo docker pull nexus3.onap.org:10001/onap/ccsdk-dgbuilder-image:v0.1.0
sudo docker pull nexus3.onap.org:10001/onap/ccsdk-dgbuilder-image:v0.1.0
sudo docker pull nexus3.onap.org:10001/onap/clamp:v1.1.0
sudo docker pull nexus3.onap.org:10001/onap/cli:v1.1.0
sudo docker pull nexus3.onap.org:10001/onap/data-router:v1.1.0
sudo docker pull nexus3.onap.org:10001/onap/model-loader:v1.1.0
sudo docker pull nexus3.onap.org:10001/onap/msb/msb_apigateway:1.0.0
sudo docker pull nexus3.onap.org:10001/onap/msb/msb_discovery:1.0.0
sudo docker pull nexus3.onap.org:10001/onap/multicloud/framework:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/multicloud/openstack-ocata:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/multicloud/openstack-windriver:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/multicloud/vio:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/oom/kube2msb
sudo docker pull nexus3.onap.org:10001/onap/policy/policy-db:v1.1.1
sudo docker pull nexus3.onap.org:10001/onap/policy/policy-drools:v1.1.1
sudo docker pull nexus3.onap.org:10001/onap/policy/policy-nexus:v1.1.1
sudo docker pull nexus3.onap.org:10001/onap/policy/policy-pe:v1.1.1
sudo docker pull nexus3.onap.org:10001/onap/portal-apps:v1.3.0
sudo docker pull nexus3.onap.org:10001/onap/portal-db:v1.3.0
sudo docker pull nexus3.onap.org:10001/onap/portal-wms:v1.3.0
sudo docker pull nexus3.onap.org:10001/onap/refrepo/postgres:latest
sudo docker pull nexus3.onap.org:10001/onap/refrepo:1.0-STAGING-latest
sudo docker pull nexus3.onap.org:10001/onap/sdnc-dmaap-listener-image:v1.2.1
sudo docker pull nexus3.onap.org:10001/onap/sdnc-image:v1.2.1
sudo docker pull nexus3.onap.org:10001/onap/sdnc-ueb-listener-image:v1.2.1
sudo docker pull nexus3.onap.org:10001/onap/search-data-service:v1.1.0
sudo docker pull nexus3.onap.org:10001/onap/sniroemulator:latest
sudo docker pull nexus3.onap.org:10001/onap/sparky-be:v1.1.0
sudo docker pull nexus3.onap.org:10001/onap/usecase-ui/usecase-ui-server:v1.0.1
sudo docker pull nexus3.onap.org:10001/onap/usecase-ui:v1.0.1
sudo docker pull nexus3.onap.org:10001/onap/vfc/catalog:v1.0.2
sudo docker pull nexus3.onap.org:10001/onap/vfc/emsdriver:v1.0.1
sudo docker pull nexus3.onap.org:10001/onap/vfc/gvnfmdriver:v1.0.1
sudo docker pull nexus3.onap.org:10001/onap/vfc/jujudriver:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/vfc/nfvo/svnfm/huawei:v1.0.2
sudo docker pull nexus3.onap.org:10001/onap/vfc/nfvo/svnfm/nokia:v1.0.2
sudo docker pull nexus3.onap.org:10001/onap/vfc/nslcm:v1.0.2
sudo docker pull nexus3.onap.org:10001/onap/vfc/resmanagement:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/vfc/vnflcm:v1.0.1
sudo docker pull nexus3.onap.org:10001/onap/vfc/vnfmgr:v1.0.1
sudo docker pull nexus3.onap.org:10001/onap/vfc/vnfres:v1.0.1
sudo docker pull nexus3.onap.org:10001/onap/vfc/wfengine-activiti:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/vfc/wfengine-mgrservice:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/vfc/ztesdncdriver:v1.0.0
sudo docker pull nexus3.onap.org:10001/onap/vfc/ztevmanagerdriver:v1.0.2
sudo docker pull nexus3.onap.org:10001/openecomp/aai-resources:v1.1.0
sudo docker pull nexus3.onap.org:10001/openecomp/aai-traversal:v1.1.0
sudo docker pull nexus3.onap.org:10001/openecomp/appc-image:v1.2.0
sudo docker pull nexus3.onap.org:10001/openecomp/dcae-collector-common-event:1.1-STAGING-latest
sudo docker pull nexus3.onap.org:10001/openecomp/dcae-controller:1.1-STAGING-latest
sudo docker pull nexus3.onap.org:10001/openecomp/dcae-dmaapbc:1.1-STAGING-latest
sudo docker pull nexus3.onap.org:10001/openecomp/mso:v1.1.1
sudo docker pull nexus3.onap.org:10001/openecomp/sdc-backend:v1.1.0
sudo docker pull nexus3.onap.org:10001/openecomp/sdc-cassandra:v1.1.0
sudo docker pull nexus3.onap.org:10001/openecomp/sdc-elasticsearch:v1.1.0
sudo docker pull nexus3.onap.org:10001/openecomp/sdc-frontend:v1.1.0
sudo docker pull nexus3.onap.org:10001/openecomp/sdc-kibana:v1.1.0
sudo docker pull nexus3.onap.org:10001/openecomp/testsuite:1.2-STAGING-latest
sudo docker pull nexus3.onap.org:10001/openecomp/vid:v1.1.1
sudo docker pull nginx:stable
sudo docker pull oomk8s/cdap:1.0.7
sudo docker pull oomk8s/cdap-fs:1.0.0
sudo docker pull oomk8s/config-init:1.1.6
sudo docker pull oomk8s/mariadb-client-init:1.0.0
sudo docker pull oomk8s/pgaas:1
sudo docker pull oomk8s/readiness-check:1.0.0
sudo docker pull oomk8s/readiness-check:1.0.0
sudo docker pull oomk8s/readiness-check:1.0.0
sudo docker pull oomk8s/readiness-check:1.0.0
sudo docker pull oomk8s/readiness-check:1.0.0
sudo docker pull oomk8s/ubuntu-init:1.0.0
sudo docker pull ubuntu:16.04
sudo docker pull ubuntu:xenial
sudo docker pull wurstmeister/kafka:latest
sudo docker pull wurstmeister/zookeeper:latest
sudo docker pull rancher/server:v1.6.10

./cd.sh


