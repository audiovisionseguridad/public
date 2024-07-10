#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "Necesita correr con privilegios..."
   exec sudo "$0" "$@"
   exit $?
fi
sudo apt install git wget
cd /opt/adv/ || { echo "Failed to change directory to /opt/adv/. Exiting."; exit 1; }
docker-compose stop adv-qr-node-rs485


echo "blacklist ch341" | sudo tee -a "/etc/modprobe.d/blacklist-ch341.conf" > /dev/null
echo "ajustando driver"
sudo update-initramfs -u

wget -qO- https://raw.githubusercontent.com/audiovisionseguridad/public/master/99-hidraw-permissions.rules | sudo tee /etc/udev/rules.d/99-hidraw-permissions.rules
sudo udevadm control --reload-rules && sudo udevadm trigger

git clone https://github.com/WCHSoftGroup/ch341ser_linux || echo "repo OK"
cd ch341ser_linux/driver
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

systemctl enable load-ch341.service
systemctl start load-ch341.service || echo "OK"
echo "OK"
