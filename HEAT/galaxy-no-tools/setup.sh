#!/bin/bash

LOGFILE="/tmp/setup.log"
now=$(date +"-%b-%d-%y-%H%M%S")
echo "Start log ${now}" > $LOGFILE

#________________________________
# Get Distribution

DISTNAME=''
if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo $ID > $LOGFILE
    if [ "$ID" = "ubuntu" ]; then
      echo 'Distribution Ubuntu' > $LOGFILE
      DISTNAME='ubuntu'
    else
      echo 'Distribution: CentOS' > $LOGFILE
      DISTNAME='centos'
    fi
else
    echo "Not running a distribution with /etc/os-release available" > $LOGFILE
fi


#________________________________
# Copy and run ansible roles

if [ "$DISTNAME" = "ubuntu" ]; then
  echo "Distribution: Ubuntu. Using apt" >> $LOGFILE
  #Remove old ansible as workaround for https://github.com/ansible/ansible-modules-core/issues/5144
  dpkg -r ansible
  apt-get autoremove -y
  #install ansible 2.2.1 (version used in INDIGO)
  apt-get -y update &>> $LOGFILE
  apt-get install -y python-pip python-dev libffi-dev libssl-dev &>> $LOGFILE #https://github.com/geerlingguy/JJG-Ansible-Windows/issues/28
  apt-get -y install git vim python-pycurl wget &>> $LOGFILE
else
  echo "Distribution: CentOS. Using yum" >> $LOGFILE
  yum install -y epel-release &>> $LOGFILE
  yum update -y &>> $LOGFILE
  yum groupinstall -y "Development Tools" &>> $LOGFILE
  yum install -y python-pip python-devel libffi-devel openssl-devel &>> $LOGFILE
  yum install -y git vim wget  &>> $LOGFILE
fi

pip install ansible==2.2.1 &>> $LOGFILE

# workaround for template module error on Ubuntu 14.04 https://github.com/ansible/ansible/issues/13818
sed -i 's\^#remote_tmp     = ~/.ansible/tmp.*$\remote_tmp     = $HOME/.ansible/tmp\' /etc/ansible/ansible.cfg
sed -i 's\^#local_tmp      = ~/.ansible/tmp.*$\local_tmp      = $HOME/.ansible/tmp\' /etc/ansible/ansible.cfg

# Enable ansible log file
sed -i 's\^#log_path = /var/log/ansible.log.*$\log_path = /var/log/ansible.log\' /etc/ansible/ansible.cfg

# Install role
BRANCH="master"
git clone https://github.com/indigo-dc/ansible-role-galaxycloud.git /etc/ansible/roles/indigo-dc.galaxycloud &>> $LOGFILE
cd /etc/ansible/roles/indigo-dc.galaxycloud && git checkout $BRANCH &>> $LOGFILE

# Run role
wget https://raw.githubusercontent.com/mtangaro/GalaxyCloud/master/HEAT/galaxy-no-tools/playbook.yml -O /tmp/playbook.yml &>> $LOGFILE
ansible-playbook /tmp/playbook.yml &>> $LOGFILE

#________________________________
# Install cvmfs packages

echo 'Install cvmfs client' &>> $LOGFILE
if [ "$DISTNAME" = "ubuntu" ]; then
  echo "Distribution: Ubuntu." >> $LOGFILE
  wget https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest_all.deb -O /tmp/cvmfs-release-latest_all.deb &>> $LOGFILE
  sudo dpkg -i /tmp/cvmfs-release-latest_all.deb &>> $LOGFILE
  rm -f /tmp/cvmfs-release-latest_all.deb &>> $LOGFILE
  sudo apt-get update &>> $LOGFILE
  apt-get install -y cvmfs cvmfs-config-default &>> $LOGFILE
else
  echo "Distribution: CentOS." >> $LOGFILE
  yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm &>> $LOGFILE
  yum install -y cvmfs cvmfs-config-default &>> $LOGFILE
fi

#________________________________
# Stop postgresql, nginx, proftpd, supervisord, galaxy

# stop galaxy
echo 'Stop Galaxy' &>> $LOGFILE
/usr/local/bin/galaxyctl stop galaxy &>> $LOGFILE

# shutdown supervisord
echo 'Stop supervisord' &>> $LOGFILE
kill -INT `cat /var/run/supervisord.pid` &>> $LOGFILE

# stop postgres
echo 'Stop postgresql' &>> $LOGFILE
if [ "$DISTNAME" = "ubuntu" ]; then
  echo "Distribution: Ubuntu." >> $LOGFILE
  systemctl stop postgresql &>> $LOGFILE
  systemctl disable postgresql &>> $LOGFILE
else
  echo "Distribution: CentOS." >> $LOGFILE
  systemctl stop postgresql-9.6 &>> $LOGFILE
  systemctl disable postgresql-9.6 &>> $LOGFILE
fi

# stop nginx
echo 'Stop nginx' &>> $LOGFILE
systemctl stop nginx &>> $LOGFILE
systemctl disable nginx &>> $LOGFILE

# stop proftpd
echo 'Stop proftpd' &>> $LOGFILE
systemctl stop proftpd &>> $LOGFILE
systemctl disable proftpd &>> $LOGFILE

#________________________________
# Remove ansible
echo 'Removing ansible' &>> $LOGFILE
if [ "$DISTNAME" = "ubuntu" ]; then
  echo "Distribution: Ubuntu. Using apt." >> $LOGFILE
  apt-get -y autoremove ansible &>> $LOGFILE
else
  echo "Distribution: CentOS. Using yum." >> $LOGFILE
  yum remove -y ansible &>> $LOGFILE
fi

#________________________________
# Remove ansible role
#echo 'Removing indigo-dc.galaxycloud' &>> $LOGFILE
rm -rf /etc/ansible/roles/indigo-dc.galaxycloud &>> $LOGFILE
rm -rf /etc/ansible/roles/indigo-dc.galaxycloud-tools &>> $LOGFILE
rm -rf /etc/ansible/roles/indigo-dc.galaxycloud-tooldeps &>> $LOGFILE

#________________________________
# Clean youm cache

if [ "$DISTNAME" = "ubuntu" ]; then
  apt-get clean
else
  yum clean all
fi

#________________________________
# Remove cloud-init artifact
# you can't remove cloud-init artifact using this script
# since it is using cloudinit to run :)
# so this is commented out.
#echo 'Removing cloud-init artifact' &>> $LOGFILE
#rm -rf /var/lib/cloud/* &>> $LOGFILE
#rm /var/log/cloud-init.log &>> $LOGFILE
#rm /var/log/cloud-init-output.log &>> $LOGFILE

#________________________________
# Remove centos user
if [ "$DISTNAME" = "ubuntu" ]; then
  userdel -r -f ubuntu
else
  userdel -r -f centos
fi