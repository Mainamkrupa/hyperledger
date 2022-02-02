#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

function launch() {
  local yaml=$1
  cat ${yaml} \
    | sed 's,{{FABRIC_CONTAINER_REGISTRY}},'${FABRIC_CONTAINER_REGISTRY}',g' \
    | sed 's,{{FABRIC_VERSION}},'${FABRIC_VERSION}',g' \
    | kubectl -n $NS apply -f -
}

function launch_orderers() {
  push_fn "Launching orderers"

  launch kube/org0/org0-orderer1.yaml
  launch kube/org0/org0-orderer2.yaml
  launch kube/org0/org0-orderer3.yaml

  kubectl -n $NS rollout status deploy/org0-orderer1
  kubectl -n $NS rollout status deploy/org0-orderer2
  kubectl -n $NS rollout status deploy/org0-orderer3

  pop_fn
}

function launch_peers() {
  push_fn "Launching peers"

  launch kube/org1/org1-peer1.yaml
  launch kube/org1/org1-peer2.yaml
  launch kube/org2/org2-peer1.yaml
  launch kube/org2/org2-peer2.yaml

  kubectl -n $NS rollout status deploy/org1-peer1
  kubectl -n $NS rollout status deploy/org1-peer2
  kubectl -n $NS rollout status deploy/org2-peer1
  kubectl -n $NS rollout status deploy/org2-peer2

  pop_fn
}

function create_org0_local_MSP() {
  echo 'set -x
  export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/var/hyperledger/fabric/config/tls/ca.crt

  # Each identity in the network needs a registration and enrollment.
  fabric-ca-client register --id.name org0-orderer1 --id.secret ordererpw --id.type orderer --url https://org0-ca --mspdir $FABRIC_CA_CLIENT_HOME/org0-ca/rcaadmin/msp
  fabric-ca-client register --id.name org0-orderer2 --id.secret ordererpw --id.type orderer --url https://org0-ca --mspdir $FABRIC_CA_CLIENT_HOME/org0-ca/rcaadmin/msp
  fabric-ca-client register --id.name org0-orderer3 --id.secret ordererpw --id.type orderer --url https://org0-ca --mspdir $FABRIC_CA_CLIENT_HOME/org0-ca/rcaadmin/msp
  fabric-ca-client register --id.name org0-admin --id.secret org0adminpw  --id.type admin   --url https://org0-ca --mspdir $FABRIC_CA_CLIENT_HOME/org0-ca/rcaadmin/msp --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

  fabric-ca-client enroll --url https://org0-orderer1:ordererpw@org0-ca --csr.hosts org0-orderer1 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/msp
  fabric-ca-client enroll --url https://org0-orderer2:ordererpw@org0-ca --csr.hosts org0-orderer2 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer2.org0.example.com/msp
  fabric-ca-client enroll --url https://org0-orderer3:ordererpw@org0-ca --csr.hosts org0-orderer3 --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer3.org0.example.com/msp
  fabric-ca-client enroll --url https://org0-admin:org0adminpw@org0-ca --mspdir /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/users/Admin@org0.example.com/msp

  # Create an MSP config.yaml (why is this not generated by the enrollment by fabric-ca-client?)
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/org0-ca.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/org0-ca.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/org0-ca.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/org0-ca.pem
      OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/msp/config.yaml

  cp /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer2.org0.example.com/msp/config.yaml
  cp /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer1.org0.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/org0-orderer3.org0.example.com/msp/config.yaml
  ' | exec kubectl -n $NS exec deploy/org0-ca -i -- /bin/sh
}

function create_org1_local_MSP() {

  echo 'set -x
  export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/var/hyperledger/fabric/config/tls/ca.crt

  # Each identity in the network needs a registration and enrollment.
  fabric-ca-client register --id.name org1-peer1 --id.secret peerpw --id.type peer --url https://org1-ca --mspdir $FABRIC_CA_CLIENT_HOME/org1-ca/rcaadmin/msp
  fabric-ca-client register --id.name org1-peer2 --id.secret peerpw --id.type peer --url https://org1-ca --mspdir $FABRIC_CA_CLIENT_HOME/org1-ca/rcaadmin/msp
  fabric-ca-client register --id.name org1-admin --id.secret org1adminpw  --id.type admin   --url https://org1-ca --mspdir $FABRIC_CA_CLIENT_HOME/org1-ca/rcaadmin/msp --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

  fabric-ca-client enroll --url https://org1-peer1:peerpw@org1-ca --csr.hosts org1-peer1,org1-peer-gateway-svc --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/msp
  fabric-ca-client enroll --url https://org1-peer2:peerpw@org1-ca --csr.hosts org1-peer2,org1-peer-gateway-svc --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer2.org1.example.com/msp
  fabric-ca-client enroll --url https://org1-admin:org1adminpw@org1-ca  --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp

  cp /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/keystore/server.key

  # Create local MSP config.yaml
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/org1-ca.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/org1-ca.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/org1-ca.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/org1-ca.pem
      OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/msp/config.yaml


  cp /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer2.org1.example.com/msp/config.yaml
  cp /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/peers/org1-peer1.org1.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp/config.yaml
  ' | exec kubectl -n $NS exec deploy/org1-ca -i -- /bin/sh
}

function create_org2_local_MSP() {
  echo 'set -x
  export FABRIC_CA_CLIENT_HOME=/var/hyperledger/fabric-ca-client
  export FABRIC_CA_CLIENT_TLS_CERTFILES=/var/hyperledger/fabric/config/tls/ca.crt

  # Each identity in the network needs a registration and enrollment.
  fabric-ca-client register --id.name org2-peer1 --id.secret peerpw --id.type peer --url https://org2-ca --mspdir $FABRIC_CA_CLIENT_HOME/org2-ca/rcaadmin/msp
  fabric-ca-client register --id.name org2-peer2 --id.secret peerpw --id.type peer --url https://org2-ca --mspdir $FABRIC_CA_CLIENT_HOME/org2-ca/rcaadmin/msp
  fabric-ca-client register --id.name org2-admin --id.secret org2adminpw  --id.type admin   --url https://org2-ca --mspdir $FABRIC_CA_CLIENT_HOME/org2-ca/rcaadmin/msp --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"

  fabric-ca-client enroll --url https://org2-peer1:peerpw@org2-ca --csr.hosts org2-peer1,org2-peer-gateway-svc --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/msp
  fabric-ca-client enroll --url https://org2-peer2:peerpw@org2-ca --csr.hosts org2-peer2,org2-peer-gateway-svc --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer2.org2.example.com/msp
  fabric-ca-client enroll --url https://org2-admin:org2adminpw@org2-ca  --mspdir /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp

  cp /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp/keystore/*_sk /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp/keystore/server.key

  # Create local MSP config.yaml
  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
      Certificate: cacerts/org2-ca.pem
      OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
      Certificate: cacerts/org2-ca.pem
      OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
      Certificate: cacerts/org2-ca.pem
      OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
      Certificate: cacerts/org2-ca.pem
      OrganizationalUnitIdentifier: orderer" > /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/msp/config.yaml

  cp /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer2.org2.example.com/msp/config.yaml
  cp /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/peers/org2-peer1.org2.example.com/msp/config.yaml /var/hyperledger/fabric/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp/config.yaml
  ' | exec kubectl -n $NS exec deploy/org2-ca -i -- /bin/sh
}

function create_local_MSP() {
  push_fn "Creating local node MSP"

  create_org0_local_MSP
  create_org1_local_MSP
  create_org2_local_MSP

  pop_fn
}

# TLS certificates are isused by the CA's Issuer, stored in a Kube secret, and mounted into the pod at /var/hyperledger/fabric/config/tls.
# For consistency with the Fabric-CA guide, his function copies the orderer's TLS certs into the traditional Fabric MSP / folder structure.
function extract_orderer_tls_cert() {
  local orderer=$1

  echo 'set -x

  mkdir -p /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/'${orderer}'.org0.example.com/tls/signcerts/

  cp \
    var/hyperledger/fabric/config/tls/tls.crt \
    /var/hyperledger/fabric/organizations/ordererOrganizations/org0.example.com/orderers/'${orderer}'.org0.example.com/tls/signcerts/cert.pem

  ' | exec kubectl -n $NS exec deploy/${orderer} -i -c main -- /bin/sh
}

function extract_orderer_tls_certs() {
  push_fn "Extracting orderer TLS certs to local MSP folder"

  extract_orderer_tls_cert org0-orderer1
  extract_orderer_tls_cert org0-orderer2
  extract_orderer_tls_cert org0-orderer3

  pop_fn
}

function network_up() {

  # Kube config
  init_namespace
  init_storage_volumes
  load_org_config

  # Network TLS CAs
  init_tls_cert_issuers

  # Network ECert CAs
  launch_ECert_CAs
  enroll_bootstrap_ECert_CA_users

  # Test Network
  create_local_MSP

  launch_orderers
  launch_peers

  extract_orderer_tls_certs
}

function stop_services() {
  push_fn "Stopping Fabric services"

  # These pods are busy executing `sleep MAX_INT` and do not shut down very quickly...
#  kubectl -n $NS delete deployment/org0-admin-cli --grace-period=0 --force
#  kubectl -n $NS delete deployment/org1-admin-cli --grace-period=0 --force
#  kubectl -n $NS delete deployment/org2-admin-cli --grace-period=0 --force

  kubectl -n $NS delete deployment --all
  kubectl -n $NS delete pod --all
  kubectl -n $NS delete service --all
  kubectl -n $NS delete configmap --all
  kubectl -n $NS delete cert --all
  kubectl -n $NS delete issuer --all
  kubectl -n $NS delete secret --all

  pop_fn
}

function scrub_org_volumes() {
  push_fn "Scrubbing Fabric volumes"
  
  # clean job to make this function can be rerun
  kubectl -n $NS delete jobs --all

  # scrub all pv contents
  kubectl -n $NS create -f kube/job-scrub-fabric-volumes.yaml
  kubectl -n $NS wait --for=condition=complete --timeout=60s job/job-scrub-fabric-volumes
  kubectl -n $NS delete jobs --all

  pop_fn
}

function network_down() {
  stop_services
  scrub_org_volumes
}