#!/bin/bash

export DOCKER_HOST=tcp://127.0.0.1:2376;
export DOCKER_TLS_VERIFY=1;
export COMPOSE_TLS_VERSION=TLSv1_2;


if [[ $EUID -ne 0 ]]; then
   echo "Necesita correr con privilegios..."
   exec sudo "$0" "$@"
   exit $?
fi
sudo apt -y install git wget
cd /opt/adv/ || { echo "Failed to change directory to /opt/adv/. Exiting."; exit 1; }
docker-compose stop adv-qr-node-rs485


echo "blacklist ch341" | sudo tee "/etc/modprobe.d/blacklist-ch341.conf" > /dev/null

echo "ajustando driver"
sudo update-initramfs -u

wget -qO- https://raw.githubusercontent.com/audiovisionseguridad/public/master/99-hidraw-permissions.rules | sudo tee /etc/udev/rules.d/99-hidraw-permissions.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

git clone https://github.com/WCHSoftGroup/ch341ser_linux || echo "repo OK"
cd /opt/adv/ch341ser_linux/driver || { echo "Failed to change directory to /opt/adv/ch341ser_linux/driver. Exiting."; exit 1; }

sudo make clean
sudo make
sudo make load 

cat << EOF > /etc/systemd/system/load-ch341.service
[Unit]
Description=Load ch341 module at boot
After=network.target

[Service]
Type=oneshot
WorkingDirectory=/opt/adv/ch341ser_linux/driver/
ExecStart=/usr/bin/make load
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

cd /opt/adv/ || { echo "Failed to change directory to /opt/adv/. Exiting."; exit 1; }

sudo systemctl enable load-ch341.service
sudo systemctl start load-ch341.service || echo "OK"
docker-compose start adv-qr-node-rs485

echo "OK"
