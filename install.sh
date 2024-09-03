#!/bin/bash
set -e

# 默认变量值
APT_KEY_URL="https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg"
APT_DOWNLOAD_URL="https://us-central1-apt.pkg.dev/projects/sonaric-platform"
RPM_DOWNLOAD_URL="https://us-central1-yum.pkg.dev/projects/sonaric-platform/sonaric-releases-rpm"

SONARIC_ARGS=""
UNINSTALL=""
VERBOSE=""
DEVNULL="/dev/null"

# 显示脚本使用方法
usage() {
 echo "用法: $0 [OPTIONS]"
 echo "选项:"
 echo " -h, --help       显示帮助信息"
 echo " -v, --verbose    启用详细模式"
 echo " -u, --uninstall  卸载 Sonaric"
}

# 处理选项和参数
handle_options() {
  while [ $# -gt 0 ]; do
    case $1 in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --verbose)
        VERBOSE=true
        DEVNULL="/dev/stdout"
        ;;
      -u | --uninstall)
        UNINSTALL=true
        ;;
      *)
        echo "无效的选项: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

# 主脚本执行
handle_options "$@"

print_message() {
  tput bold
  echo ""
  echo "$@"
  echo ""
  tput sgr0
}

command_exists() {
  command -v "$@" > /dev/null 2>&1
}

get_distribution() {
  lsb_dist=""
  # 每个我们正式支持的系统都有 /etc/os-release
  if [ -r /etc/os-release ]; then
    lsb_dist="$(. /etc/os-release && echo "$ID")"
  fi
  # 返回空字符串也应该没关系，因为
  # case 语句只有在提供实际值时才会执行
  echo "$lsb_dist"
}

# 检查是否是派生的 Linux 发行版
check_forked() {

  # 检查是否存在 lsb_release 命令，它通常存在于派生的发行版中
  if command_exists lsb_release; then
    # 检查是否支持 `-u` 选项
    set +e
    lsb_release -a -u > /dev/null 2>&1
    lsb_release_exit_code=$?
    set -e

    # 检查命令是否成功退出，这意味着我们在派生的发行版中
    if [ "$lsb_release_exit_code" = "0" ]; then
      # 打印当前发行版的信息
      cat <<-EOF
      您正在使用 '$lsb_dist' 版本 '$dist_version'。
      EOF

      # 获取上游版本信息
      lsb_dist=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[:space:]')
      dist_version=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[:space:]')

      # 打印上游发行版的信息
      cat <<-EOF
      上游发行版是 '$lsb_dist' 版本 '$dist_version'。
      EOF
    else
      if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "raspbian" ]; then
        if [ "$lsb_dist" = "osmc" ]; then
          # OSMC 运行 Raspbian
          lsb_dist=raspbian
        else
          lsb_dist=debian
        fi
        dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
        case "$dist_version" in
          12)
            dist_version="bookworm"
          ;;
          11)
            dist_version="bullseye"
          ;;
          10)
            dist_version="buster"
          ;;
          9)
            dist_version="stretch"
          ;;
          8)
            dist_version="jessie"
          ;;
        esac
      fi
    fi
  fi
}

user="$(id -un 2> /dev/null || true)"
sh_c='sh -c'
if [ "$user" != 'root' ]; then
  if command_exists sudo; then
    sh_c='sudo -E sh -c'
  elif command_exists su; then
    sh_c='su -c'
  else
    cat >&2 <<-'EOF'
错误: 这个安装程序需要能够以 root 身份运行命令。
我们找不到可用的 "sudo" 或 "su"。
EOF
    exit 1
  fi
fi

exec_cmd() {
  if [ "$VERBOSE" = true ]; then
    echo "$@"
  fi
  $sh_c "$@"
}

confirm_Y() {
  read -p "$1 [Y/n] " reply;
  if [ "$reply" = "${reply#[Nn]}" ]; then
    return 0
  fi
 return 1
}

confirm_N() {
  read -p "$1 [y/N] " reply;
  if [ "$reply" = "${reply#[Yy]}" ]; then
    return 1
  fi
 return 0
}

#confirm_Y "您是否要安装 Sonaric?" && echo true || echo false
#
#confirm_N "您不想安装 Sonaric 吗?" && echo true || echo false

echo '
  /$$$$$$                                          /$$
 /$$__  $$                                        |__/
| $$  \__/  /$$$$$$  /$$$$$$$   /$$$$$$   /$$$$$$  /$$  /$$$$$$$
|  $$$$$$  /$$__  $$| $$__  $$ |____  $$ /$$__  $$| $$ /$$_____/
 \____  $$| $$  \ $$| $$  \ $$  /$$$$$$$| $$  \__/| $$| $$
 /$$  \ $$| $$  | $$| $$  | $$ /$$__  $$| $$      | $$| $$
|  $$$$$$/|  $$$$$$/| $$  | $$|  $$$$$$$| $$      | $$|  $$$$$$$
 \______/  \______/ |__/  |__/ \_______/|__/      |__/ \_______/
'

print_message "检测操作系统..."

# 执行非常基础的平台检测
lsb_dist=$( get_distribution )
lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

case "$lsb_dist" in

  ubuntu)
    if command_exists lsb_release; then
      dist_version="$(lsb_release --codename | cut -f2)"
    fi
    if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
      dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
    fi
  ;;

  debian|raspbian)
    dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
    case "$dist_version" in
      12)
        dist_version="bookworm"
      ;;
      11)
        dist_version="bullseye"
      ;;
      10)
        dist_version="buster"
      ;;
      9)
        dist_version="stretch"
      ;;
      8)
        dist_version="jessie"
      ;;
    esac
  ;;

  centos|rhel|sles)
    if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
      dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
    fi
  ;;

  *)
    if command_exists lsb_release; then
      dist_version="$(lsb_release --release | cut -f2)"
    fi
    if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
      dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
    fi
  ;;

esac

# 检查是否是派生的 Linux 发行版
check_forked

echo "操作系统: $lsb_dist $dist_version"

do_install() {
  # 检查系统ctl单元是否存在以及是否处于活动状态
  if command_exists systemctl && systemctl list-units --full --all sonaricd.service | grep -Fq 'sonaricd.service'; then
    exec_cmd 'systemctl start sonaricd' || echo "启动 Sonaric 失败"
  fi

  print_message "检查 Sonaric..."

  if command_exists sonaricd; then
    echo "Sonaric 已经安装，正在检查更新..."
    do_update
    echo "完成"
    exit 0
  else
    echo "Sonaric 尚未安装。"
  fi

  print_message "安装 Sonaric..."

  # 根据每个支持的发行版处理安装步骤
  case "$lsb_dist" in

    ubuntu|debian|raspbian)
      echo "正在添加 Sonaric 仓库..."
      if [ ! -r "/etc/apt/sources.list.d/sonaric.list" ]; then
        echo "deb [trusted=yes] $APT_DOWNLOAD_URL $(lsb_release -cs) main" > /etc/apt/sources.list.d/sonaric.list
      fi
      echo "正在安装 Sonaric..."
      exec_cmd "apt-get update && apt-get install -y sonaric"
    ;;

    centos|rhel)
      echo "正在添加 Sonaric 仓库..."
      if [ ! -r "/etc/yum.repos.d/sonaric.repo" ]; then
        echo "[sonaric]
name=Sonaric
baseurl=$RPM_DOWNLOAD_URL
enabled=1
gpgcheck=0" > /etc/yum.repos.d/sonaric.repo
      fi
      echo "正在安装 Sonaric..."
      exec_cmd "yum install -y sonaric"
    ;;

    *)
      echo "不支持的操作系统发行版: $lsb_dist"
      exit 1
    ;;
  esac
}

do_update() {
  echo "正在更新 Sonaric..."
  case "$lsb_dist" in
    ubuntu|debian|raspbian)
      exec_cmd "apt-get update && apt-get upgrade -y sonaric"
      ;;
    centos|rhel)
      exec_cmd "yum update -y sonaric"
      ;;
    *)
      echo "不支持的操作系统发行版: $lsb_dist"
      exit 1
      ;;
  esac
}

do_uninstall() {
  print_message "卸载 Sonaric..."

  case "$lsb_dist" in
    ubuntu|debian|raspbian)
      exec_cmd "apt-get remove -y sonaric"
      ;;
    centos|rhel)
      exec_cmd "yum remove -y sonaric"
      ;;
    *)
      echo "不支持的操作系统发行版: $lsb_dist"
      exit 1
      ;;
  esac
}

# 主逻辑
if [ "$UNINSTALL" = true ]; then
  do_uninstall
elif [ "$VERBOSE" = true ]; then
  do_install
else
  confirm_Y "您是否要安装 Sonaric?" && do_install || exit 0
fi
