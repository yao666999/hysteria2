#!/bin/bash

export LANG=en_US.UTF-8

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

red(){ echo -e "\033[31m\033[01m$1\033[0m"; }
green(){ echo -e "\033[32m\033[01m$1\033[0m"; }
yellow(){ echo -e "\033[33m\033[01m$1\033[0m"; }

# 判断系统及定义系统安装依赖方式
REGEX=("debian" "ubuntu" "centos|red hat|kernel|oracle linux|alma|rocky" "'amazon linux'" "fedora")
RELEASE=("Debian" "Ubuntu" "CentOS" "CentOS" "Fedora")
PACKAGE_UPDATE=("apt-get update" "apt-get update" "yum -y update" "yum -y update" "yum -y update")
PACKAGE_INSTALL=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "yum -y install")
PACKAGE_REMOVE=("apt -y remove" "apt -y remove" "yum -y remove" "yum -y remove" "yum -y remove")

[[ $EUID -ne 0 ]] && red "注意: 请在root用户下运行脚本" && exit 1

# 检测系统
CMD=("$(grep -i pretty_name /etc/os-release 2>/dev/null | cut -d \" -f2)" "$(hostnamectl 2>/dev/null | grep -i system | cut -d : -f2)" "$(lsb_release -sd 2>/dev/null)" "$(grep -i description /etc/lsb-release 2>/dev/null | cut -d \" -f2)" "$(grep . /etc/redhat-release 2>/dev/null)" "$(grep . /etc/issue 2>/dev/null | cut -d \\ -f1 | sed '/^[ ]*$/d')")

for i in "${CMD[@]}"; do
    SYS="$i" && [[ -n $SYS ]] && break
done

for ((int = 0; int < ${#REGEX[@]}; int++)); do
    [[ $(echo "$SYS" | tr '[:upper:]' '[:lower:]') =~ ${REGEX[int]} ]] && SYSTEM="${RELEASE[int]}" && [[ -n $SYSTEM ]] && break
done

[[ -z $SYSTEM ]] && red "目前暂不支持你的VPS的操作系统！" && exit 1

# 安装curl
[[ -z $(type -P curl) ]] && { [[ ! $SYSTEM == "CentOS" ]] && ${PACKAGE_UPDATE[int]}; ${PACKAGE_INSTALL[int]} curl; }

# 获取IP
realip(){ ip=$(curl -s4m8 ip.sb -k) || ip=$(curl -s6m8 ip.sb -k); }

# 国家代码对应的中文名称
declare -A COUNTRY_MAP=(
  ["US"]="美国" ["CN"]="中国" ["HK"]="香港" ["TW"]="台湾" ["JP"]="日本" ["KR"]="韩国"
  ["SG"]="新加坡" ["AU"]="澳大利亚" ["DE"]="德国" ["GB"]="英国" ["CA"]="加拿大" ["FR"]="法国"
  ["IN"]="印度" ["IT"]="意大利" ["RU"]="俄罗斯" ["BR"]="巴西" ["NL"]="荷兰" ["SE"]="瑞典"
  ["NO"]="挪威" ["FI"]="芬兰" ["DK"]="丹麦" ["CH"]="瑞士" ["ES"]="西班牙" ["PT"]="葡萄牙"
  ["AT"]="奥地利" ["BE"]="比利时" ["IE"]="爱尔兰" ["PL"]="波兰" ["NZ"]="新西兰" ["MX"]="墨西哥"
  ["ID"]="印度尼西亚" ["TH"]="泰国" ["VN"]="越南" ["MY"]="马来西亚" ["PH"]="菲律宾"
  ["TR"]="土耳其" ["AE"]="阿联酋" ["SA"]="沙特阿拉伯" ["ZA"]="南非" ["IL"]="以色列" 
  ["UA"]="乌克兰" ["GR"]="希腊" ["CZ"]="捷克" ["HU"]="匈牙利" ["RO"]="罗马尼亚" 
  ["BG"]="保加利亚" ["HR"]="克罗地亚" ["RS"]="塞尔维亚" ["EE"]="爱沙尼亚" ["LV"]="拉脱维亚"
  ["LT"]="立陶宛" ["SK"]="斯洛伐克" ["SI"]="斯洛文尼亚" ["IS"]="冰岛" ["LU"]="卢森堡"
  ["UK"]="英国"
)

# 获取IP地域信息
get_ip_region() {
    local ip=$1
    if [[ -z "$ip" ]]; then
        realip
    fi

    # 首先尝试直接用API获取中文地区名称
    local chinese_region=""

    # 尝试使用多个API获取地域信息
    local country_code=""

    # 方法1: 使用 cip.cc API (直接返回中文)
    chinese_region=$(curl -s "https://cip.cc/${ip}" | grep "数据二" | cut -d ":" -f2 | awk '{print $1}')
    if [[ -n "$chinese_region" && "$chinese_region" != *"timeout"* ]]; then
        echo "$chinese_region"
        return
    fi

    # 方法2: 使用 ipinfo.io API
    country_code=$(curl -s -m 5 "https://ipinfo.io/${ip}/json" | grep -o '"country":"[^"]*"' | cut -d ':' -f2 | tr -d '",')

    # 方法3: 使用 ip.sb API
    if [[ -z "$country_code" ]]; then
        country_code=$(curl -s -m 5 "https://api.ip.sb/geoip/${ip}" | grep -o '"country_code":"[^"]*"' | cut -d ':' -f2 | tr -d '",')
    fi

    # 方法4: 使用 ipapi.co API
    if [[ -z "$country_code" ]]; then
        country_code=$(curl -s -m 5 "https://ipapi.co/${ip}/country")
        # 检查是否有错误
        if [[ "$country_code" == *"error"* || "$country_code" == *"reserved"* ]]; then
            country_code=""
        fi
    fi

    # 方法5: 使用 ip-api.com API
    if [[ -z "$country_code" ]]; then
        country_code=$(curl -s -m 5 "http://ip-api.com/json/${ip}?fields=countryCode" | grep -o '"countryCode":"[^"]*"' | cut -d ':' -f2 | tr -d '",')
    fi

    # 将国家代码转换为中文国家名称
    if [[ -n "$country_code" ]]; then
        local country_name="${COUNTRY_MAP[$country_code]}"
        if [[ -n "$country_name" ]]; then
            echo "$country_name"
            return
        fi
    fi

    # 最后尝试获取洲际信息
    local continent=""
    continent=$(curl -s -m 5 "http://ip-api.com/json/${ip}?fields=continent" | grep -o '"continent":"[^"]*"' | cut -d ':' -f2 | tr -d '",')

    # 洲际信息映射
    if [[ -n "$continent" ]]; then
        case $continent in
            "North America") echo "北美洲" ;;
            "South America") echo "南美洲" ;;
            "Europe") echo "欧洲" ;;
            "Asia") echo "亚洲" ;;
            "Africa") echo "非洲" ;;
            "Oceania") echo "大洋洲" ;;
            "Antarctica") echo "南极洲" ;;
            *) echo "国外" ;;
        esac
        return
    fi

    # 如果所有方法都失败，默认使用"国外"
    echo "国外"
}

# 安装Hysteria2
install_hy2() {
    # 检查网络环境
    realip

    # 安装依赖
    [[ ! ${SYSTEM} == "CentOS" ]] && ${PACKAGE_UPDATE} > /dev/null 2>&1
    ${PACKAGE_INSTALL} curl wget sudo qrencode procps iptables-persistent netfilter-persistent > /dev/null 2>&1

    # 安装Hysteria2
    wget -N https://raw.githubusercontent.com/Misaka-blog/hysteria-install/main/hy2/install_server.sh > /dev/null 2>&1
    bash install_server.sh > /dev/null 2>&1
    wget -N https://raw.githubusercontent.com/Misaka-blog/hysteria-install/main/hy2/install_server.sh > /dev/null
    bash install_server.sh > /dev/null
    rm -f install_server.sh

    if [[ ! -f "/usr/local/bin/hysteria" ]]; then
        red "Hysteria 2 安装失败！" && exit 1
    fi

    # 配置Hysteria2
    mkdir -p /etc/hysteria

    # 生成自签证书
    openssl ecparam -genkey -name prime256v1 -out /etc/hysteria/private.key
    openssl req -new -x509 -days 36500 -key /etc/hysteria/private.key -out /etc/hysteria/cert.crt -subj "/CN=www.bing.com"
    chmod 644 /etc/hysteria/cert.crt /etc/hysteria/private.key

    # 生成随机密码
    auth_pwd=$(date +%s%N | md5sum | cut -c 1-8)

    # 设置配置文件
    cat << EOF > /etc/hysteria/config.yaml
listen: :7005

tls:
  cert: /etc/hysteria/cert.crt
  key: /etc/hysteria/private.key

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432

auth:
  type: password
  password: $auth_pwd

masquerade:
  type: proxy
  proxy:
    url: https://en.snu.ac.kr
    rewriteHost: true
EOF

    # 准备客户端配置
    if [[ -n $(echo $ip | grep ":") ]]; then
        last_ip="[$ip]"
    else
        last_ip=$ip
    fi

    mkdir -p /root/hy

    # 获取IP地域信息作为节点名称
    node_name=$(get_ip_region "$ip")

    # 生成YAML客户端配置
    cat << EOF > /root/hy/hy-client.yaml
server: $last_ip:7005

auth: $auth_pwd

tls:
  sni: www.bing.com
  insecure: true

quic:
  initStreamReceiveWindow: 16777216
  maxStreamReceiveWindow: 16777216
  initConnReceiveWindow: 33554432
  maxConnReceiveWindow: 33554432

fastOpen: true

socks5:
  listen: 127.0.0.1:5678

transport:
  udp:
    hopInterval: 30s 
EOF

    # 生成JSON客户端配置
    cat << EOF > /root/hy/hy-client.json
{
  "server": "$last_ip:7005",
  "auth": "$auth_pwd",
  "tls": {
    "sni": "www.bing.com",
    "insecure": true
  },
  "quic": {
    "initStreamReceiveWindow": 16777216,
    "maxStreamReceiveWindow": 16777216,
    "initConnReceiveWindow": 33554432,
    "maxConnReceiveWindow": 33554432
  },
  "socks5": {
    "listen": "127.0.0.1:5678"
  },
  "transport": {
    "udp": {
      "hopInterval": "30s"
    }
  }
}
EOF

    # 生成分享链接，使用中文国家名称作为节点名称
    url="hysteria2://$auth_pwd@$last_ip:7005/?insecure=1&sni=www.bing.com#$node_name"
    echo $url > /root/hy/url.txt

    # 启动服务并设置开机自启
    systemctl daemon-reload
    systemctl enable hysteria-server > /dev/null 2>&1
    systemctl start hysteria-server

    # 设置开机自启
    if [[ ! -f /etc/systemd/system/hysteria-autostart.service ]]; then
        cat > /etc/systemd/system/hysteria-autostart.service << EOF
[Unit]
Description=Hysteria 2 Auto Start Service
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "systemctl start hysteria-server"
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable hysteria-autostart >/dev/null 2>&1
    fi

    # 显示结果
    if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) ]]; then
        green "======================================================================================"
        green "Hysteria 2 安装成功！"
        yellow "端口: 7005"
        yellow "密码: $auth_pwd"
        yellow "伪装网站: en.snu.ac.kr"
        yellow "TLS SNI: www.bing.com"
        yellow "节点名称: $node_name"
        echo ""
        yellow "客户端配置已保存到: /root/hy/"
        yellow "分享链接:"
        red "$url"
        green "======================================================================================"
    else
        red "Hysteria 2 服务启动失败，请检查日志" && exit 1
    fi
}

# 卸载Hysteria2
uninstall_hy2() {
    systemctl stop hysteria-server >/dev/null 2>&1
    systemctl disable hysteria-server >/dev/null 2>&1
    systemctl disable hysteria-autostart >/dev/null 2>&1

    rm -f /etc/systemd/system/hysteria-autostart.service
    rm -f /lib/systemd/system/hysteria-server.service /lib/systemd/system/hysteria-server@.service
    rm -rf /usr/local/bin/hysteria /etc/hysteria /root/hy

    systemctl daemon-reload

    green "Hysteria 2 已完全卸载！"
}

# 启动服务
start_hy2() {
    systemctl start hysteria-server
    if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) ]]; then
        green "Hysteria 2 已启动"
    else 
        red "Hysteria 2 启动失败"
    fi
}

# 停止服务
stop_hy2() {
    systemctl stop hysteria-server
    green "Hysteria 2 已停止"
}

# 重启服务
restart_hy2() {
    systemctl restart hysteria-server
    if [[ -n $(systemctl status hysteria-server 2>/dev/null | grep -w active) ]]; then
        green "Hysteria 2 已重启"
    else 
        red "Hysteria 2 重启失败"
    fi
}

# 查看配置
show_config() {
    if [ ! -f "/root/hy/url.txt" ]; then
        red "配置文件不存在"
        return
    fi

    green "======================================================================================"
    if [ -f "/root/hy/hy-client.yaml" ]; then
        yellow "YAML配置文件 (/root/hy/hy-client.yaml):"
        cat /root/hy/hy-client.yaml
        echo ""
    fi

    if [ -f "/root/hy/url.txt" ]; then
        yellow "分享链接:"
        red "$(cat /root/hy/url.txt)"
    fi
    green "======================================================================================"
}

# 服务控制菜单
service_menu() {
    clear
    echo "#############################################################"
    echo -e "#                  ${GREEN}Hysteria 2 服务控制${PLAIN}                     #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 启动 Hysteria 2"
    echo -e " ${GREEN}2.${PLAIN} 停止 Hysteria 2"
    echo -e " ${GREEN}3.${PLAIN} 重启 Hysteria 2"
    echo -e " ${GREEN}0.${PLAIN} 返回主菜单"
    echo ""
    read -rp "请输入选项 [0-3]: " switchInput
    case $switchInput in
        1) start_hy2 ;;
        2) stop_hy2 ;;
        3) restart_hy2 ;;
        0) menu ;;
        *) red "无效选项" ;;
    esac
    menu
}

# 主菜单
menu() {
    clear
    echo "#############################################################"
    echo -e "#                 ${GREEN}Hysteria 2 一键配置脚本${PLAIN}                  #"
    echo "#############################################################"
    echo ""
    echo -e " ${GREEN}1.${PLAIN} 安装 Hysteria 2 (端口7005, 自签证书)"
    echo -e " ${RED}2.${PLAIN} 卸载 Hysteria 2"
    echo "------------------------------------------------------------"
    echo -e " ${GREEN}3.${PLAIN} 关闭、开启、重启 Hysteria 2"
    echo -e " ${GREEN}4.${PLAIN} 显示 Hysteria 2 配置文件"
    echo "------------------------------------------------------------"
    echo -e " ${GREEN}0.${PLAIN} 退出脚本"
    echo ""
    read -rp "请输入选项 [0-4]: " menuInput
    case $menuInput in
        1) install_hy2 ;;
        2) uninstall_hy2 ;;
        3) service_menu ;;
        4) show_config ;;
        0) exit 0 ;;
        *) red "请输入正确的选项 [0-4]" && exit 1 ;;
    esac
}

menu
menu
