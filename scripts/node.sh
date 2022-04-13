#!/usr/bin/env bash

echo "Running node.sh"

adminUsername=$1
adminPassword=$2
uniqueString=$3
location=$4
graphDatabaseVersion=$5
installGraphDataScience=$6
graphDataScienceLicenseKey=$7
installBloom=$8
bloomLicenseKey=$9
nodeCount=${10}
graphDataScienceVersion=${11}
bloomVersion=${12}
apocVersion=${13}

echo "Using the settings..."
echo "adminUsername: ${adminUsername}"
echo "adminPassword: ${adminPassword}"
echo "uniqueString: ${uniqueString}"
echo "location: ${location}"
echo "nodeCount: ${nodeCount}"
echo "graphDatabaseVersion: ${graphDatabaseVersion}"
echo "installGraphDataScience: ${installGraphDataScience}"
echo "graphDataScienceLicenseKey: ${graphDataScienceLicenseKey}"
echo "installBloom: ${installBloom}"
echo "bloomLicenseKey: ${bloomLicenseKey}"
echo "apocVersion: ${apocVersion}"
echo "bloomVersion: ${bloomVersion}"
echo "graphDataScienceVersion: ${graphDataScienceVersion}"

echo "Turning off firewalld"
systemctl stop firewalld
systemctl disable firewalld

echo Adding neo4j yum repo...
rpm --import https://debian.neo4j.com/neotechnology.gpg.key
echo "
[neo4j]
name=Neo4j Yum Repo
baseurl=http://yum.neo4j.com/stable
enabled=1
gpgcheck=1" > /etc/yum.repos.d/neo4j.repo

echo Installing Graph Database...
export NEO4J_ACCEPT_LICENSE_AGREEMENT=yes
yum -y install neo4j-enterprise-${graphDatabaseVersion}

echo Installing unzip...
yum -y install unzip

echo Configuring network in neo4j.conf...
sed -i 's/#dbms.default_listen_address=0.0.0.0/dbms.default_listen_address=0.0.0.0/g' /etc/neo4j/neo4j.conf


nodeIndex=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute?api-version=2017-03-01" \
  | jq ".name" \
  | sed 's/.*_//' \
  | sed 's/"//')
PUBLIC_HOST_NAME='vm'$nodeIndex'.node-'$uniqueString'.'$location'.cloudapp.azure.com'
echo "Advertising cluster at PUBLIC_HOST_NAME: ${PUBLIC_HOST_NAME}"
sed -i s/#dbms.default_advertised_address=localhost/dbms.default_advertised_address=${PUBLIC_HOST_NAME}/g /etc/neo4j/neo4j.conf

echo "Adding entries to /etc/hosts to route cluster traffic internally..."
echo "
# Route cluster traffic internally
10.0.0.4 vm0.node-${uniqueString}.${location}.cloudapp.azure.com
10.0.0.5 vm1.node-${uniqueString}.${location}.cloudapp.azure.com
10.0.0.6 vm2.node-${uniqueString}.${location}.cloudapp.azure.com
" >> /etc/hosts

echo Installing on ${nodeCount} node
if [[ $nodeCount == 1 ]]; then
  echo Running on a single node.
else
  echo Running on multiple nodes.  Configuring membership in neo4j.conf...
  coreMembers='vm0X,vm1X,vm2X'
  coreMembers=$(echo $coreMembers | sed 's/X/.node-'$uniqueString'.'$location'.cloudapp.azure.com:5000/g')
  sed -i s/#causal_clustering.initial_discovery_members=localhost:5000,localhost:5001,localhost:5002/causal_clustering.initial_discovery_members=${coreMembers}/g /etc/neo4j/neo4j.conf
  sed -i s/#dbms.mode=CORE/dbms.mode=CORE/g /etc/neo4j/neo4j.conf
fi


if [[ $installGraphDataScience == True && $nodeCount == 1 ]]; then
  if [[ $graphDataScienceVersion == None ]]; then
      echo Installing bundled Graph Data Science...
      cp /var/lib/neo4j/products/neo4j-graph-data-science-*.jar /var/lib/neo4j/plugins
  else
      echo Installing Graph Data Science $graphDataScienceVersion
      curl "https://graphdatascience.ninja/neo4j-graph-data-science-${graphDataScienceVersion}.zip" -o "neo4j-graph-data-science-${graphDataScienceVersion}.zip"
      unzip "neo4j-graph-data-science-${graphDataScienceVersion}.zip"
      cp "neo4j-graph-data-science-${graphDataScienceVersion}.jar" /var/lib/neo4j/plugins
  fi
else
    echo Not installing Graph Data Science
fi

if [[ $installBloom == True ]]; then
  if [[ $bloomVersion == None ]]; then
    echo Installing bundled Bloom
    cp /var/lib/neo4j/products/bloom-plugin-*.jar /var/lib/neo4j/plugins
  else
    echo Installing Bloom $bloomVersion
    curl -L "https://neo4j.com/artifact.php?name=neo4j-bloom-${bloomVersion}.zip" -o "neo4j-bloom-${bloomVersion}.zip"
    unzip neo4j-bloom-${bloomVersion}.zip
    cp "bloom-plugin-4.x-${bloomVersion}.jar" /var/lib/neo4j/plugins
  fi
else
    echo Not installing Bloom
fi

if [[ $bloomLicenseKey != None ]]; then
  echo Writing Bloom license key...
  mkdir -p /etc/neo4j/licenses
  echo $bloomLicenseKey > /etc/neo4j/licenses/neo4j-bloom.license
  sed -i '$a neo4j.bloom.license_file=/etc/neo4j/licenses/neo4j-bloom.license' /etc/neo4j/neo4j.conf
fi

if [[ $graphDataScienceLicenseKey != None ]]; then
  echo Writing GDS license key...
  mkdir -p /etc/neo4j/licenses
  echo $graphDataScienceLicenseKey > /etc/neo4j/licenses/neo4j-gds.license
  sed -i '$a gds.enterprise.license_file=/etc/neo4j/licenses/neo4j-gds.license' /etc/neo4j/neo4j.conf
fi

if [[ $apocVersion == None ]]; then
  echo Installing bundled Apoc
  cp /var/lib/neo4j/labs/apoc-*.jar /var/lib/neo4j/plugins
else
  echo Installing Apoc $apocVersion
  curl -L "https://github.com/neo4j-contrib/neo4j-apoc-procedures/releases/download/${apocVersion}/apoc-${apocVersion}-all.jar" -o "apoc-${apocVersion}-all.jar"
  cp "apoc-${apocVersion}-all.jar" /var/lib/neo4j/plugins
fi

echo Configuring extensions and security in neo4j.conf...
sed -i s~#dbms.unmanaged_extension_classes=org.neo4j.examples.server.unmanaged=/examples/unmanaged~dbms.unmanaged_extension_classes=com.neo4j.bloom.server=/bloom,semantics.extension=/rdf~g /etc/neo4j/neo4j.conf
sed -i s/#dbms.security.procedures.unrestricted=my.extensions.example,my.procedures.*/dbms.security.procedures.unrestricted=,jwt.security.*,apoc.*,gds.*,bloom.*,foo.*/g /etc/neo4j/neo4j.conf
sed -i s/gds.*,bloom.*/jwt.security.*,apoc.*,gds.*,bloom.*,foo.*/g /etc/neo4j/neo4j.conf
sed -i '$a dbms.security.http_auth_allowlist=/,/browser.*,/bloom.*,foo.*' /etc/neo4j/neo4j.conf
sed -i '$a dbms.security.procedures.allowlist=apoc.*,gds.*,bloom.*,foo.*' /etc/neo4j/neo4j.conf

echo Setting service permission bits to 644...
sudo chmod 644 /usr/lib/systemd/system/neo4j.service


echo Starting Neo4j...
service neo4j start
neo4j-admin set-initial-password ${adminPassword}