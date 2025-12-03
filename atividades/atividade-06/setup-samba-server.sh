#!/bin/bash

apt-get update
apt-get install -y samba

# Cria diretório compartilhado
mkdir -p /shared
chmod 777 /shared

# Cria usuário do Samba
(echo "password"; echo "password") | smbpasswd -a -s user

# Configura o Samba
cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   server string = Samba Server
   security = user
   map to guest = bad user

[shared]
   path = /shared
   browsable = yes
   writable = yes
   guest ok = no
   valid users = user
EOF

# Inicia o serviço
service smbd restart
