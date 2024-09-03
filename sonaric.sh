#!/bin/bash

# 主菜单函数
function main_menu() {
    while true; do
        clear
        echo "脚本由大赌社区哈哈哈哈编写，推特 @ferdie_jhovie，免费开源，请勿相信收费"
        echo "================================================================"
        echo "退出脚本，请按键盘 ctrl + C 退出即可"
        echo "请选择要执行的操作:"
        echo "1) 启动节点"
        echo "2) Discord 上注册节点"
        echo "3) 查看积分"
        echo "4) 删除节点"
        echo "5) 备份节点"
        echo "6) 退出"

        read -p "请输入选项 [1-6]: " choice

        case $choice in
            1)
                echo "开始更新和升级系统包，这可能需要几分钟时间..."
                sudo apt update -y && sudo apt upgrade -y

                echo "系统包更新和升级完成。接下来将下载并执行安装脚本，这也可能需要一些时间..."
                sh -c "$(curl -fsSL https://raw.githubusercontent.com/sdohuajia/Sonaric/main/install.sh)"

                echo "按任意键查看节点状态，这可能需要 3-4 分钟时间..."
                read -n 1 -s -r

                sonaric node-info
                echo "节点状态检查完成。请确保你已确认节点运行在最新版本。"
                ;;
            2)
                echo "请输入你的注册代码:"
                read -p "注册代码: " register_code

                echo "正在注册节点，请稍候..."
                sonaric node-register "$register_code"

                echo "注册完成。请按任意键返回主菜单..."
                read -n 1 -s -r
                ;;
            3)
                echo "正在查看积分，请稍候..."
                sonaric points

                echo "积分查看完成。请按任意键返回主菜单..."
                read -n 1 -s -r
                ;;
            4)
                echo "正在删除节点和相关文件，请稍候..."
                
                # 卸载和删除节点相关的文件和进程
                sudo apt-get remove --purge -y sonaricd sonaric
                sudo pkill -f sonaric
                sudo rm -rf /usr/local/bin/sonaric
                sudo rm -rf /opt/sonaric
                sudo rm -rf ~/.sonaric

                echo "节点删除完成。请按任意键返回主菜单..."
                read -n 1 -s -r
                ;;
            5)
                echo "正在备份节点数据，请稍候..."

                # 备份节点相关数据
                sudo cp -r /var/lib/sonaricd ~/.sonaric_backup

                echo "备份完成。请妥善保管备份文件，包括节点身份、数据库、配置文件和日志。"
                echo "备份文件路径: ~/.sonaric_backup"
                echo "请按任意键返回主菜单..."
                read -n 1 -s -r
                ;;
            6)
                echo "退出脚本。"
                exit 0
                ;;
            *)
                echo "无效选项，请输入 1 到 6 之间的数字。"
                ;;
        esac

        # 等待用户按任意键返回主菜单
        echo "按任意键返回主菜单..."
        read -n 1 -s -r
    done
}

# 运行主菜单函数
main_menu
