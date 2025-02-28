#!/bin/bash

# Vérification des privilèges root
#if [[ $SUID -ne 0 ]]; then
#  echo "Ce script doit être exécuté en tant que root. Loggué vous !!!! [su -]"
#  exit 1
#fi


################ PHASE 1 préparer le serveur ################
echo ""
echo "### PHASE 1 : PREPARATION DU SERVEUR POUR PXE BOOT ###"

# Variables
USERNAME="ansible"
PASSWORD="root"

# Mise à jour du système RHEL 8
sudo dnf update -y

#Installer package necessaires
sudo dnf install -y ansible httpd dhcp-server tftp-server syslinux wget firewalld

# Créer utilisateur ansible
sudo useradd -m $USERNAME

# Mot de passe pour l'utilisateur ansible
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Ajouter ansible au sudoers (wheel)
sudo usermod -aG wheel ansible

################ FIN PHASE 1 ################






################ PHASE 2 Config des services réseaux ################ 
echo ""
echo "### PHASE 2 : CONFIGURATION DU RÉSEAU POUR PXE BOOT ###"



################ DHCP ################
echo ""
echo "################ DHCP ################"

#Variables réseaux (Adapter à votre réseau)
SERVER_IP="192.168.1.101"
NETWORK="192.168.1.0"
NETMASK="255.255.255.0"
DHCP_POOL_START="192.168.1.100"
DHCP_POOL_END="192.168.1.200"
GATEWAY="192.168.1.254"
DNS="8.8.8.8, 8.8.4.4"

# 1. Configuration du serveur DHCP
echo ""
echo "Configuration du serveur DHCP..."
cat > /etc/dhcp/dhcpd.conf <<EOL
subnet $NETWORK netmask $NETMASK {
    range $DHCP_POOL_START $DHCP_POOL_END;
    option routers $GATEWAY;
    option domain-name-servers $DNS;
    next-server $SERVER_IP;
    filename "pxelinux.0";
}
EOL

echo ""
echo "################ FIN DHCP ################"
################ FIN DHCP ################






################ TFTP ################
echo ""
echo "################ TFTP ################"

# Variables TFTP
TFTP_ROOT="/var/lib/tftpboot"

# 2. Configuration du serveur TFTP
echo ""
echo "Configuration du serveur TFTP..."
sudo mkdir -p $TFTP_ROOT
sudo cp /usr/share/syslinux/pxelinux.0 $TFTP_ROOT/
sudo cp /usr/share/syslinux/ldlinux.c32 $TFTP_ROOT/

echo ""
echo "################ FIN TFTP ################"
################ FIN TFTP ################






################ HTTP ################
echo ""
echo "################ HTTP ################"
# Variables HTTP
HTTP_ROOT="/var/www/html"
UBUNTU_ISO_PATH="/home/user/Documents/ubuntu24.iso"  # Remplacez par le chemin de votre ISO

# 3. Configuration du serveur HTTP
echo ""
echo "Configuration du serveur HTTP..."
sudo mkdir -p $HTTP_ROOT/ubuntu24
sudo mount -o loop $UBUNTU_ISO_PATH /mnt
sudo cp -r /mnt/* $HTTP_ROOT/ubuntu24/
sudo umount /mnt

echo ""
echo "################ FIN HTTP ################"
################ FIN HTTP ################






################ PXE ################
echo ""
echo "################ PXE ################"


# Variables PXE
PXE_CONFIG_DIR="$TFTP_ROOT/pxelinux.cfg"


# Configuration des fichiers PXE
echo ""
echo "Création du fichier de configuration PXE..."
sudo mkdir -p $PXE_CONFIG_DIR
cat > $PXE_CONFIG_DIR/default <<EOL
DEFAULT ubuntu
LABEL ubuntu
    KERNEL ubuntu24/vmlinuz
    APPEND initrd=ubuntu24/initrd.gz auto=true priority=critical ks=http://$SERVER_IP/ks.cfg
EOL


# Copie des fichiers vmlinuz, initrd.gz de l'OS
echo ""
echo "Copie des fichiers vmlinuz, initrd.gz de l'OS..."
sudo mkdir $TFTP_ROOT/ubuntu24/
sudo cp $HTTP_ROOT/ubuntu24/casper/vmlinuz $TFTP_ROOT/ubuntu24/
sudo cp $HTTP_ROOT/ubuntu24/casper/initrd $TFTP_ROOT/ubuntu24/


echo ""
echo "################ PXE ################"
################ FIN PXE ################



echo ""
echo "################ FIN PHASE 2 ################"
################ FIN PHASE 2 ################






################ PHASE 3 Activation et démarrage des services ################
echo ""
echo "### PHASE 3 : Activation et démarrage des services ###"



################ DHCP ################
echo ""
echo "################ DHCP ################"

echo ""
echo "Activation et démarrage du service DHCP..."
sudo systemctl enable dhcpd
sudo systemctl start dhcpd

echo ""
echo "################ FIN DHCP ################"
################ FIN DHCP ################





################ TFTP ################
echo ""
echo "################ TFTP ################"

# Activer et démarrer le services TFTP
echo ""
echo "Activation et démarrage du service TFTP..."
sudo systemctl enable tftp
sudo systemctl start tftp

echo ""
echo "################ FIN TFTP ################"
################ FIN TFTP ################




################ HTTP ################
echo ""
echo "################ HTTP ################"

# Activer et démarrer le services HTTP
echo ""
echo "Activation et démarrage du service HTTP..."

systemctl enable httpd
systemctl start httpd

echo ""
echo "################ FIN HTTP ################"
################ FIN HTTP ################


echo ""
echo "################ FIN PHASE 3 ################"
################ FIN PHASE 3 ################






################ PHASE 4 Activation du firewall et Ouverture des ports ################
echo ""
echo "### PHASE 4 : Activation du firewall et Ouverture des ports ###"


################ Ouverture des ports ################
echo ""
echo "################ Ouverture des ports ################"

echo ""
echo "Configuration du pare-feu..."
firewall-cmd --add-service=dhcp --permanent
firewall-cmd --add-service=tftp --permanent
firewall-cmd --add-service=http --permanent
firewall-cmd --reload

echo ""
echo "################ FIN Ouverture des ports ################"
################ FIN Ouverture des ports ################




################ Activation du firewall ################
echo ""
echo "################ Activation du firewall ################"

sudo systemctl enable firewalld
sudo systemctl start firewalld

echo ""
echo "################ FIN Activation du firewall ################"
################ FIN Activation du firewall ################




################ Vérifications des services ################
echo ""
echo "################ Vérifications des services... ################"

echo ""
echo "Vérifications des services..."
systemctl status dhcpd | grep "active (running)" || { echo "Erreur : le service DHCP n'est pas démarré."; exit 1; }
systemctl status tftp | grep "active (running)" || { echo "Erreur : le service TFTP n'est pas démarré."; exit 1; }
systemctl status httpd | grep "active (running)" || { echo "Erreur : le service HTTP n'est pas démarré."; exit 1; }

echo ""
echo "################ FIN Vérifications des services ################"
################ FIN Vérifications des services ################


echo " "
echo "### CONFIGURATION DU RÉSEAU POUR PXE BOOT TERMINÉE AVEC SUCCÈS ###"
echo ""






################ PHASE 5 Creation du fichier Kickstart ################
echo ""
echo "### PHASE 5 : Creation du fichier Kickstart ###"



################ Creation du fichier Kickstart ################
echo ""
echo "################ Creation du fichier Kickstart ################"

cat > $HTTP_ROOT/ks.cfg << EOL
install
url --url http://$SERVER_IP/ubuntu24

lang en_US.UTF-8
keyboard fr
timezone Europe/New_York

rootpw --iscrypted $6$rounds=8000$RANDOM_SALT$HASHED_PASSWORD

bootloader --location=mbr --boot-drive=sda
clearpart --all --initlabel

part /boot --fstype=ext4 --size=500
part swap --size=2048
part / --fstype=ext4 --size=10240

%packages
@core #install graphique
# @^minimal-environment # install minimal
%end

%post
# script après installation
echo "Configuration post-installation réussie !" > /tmp/post-install.log
%end
EOL

echo ""
echo "################ FIN Creation du fichier Kickstart ################"
################ FIN Creation du fichier Kickstart ################



echo ""
echo "Vérifiez que le fichier PXE est accessible via http://$SERVER_IP/ et que les machines peuvent booter via PXE."
echo ""
