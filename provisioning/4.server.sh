#!/bin/bash

OPENVPN_DIR='/etc/openvpn'
SERVER_CONF="${OPENVPN_DIR}/server.conf"
RSA_DIR='/root/openvpn-ca'
KEY_DIR="${RSA_DIR}/keys"

prep_rsa() {
    cd "${RSA_DIR}" || exit
    # shellcheck disable=SC1091
    . ./vars
}

if [ ! -d "${RSA_DIR}" ]
then
    /usr/bin/make-cadir "${RSA_DIR}"
fi

/bin/sed -ie 's/KEY_NAME="EasyRSA"/KEY_NAME="server"/' "${RSA_DIR}/vars"
/bin/sed -ie 's/export KEY_SIZE=2048/export KEY_SIZE=4096/' "${RSA_DIR}/vars"

if [ ! -e "${KEY_DIR}/ca.crt" ] \
       || [ ! -e "${KEY_DIR}/server.key" ] \
       || [ ! -e "${KEY_DIR}/server.crt" ]
then
    prep_rsa
   ./clean-all
fi

new_ca=false
if [ ! -e "${KEY_DIR}/ca.crt" ]
then
    prep_rsa
    echo 'Building CA...'
    ./build-ca --batch >/dev/null 2>&1
    new_ca=true
fi

if $new_ca \
        || [ ! -e "${KEY_DIR}/server.key" ] \
        || [ ! -e "${KEY_DIR}/server.crt" ]
then
    prep_rsa
    echo 'Building server keys...'
    ./build-key-server --batch server >/dev/null 2>&1
fi

if [ ! -e "${KEY_DIR}/dhparams.pem" ]
then
    prep_rsa
    echo 'Building dhparam (can take a while)...'
    $OPENSSL dhparam -dsaparam -out "${KEY_DIR}/dhparams.pem" "${KEY_SIZE}"
fi

if [ ! -e "${KEY_DIR}/ta.key" ]
then
    /usr/sbin/openvpn --genkey --secret "${KEY_DIR}/ta.key"
fi

cd "${KEY_DIR}" || exit
cp -f ca.crt ca.key server.crt server.key ta.key dhparams.pem "${OPENVPN_DIR}"

cp /vagrant/provisioning/server.conf "${SERVER_CONF}"

systemctl start openvpn@server
