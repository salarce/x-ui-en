#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

cur_dir=$(pwd)

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}Error：${plain} must be run with the root user!\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}system version not detected, please contact the script author！${plain}\n" && exit 1
fi

arch=$(arch)

if [[ $arch == "x86_64" || $arch == "x64" || $arch == "amd64" ]]; then
  arch="amd64"
elif [[ $arch == "aarch64" || $arch == "arm64" ]]; then
  arch="arm64"
elif [[ $arch == "s390x" ]]; then
    arch="s390x"
else
    arch="amd64"
    echo -e "${red}failed to detect schema, using default schema: ${arch}${plain}"
fi

echo "schema: ${arch}"

if [ $(getconf WORD_BIT) != '32' ] && [ $(getconf LONG_BIT) != '64' ]; then
    echo "This software does not support 32-bit systems (x86), please use a 64-bit system (x86_64), if the detection is incorrect, please contact the author"
    exit -1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}Please use CentOS 7 or later!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}Please use Ubuntu 16 or later!${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}Please use Debian 8 or later!${plain}\n" && exit 1
    fi
fi

install_base() {
    if [[ x"${release}" == x"centos" ]]; then
        yum install wget curl tar -y
    else
        apt install wget curl tar -y
    fi
}

#This function will be called when user installed x-ui out of sercurity
config_after_install() {
    echo -e "${yellow}For security reasons, it is necessary to forcibly modify the port and account password after the installation/update is completed${plain}"
    read -p "Do you want to continue?[y/n]": config_confirm
    if [[ x"${config_confirm}" == x"y" || x"${config_confirm}" == x"Y" ]]; then
        read -p "Please set your account name:" config_account
        echo -e "${yellow}Your account name will be set to:${config_account}${plain}"
        read -p "Please set your account password:" config_password
        echo -e "${yellow}Your account password will be set to:${config_password}${plain}"
        read -p "Please set panel access port:" config_port
        echo -e "${yellow}Your panel access port will be set to:${config_port}${plain}"
        echo -e "${yellow}confirms setting...${plain}"
        /usr/local/x-ui/x-ui setting -username ${config_account} -password ${config_password}
        echo -e "${yellow}account password setting${plain}"
        /usr/local/x-ui/x-ui setting -port ${config_port}
        echo -e "${yellow}panel port setting${plain}"
    else
        echo -e "${red}has been canceled, all setting items are default settings, please modify in time${plain}"
    fi
}

install_x-ui() {
    systemctl stop x-ui
    cd /usr/local/

    if [ $# == 0 ]; then
        last_version=$(curl -Ls "https://api.github.com/repos/salarce/x-ui-en/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [[ ! -n "$last_version" ]]; then
            echo -e "${red}failed to detect x-ui version, possibly exceeding Github API limits, please try again later, or manually specify x-ui version to install${plain}"
            exit 1
        fi
        echo -e "Detected latest version of X-UI：${last_version}， start installation"
        wget -N --no-check-certificate -O /usr/local/x-ui-en-linux-${arch}.tar.gz https://github.com/salarce/x-ui-en/releases/download/${last_version}/x-ui-en-linux-${arch}.tar.gz
        if [[ $? -ne 0 ]]; then
            echo -e "${red}failed to download x-ui, make sure your server can download the Github file${plain}"
            exit 1
        fi
    else
        last_version=$1
        url="https://github.com/salarce/x-ui-en/releases/download/${last_version}/x-ui-en-linux-${arch}.tar.gz"
        echo -e "Start installing x-ui v$1"
        wget -N --no-check-certificate -O /usr/local/x-ui-en-linux-${arch}.tar.gz ${url}
        if [[ $? -ne 0 ]]; then
            echo -e "${red}failed to download x-ui v$1, make sure exists for this version${plain}"
            exit 1
        fi
    fi

    if [[ -e /usr/local/x-ui/ ]]; then
        rm /usr/local/x-ui/ -rf
    fi

    tar zxvf x-ui-en-linux-${arch}.tar.gz
    rm x-ui-en-linux-${arch}.tar.gz -f
    cd x-ui
    chmod +x x-ui bin/xray-linux-${arch}
    cp -f x-ui.service /etc/systemd/system/
    wget --no-check-certificate -O /usr/bin/x-ui https://raw.githubusercontent.com/salarce/x-ui-en/main/x-ui-en.sh
    chmod +x /usr/local/x-ui/x-ui-en.sh
    chmod +x /usr/bin/x-ui
    config_after_install
    #echo -e "For a clean installation, the default web port is ${green}55441${plain}， and the username and password default to ${green}admin${plain}"
    #echo -e "Please make sure this port is not in use by another program,${yellow} and make sure port 55441 is allowed${plain}"
    #    echo -e "If you want to change 55441 to another port, enter the x-ui command to modify it, and also make sure that the port you modify is also allowed"
    #echo -e ""
    #echo -e "If it's an update panel, access the panel the way you did before"
    #echo -e ""
    systemctl daemon-reload
    systemctl enable x-ui
    systemctl start x-ui
    echo -e "${green}x-ui v${last_version}${plain} installation complete, panel started，"
    echo -e ""
    echo -e "X-UI manual: "
    echo -e "----------------------------------------------"
    echo -e "x-ui              - Show admin menu (more features)"
    echo -e "x-ui start        - Launches x-ui panel"
    echo -e "x-ui stop         - Stop x-ui panel"
    echo -e "x-ui restart      - Restart x-ui panel"
    echo -e "x-ui status       - View x-ui status"
    echo -e "x-ui enable       - Set x-ui to start automatically"
    echo -e "x-ui disable      - cancels x-ui auto-start"
    echo -e "x-ui log          - View x-ui logs"
    echo -e "x-ui update       - Update x-ui panel"
    echo -e "x-ui install      - Installs x-ui panel"
    echo -e "x-ui uninstall    - Uninstall x-ui panel"
    echo -e "----------------------------------------------"
}

echo -e "${green}start installation...${plain}"
install_base
install_x-ui $1
