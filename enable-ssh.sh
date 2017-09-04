#!/bin/bash

sudo sed -i '/Port/s/^# *//' /etc/ssh/sshd_config
sudo service ssh restart

