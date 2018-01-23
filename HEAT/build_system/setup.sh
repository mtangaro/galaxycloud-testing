#!/bin/bash

#________________________________
# Control variables

ansible_venv=/tmp/myansible
ANSIBLE_VERSION=2.2.1

OS_BRANCH="master"
BRANCH="master"
TOOLS_BRANCH="devel"
TOOLDEPS_BRANCH="devel"
REFDATA_BRANCH="devel"

role_dir=/tmp/roles

#________________________________
# Start logging
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
      echo 'Distribution Ubuntu' &>> $LOGFILE
      DISTNAME='ubuntu'
    else
      echo 'Distribution: CentOS' &>> $LOGFILE
      DISTNAME='centos'
    fi
else
    echo "Not running a distribution with /etc/os-release available" &>> $LOGFILE
fi

#________________________________
# Install prerequisites
function prerequisites(){

  if [[ $DISTNAME = "ubuntu" ]]; then
    apt-get -y install git vim python-pycurl wget
  else
    yum install -y git vim wget
  fi

}

#________________________________
# Ansible management
function install_ansible(){

  echo 'Remove ansible virtualenv if exists'
  rm -rf $ansible_venv

  if [[ $DISTNAME = "ubuntu" ]]; then
    #Remove old ansible as workaround for https://github.com/ansible/ansible-modules-core/issues/5144
    dpkg -r ansible
    apt-get autoremove -y
    apt-get -y update
    apt-get install -y python-pip python-dev libffi-dev libssl-dev python-virtualenv
  else
    yum install -y epel-release
    yum update -y
    yum groupinstall -y "Development Tools"
    yum install -y python-pip python-devel libffi-devel openssl-devel python-virtualenv
  fi

  # Install ansible in a specific virtual environment
  virtualenv --system-site-packages $ansible_venv
  . $ansible_venv/bin/activate
  pip install pip --upgrade

  #install ansible 2.2.1 (version used in INDIGO)
  pip install ansible==$ANSIBLE_VERSION

  # workaround for https://github.com/ansible/ansible/issues/20332
  cd $ansible_venv
  wget https://raw.githubusercontent.com/ansible/ansible/devel/examples/ansible.cfg  -O $ansible_venv/ansible.cfg

  sed -i 's\^#remote_tmp     = ~/.ansible/tmp.*$\remote_tmp     = $HOME/.ansible/tmp\' $ansible_venv/ansible.cfg
  sed -i 's\^#local_tmp      = ~/.ansible/tmp.*$\local_tmp      = $HOME/.ansible/tmp\' $ansible_venv/ansible.cfg
  #sed -i 's:#remote_tmp:remote_tmp:' /tmp/myansible/ansible.cfg

  # Enable ansible log file
  sed -i 's\^#log_path = /var/log/ansible.log.*$\log_path = /var/log/ansible.log\' $ansible_venv/ansible.cfg

}

# Remove ansible
function remove_ansible(){

  echo "Removing ansible venv"
  deactivate
  rm -rf $ansible_venv

  echo 'Removing roles'
  rm -rf $role_dir

  echo 'Removing ansible'
  if [[ $DISTNAME = "ubuntu" ]]; then
    apt-get -y autoremove ansible
  else
    yum remove -y ansible
  fi

}

#________________________________
# Install ansible roles
function install_ansible_roles(){

  mkdir -p $role_dir

  # Dependencies
  ansible-galaxy install --roles-path $role_dir indigo-dc.galaxycloud-indigorepo
  ansible-galaxy install --roles-path $role_dir indigo-dc.oneclient
  ansible-galaxy install --roles-path $role_dir indigo-dc.cvmfs-client

  # 1. indigo-dc.galaxycloud-os
  git clone https://github.com/indigo-dc/ansible-role-galaxycloud-os.git $role_dir/indigo-dc.galaxycloud-os
  cd $role_dir/indigo-dc.galaxycloud-os && git checkout $OS_BRANCH

  # 2. indigo-dc.galaxycloud
  git clone https://github.com/indigo-dc/ansible-role-galaxycloud.git $role_dir/indigo-dc.galaxycloud
  cd $role_dir/indigo-dc.galaxycloud && git checkout $BRANCH

  #### # 3. indigo-dc.galaxy-tools
  #### git clone https://github.com/indigo-dc/ansible-galaxy-tools.git $role_dir/indigo-dc.galaxy-tools
  #### cd $role_dir/indigo-dc.galaxy-tools && git checkout $TOOLS_BRANCH

  # 3. indigo-dc.galaxycloud-tools and indigo-dc.galaxycloud-tooldeps
  git clone https://github.com/indigo-dc/ansible-role-galaxycloud-tools.git $role_dir/indigo-dc.galaxycloud-tools
  cd $role_dir/indigo-dc.galaxycloud-tools && git checkout $TOOLS_BRANCH

  git clone https://github.com/indigo-dc/ansible-role-galaxycloud-tooldeps.git $role_dir/indigo-dc.galaxycloud-tooldeps
  cd $role_dir/indigo-dc.galaxycloud-tooldeps && git checkout $TOOLDEPS_BRANCH

  # 4. indigo-dc.galaxycloud-refdata
  git clone https://github.com/indigo-dc/ansible-role-galaxycloud-refdata.git $role_dir/indigo-dc.galaxycloud-refdata
  cd $role_dir/indigo-dc.galaxycloud-refdata && git checkout $REFDATA_BRANCH

}

#________________________________
# Postgresql management
function start_postgresql(){

  echo 'Start postgresql'
  if [[ $DISTNAME = "ubuntu" ]]; then
    systemctl start postgresql
  else
    systemctl start postgresql-9.6
  fi

}

#________________________________
# Stop all services with rigth order
function stop_services(){

  echo 'Stop Galaxy'
  /usr/bin/galaxyctl stop galaxy --force

  # shutdown supervisord
  echo 'Stop supervisord'
  kill -INT `cat /var/run/supervisord.pid`

  # stop postgres
  echo 'Stop postgresql'
  if [[ $DISTNAME = "ubuntu" ]]; then
    systemctl stop postgresql
    systemctl disable postgresql
  else
    systemctl stop postgresql-9.6
    systemctl disable postgresql-9.6
  fi

  # stop nginx
  echo 'Stop nginx'
  systemctl stop nginx
  systemctl disable nginx

  # stop proftpd
  echo 'Stop proftpd'
  systemctl stop proftpd
  systemctl disable proftpd

}

#________________________________
# Run playbook
function run_playbook(){

  wget https://raw.githubusercontent.com/mtangaro/GalaxyCloud/master/HEAT/build_system/$galaxy_flavor.yml -O /tmp/playbook.yml
  ansible-playbook /tmp/playbook.yml

}

#________________________________
function build_base_image () {

  # Install depdendencies
  if [[ $DISTNAME = "ubuntu" ]]; then
    apt-get -y update
    apt-get -y install python-pip python-dev libffi-dev libssl-dev
    apt-get -y install git vim python-pycurl wget
  else
    yum install -y epel-release &>> $LOGFILE
    yum update -y
    yum groupinstall -y "Development Tools"
    yum install -y python-pip python-devel libffi-devel openssl-devel
    yum install -y git vim python-curl wget
  fi

  # Install cvmfs packages
  echo 'Install cvmfs client'
  if [[ $DISTNAME" = "ubuntu" ]]; then
    wget https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest_all.deb -O /tmp/cvmfs-release-latest_all.deb
    sudo dpkg -i /tmp/cvmfs-release-latest_all.deb
    rm -f /tmp/cvmfs-release-latest_all.deb
    sudo apt-get update
    apt-get install -y cvmfs cvmfs-config-default
  else
    yum install -y https://ecsft.cern.ch/dist/cvmfs/cvmfs-release/cvmfs-release-latest.noarch.rpm
    yum install -y cvmfs cvmfs-config-default
  fi

}

#________________________________
function run_tools_script() {

  # Get install script
  wget https://raw.githubusercontent.com/mtangaro/GalaxyCloud/master/HEAT/build_system/install_tools.sh -O /usr/local/bin/install-tools
  chmod +x /usr/local/bin/install-tools

  # Get recipe
  echo 'Get tools recipe'
  wget $tools_recipe_url  -O /tmp/tools.yml

  # create fake user
  echo "create fake user"
  /usr/bin/python /usr/local/bin/create_galaxy_user.py --user placeholder@placeholder.com --password placeholder --username placeholder -c /home/galaxy/galaxy/config/galaxy.ini --key placeholder_api_key

  # run install script
  echo "run install-tools script"
  /usr/local/bin/install-tools placeholder_api_key /tmp/tools.yml

  echo "remove conda tarballs"
  /home/galaxy/tool_deps/_conda/bin/conda clean --tarballs --yes > /dev/null

  # delete fake user
  echo "delete fake user"
  cd $HOME/galaxy
  /usr/bin/python /usr/local/bin/delete_galaxy_user.py --user placeholder@placeholder.com 

}

#________________________________
# Clean package manager cache
function clean_package_manager_cache(){

  echo "Clean package manager cache"
  if [[ $DISTNAME = "ubuntu" ]]; then
    apt-get clean
  else
    yum clean all
  fi

}

#________________________________
# Copy remove cloud-init artifact script
function copy_cloud_init_script(){

  wget https://raw.githubusercontent.com/mtangaro/GalaxyCloud/master/HEAT/build_system/clean_cloudinit_artifact.sh -O /tmp/clean_cloudinit_artifact.sh

}

#________________________________
# Remove cloud-init user
function remove_user(){

  echo "Remove default user"
  if [[ $DISTNAME = "ubuntu" ]]; then
    userdel -r -f ubuntu
  else
    userdel -r -f centos
  fi

}

#________________________________
# MAIN FUNCTION

{

# install dependencies
prerequisites

if [[ $galaxy_flavor = "build_base_image" ]]; then
  build_base_image

elif [[ $galaxy_flavor = "run_tools_script" ]]; then
  start_postgresql
  run_tools_script
  stop_services

else
  # Prepare the system: install ansible, ansible roles
  install_ansible
  install_ansible_roles
  # Run ansible play
  run_playbook
  # Stop all services and remove ansible
  stop_services
  remove_ansible

fi

# Clean the environment
clean_package_manager_cache
copy_cloud_init_script
remove_user

} >> $LOGFILE

echo "End setup script" >> $LOGFILE
