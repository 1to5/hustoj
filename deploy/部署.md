# 🎓 HUSTOJ 完整手册
## 从模板开发到 VPS 部署 · 0 基础大学生版

> **读前须知**  
> - 每一步都有完整命令，照抄即可  
> - 命令前有 `#` 的是注释，解释这行在做什么，不需要输入  
> - `你的XXX` 字样需要替换成你自己的内容  
> - 遇到报错：先看报错最后一行，再来问

---

## 目录

| 章节 | 内容 | 时间 |
|------|------|------|
| 第 0 章 | 准备工作 | 20 分钟 |
| 第 1 章 | 搭建代码仓库 | 20 分钟 |
| 第 2 章 | VPS 首次安装 | 30 分钟 |
| 第 3 章 | 开发自定义模板 | 持续进行 |
| 第 4 章 | 配置自动部署 | 20 分钟 |
| 第 5 章 | 日常运维手册 | 随时查阅 |

---

## 第 0 章：准备工作

### 你需要的东西

| 东西 | 去哪里弄 | 费用 |
|------|----------|------|
| GitHub 账号 | github.com 注册 | 免费 |
| VPS 服务器 | 阿里云/腾讯云学生机 | ≈10元/月 |
| 电脑终端 | Mac 自带 Terminal；Windows 用 PowerShell | 免费 |
| VS Code | code.visualstudio.com | 免费 |

**VPS 购买要点：**
- 系统选 **Ubuntu 22.04 LTS**（本手册所有命令基于此）
- 配置至少 **2核2G**
- 记下你的 VPS **IP 地址**和**root 密码**

### 安装 Git

```bash
# macOS
brew install git

# Windows：去 https://git-scm.com/download/win 下载安装包

# 安装完后配置身��（只需做一次）
git config --global user.name "你的名字"
git config --global user.email "你的邮箱"

# 验证
git --version
# 看到版本号就成功了
```

### 配置 SSH 密钥（和 GitHub 免密通信）

```bash
# 生成密钥，一路回车
ssh-keygen -t ed25519 -C "你的邮箱"

# 查看公钥，复制全部内容
cat ~/.ssh/id_ed25519.pub
```

复制后去 GitHub：头像 → Settings → SSH and GPG keys → New SSH key → 粘贴 → 保存

```bash
# 测试是否成功
ssh -T git@github.com
# 看到 "Hi 你的用户名!" 就成功了
```

---

## 第 1 章：搭建代码仓库

### 1.1 Fork 官方仓库

1. 打开 [github.com/zhblue/hustoj](https://github.com/zhblue/hustoj)
2. 点右上角 **Fork** → **Create fork**
3. ��在你有了 `github.com/你的用户名/hustoj`

### 1.2 克隆到本地

```bash
# 在电脑上找个地方存代码，比如桌面
cd ~/Desktop

# 克隆你的 Fork（换成你的用户名）
git clone git@github.com:你的用户名/hustoj.git
cd hustoj

# 添加官方仓库地址，方便以后同步官方更新
git remote add upstream https://github.com/zhblue/hustoj.git

# 确认设置正确
git remote -v
# 应该看到 origin 和 upstream 两行
```

### 1.3 新建模板独立仓库

在 GitHub 上新建一个仓库，名字叫 `hustoj-mytheme`。

```bash
# 回到桌面
cd ~/Desktop
mkdir hustoj-mytheme
cd hustoj-mytheme
git init

# 把官方 syzoj 模板复制过来作为起点
cp -r ~/Desktop/hustoj/trunk/web/template/syzoj/* .

# 第一次提交
git add .
git commit -m "初始化：基于官方 syzoj 模板"
git remote add origin git@github.com:你的用户名/hustoj-mytheme.git
git branch -M main
git push -u origin main
```

### 1.4 将模板挂入主仓库（Submodule）

```bash
cd ~/Desktop/hustoj

# 将模板仓库作为子模块
git submodule add \
    git@github.com:你的用户名/hustoj-mytheme.git \
    trunk/web/template/mytheme

git add .gitmodules trunk/web/template/mytheme
git commit -m "添加自定义模板 mytheme"
git push origin master
```

### 1.5 添加部署脚本文件夹

```bash
cd ~/Desktop/hustoj
mkdir -p deploy
```

把本手册第 2 章的所有脚本文件创建在这里，然后统一提交：

```bash
git add deploy/
git commit -m "添加部署脚本"
git push origin master
```

**最终仓库结构：**

```
hustoj/                          ← 主仓库（GitHub）
├── trunk/
│   └── web/
│       └── template/
│           ├── syzoj/           ← 官方模板（不动）
│           └── mytheme/         ← 你的模板（独立仓库）
├── deploy/
│   ├── setup.sh                 ← 新机器一键安装
│   ├── update.sh                ← 代码热更新
│   ├── bak.sh                   ← 备份
│   ├── restore.sh               ← 恢复
│   └── oj.sh                    ← 日常运维入口
└── .gitmodules
```

---

## 第 2 章：VPS 首次安装

### 2.1 登录 VPS

```bash
# 在你的电脑终端输入（换成你的 IP）
ssh root@你的VPS的IP地址

# 第一次会提示是否信任，输入 yes
# 然后输入你购买 VPS 时设置的密码
```

### 2.2 把部署脚本下载到 VPS

```bash
# 在 VPS 上执行
# 拉取你的代码（含模板子模块）
git clone --recurse-submodules \
    https://github.com/你的用户名/hustoj.git \
    /home/judge/src

# 让 setup.sh 可以运行
chmod +x /home/judge/src/deploy/*.sh
```

### 2.3 编辑安装脚本配置

```bash
# 用 nano 编辑器打开脚本（方向键移动，Ctrl+O 保存，Ctrl+X 退出）
nano /home/judge/src/deploy/setup.sh

# 找到配置区，修改这几行：
YOUR_REPO="https://github.com/你的用户名/hustoj.git"
OJ_NAME="我的OJ"           # 你的 OJ 名字
OJ_TEMPLATE="mytheme"      # 你的模板文件夹名
```

### 2.4 执行安装

```bash
# 运行一键安装（大约需要 10~20 分钟）
sudo bash /home/judge/src/deploy/setup.sh

# 安装结束后会显示：
# ✅ 安装完成！
# 数据库密码: xxxxxxxx  ← 立刻记下来！
```

安装完成后，在浏��器访问 `http://你的VPS_IP`，应该能看到 OJ 首页。

**注册管理员账号：**
1. 点击页面上的【注册】
2. 用户名必须填 `admin`
3. 注册完成即可登录后台 `http://你的VPS_IP/admin`

---

## 第 3 章：开发自定义模板

### 3.1 理解模板文件的作用

```
hustoj-mytheme/
├── header.php    ← 每个页面顶部（导航栏）
├── footer.php    ← 每个页面底部（页脚 + JS）
├── css.php       ← 引入 CSS 文件
├── js.php        ← 引入 JS 文件
├── index.php     ← 首页
├── *.php         ← 各功能页面（题目、状态、排行等）
├── css/
│   ├── style.css     ← 官方样式（尽量不动）
│   └── custom.css    ← 你的自定义样���（在这里改）
└── js/
    └── custom.js     ← 你的自定义 JS
```

**最重要的规则：** 不要直接修改 `style.css`，新建 `css/custom.css` 写你的样式，这样官方更新时不会冲突。

### 3.2 引入你的自定义样式

编辑 `css.php`，在最后加一行：

```php name=css.php
<?php /* 原有内容保持不变 */ ?>
<!-- 你的自定义样式 -->
<link rel="stylesheet" href="<?php echo $path_fix."template/$OJ_TEMPLATE"?>/css/custom.css">
```

新建 `css/custom.css`：

```css name=css/custom.css
/* ======================
   我的 OJ 自定义样式
   ====================== */

/* 改导航栏颜色 */
.ui.menu {
    background-color: #1a1a2e !important;
}
.ui.menu .item, .ui.menu .item a {
    color: #e0e0e0 !important;
}

/* 改页面背景 */
.pushable > .pusher {
    background-color: #f5f7fa;
}

/* 改按钮圆角 */
.ui.button {
    border-radius: 6px !important;
}

/* 改链接颜色 */
a { color: #1a73e8; }
a:hover { color: #1557b0; }
```

### 3.3 本地预览效果

```bash
# 进入 web 目录
cd ~/Desktop/hustoj/trunk/web

# 启动 PHP 内置服务器（仅预览静态效果）
php -S localhost:8080

# 浏览器访问 http://localhost:8080
```

### 3.4 提交模板修改

```bash
# 进入模板目录
cd ~/Desktop/hustoj-mytheme

# 查看修改了哪些文件
git status

# 提交
git add .
git commit -m "修改导航栏颜色"
git push origin main

# 回到主仓库，更新子模块引用
cd ~/Desktop/hustoj
git add trunk/web/template/mytheme
git commit -m "同步模板更新"
git push origin master
```

---

## 第 4 章：配置自动部署

> 目标：在电脑��� `git push` 后，VPS 自动拉取新代码，不需要手动登录服务器。

### 4.1 生成部署专用密钥

```bash
# 在你的电脑上执行
ssh-keygen -t ed25519 -C "deploy-key" \
    -f ~/.ssh/hustoj_deploy -N ""

# 查看公钥（要加到 VPS）
cat ~/.ssh/hustoj_deploy.pub

# 查看私钥（要加到 GitHub Secrets）
cat ~/.ssh/hustoj_deploy
```

```bash
# 在 VPS 上执行：信任这个部署密钥
echo "粘贴上面 hustoj_deploy.pub 的内容" >> ~/.ssh/authorized_keys
```

### 4.2 在 GitHub 添加 Secrets

1. 打开你的 `hustoj` 仓库页面
2. Settings → Secrets and variables → Actions → New repository secret

| 名称 | 值 |
|------|----|
| `VPS_HOST` | 你的 VPS IP |
| `VPS_USER` | `root` |
| `VPS_SSH_KEY` | `hustoj_deploy` 私钥的完整内容 |

### 4.3 创建 GitHub Actions 工作流

在你的 `hustoj` 仓库中创建：

```yaml name=.github/workflows/deploy.yml
name: 自动部署到 VPS

on:
  push:
    branches: [master]
  workflow_dispatch:   # 支持手动触发

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: SSH 连接 VPS 并更新
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            sudo bash /home/judge/src/deploy/update.sh \
              >> /home/judge/log/deploy.log 2>&1
```

```bash
# 提交工作流文件
cd ~/Desktop/hustoj
git add .github/workflows/deploy.yml
git commit -m "添加自动部署工作流"
git push origin master

# 推送后去 GitHub 仓库 → Actions 标签查看部署状态
```

---

## 第 5 章：日常运维手册

所有运维操作统一通过 `oj.sh` 完成，简单好记。

```bash
# 语法
sudo bash /home/judge/src/deploy/oj.sh <命令>
```

### 5.1 常用命令速查

```bash
# 查看所有服务状态
sudo bash /home/judge/src/deploy/oj.sh status

# 手动更新代码
sudo bash /home/judge/src/deploy/oj.sh update

# 立即备份
sudo bash /home/judge/src/deploy/oj.sh bak

# 进入数据库命令行
sudo bash /home/judge/src/deploy/oj.sh db

# 查看系统总览
sudo bash /home/judge/src/deploy/oj.sh check

# 查看实时判题日志
sudo bash /home/judge/src/deploy/oj.sh log judge

# 重启所有服务
sudo bash /home/judge/src/deploy/oj.sh restart
```

### 5.2 日常开发循环

```
修改模板 css/custom.css
      ↓
git commit + push（模板仓库）
      ↓
更新主仓库子模块引用 + push
      ↓
GitHub Actions 自动触发
      ↓
VPS 自动拉取更新（约 1 分钟）
      ↓
刷新浏览器查看效果
```

### 5.3 同步官方更新

官方修复了 bug 或新增功能时：

```bash
cd ~/Desktop/hustoj

# 拉取官方最新代码
git fetch upstream

# 合并到你的主分支
git merge upstream/master

# 如果有冲突（用 VS Code 解决）
code .

# 推送，自动部署
git push origin master
```

### 5.4 从备份恢复数据

```bash
# 查看有哪些备份
ls -lh /var/backups/hustoj_*.tar.bz2

# 恢复指定备份
sudo bash /home/judge/src/deploy/oj.sh restore \
    /var/backups/hustoj_20250226.tar.bz2
```

### 5.5 常见问题排查

| 现象 | 排查命令 | 最可能的原因 |
|------|----------|------------|
| 网页打不开 | `sudo bash deploy/oj.sh status` | Nginx 未启动 |
| 页面空白/报错 | `sudo bash deploy/oj.sh log nginx` | PHP 报错 |
| 提交后不判题 | `ps aux \| grep judged` | judged 未运行 |
| 判题一直 Waiting | `sudo bash deploy/oj.sh restart` | 重启服务 |
| 模板没更新 | `cd /home/judge/src && git submodule update --remote` | 子模块未同步 |

---

## 附录：完整脚本文件

### `deploy/setup.sh` — 新机器一键安装

```bash name=deploy/setup.sh
#!/bin/bash
# ============================================================
# HUSTOJ VPS 一键安装脚本
# 使用方法：sudo bash deploy/setup.sh
# 系统要求：Ubuntu 22.04 LTS
# ============================================================
set -e

# ════════════════ 修改这里的配置 ════════════════
YOUR_REPO="https://github.com/你的用户名/hustoj.git"
OJ_NAME="我的OJ"
OJ_TEMPLATE="mytheme"
DB_NAME="jol"
DB_USER="hustoj"
DB_PASS=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w20 | head -n1)
# ════════════════════════════════════════════════

# 颜色输出
info()    { echo -e "\033[32m[INFO]\033[0m $*"; }
warning() { echo -e "\033[33m[WARN]\033[0m $*"; }
error()   { echo -e "\033[31m[ERROR]\033[0m $*"; exit 1; }
step()    { echo -e "\n\033[36m>>> $* \033[0m"; }

[ "$(whoami)" != "root" ] && error "请用 sudo 执行"

echo "============================================"
echo "  HUSTOJ 一键安装"
echo "  OJ名称: $OJ_NAME"
echo "  模板:   $OJ_TEMPLATE"
echo "============================================"

step "第1步：安装系统依赖"
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    nginx mariadb-server \
    php8.3-fpm php8.3-mysql php8.3-gd \
    php8.3-mbstring php8.3-xml php8.3-zip php8.3-curl \
    g++ make flex libmariadb-dev-compat \
    git curl wget bzip2

step "第2步：创建 judge 系统用户"
useradd -m -u 1536 judge 2>/dev/null || info "judge 用户已存在"
# 禁止 judge 用户登录 Shell（安全加固）
chsh judge -s /sbin/nologin 2>/dev/null || true

step "第3步：下载代码（含模板子模块）"
if [ -d /home/judge/src/.git ]; then
    info "代码目录已存在，跳过克隆"
else
    git clone --recurse-submodules "$YOUR_REPO" /home/judge/src
fi

step "第4步：创建目录结构"
mkdir -p /home/judge/{etc,data,log,backup}
mkdir -p /var/backups
CPU=$(grep "cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')
CPU=${CPU:-1}
for i in $(seq 0 $((CPU-1))); do
    mkdir -p /home/judge/run$i
    chown judge /home/judge/run$i
done
info "创建了 $CPU 个判题目录（对应 CPU 核心数）"

step "第5步：配置数据库"
systemctl start mariadb
systemctl enable mariadb

mysql <<SQL
CREATE DATABASE IF NOT EXISTS $DB_NAME DEFAULT CHARSET utf8mb4;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL

# 仅首次导入数据库结构
if ! mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "SHOW TABLES;" 2>/dev/null | grep -q "users"; then
    mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        < /home/judge/src/install/db.sql
    mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "INSERT IGNORE INTO privilege(user_id,rightstr,rtime)
            VALUES('admin','administrator',NOW());"
    info "数据库初始化完成"
fi

step "第6步：写入配置文件"
# judge.conf（官方标准配置）
cp /home/judge/src/install/judge.conf /home/judge/etc/judge.conf
cp /home/judge/src/install/java0.policy /home/judge/etc/ 2>/dev/null || true

CONF=/home/judge/etc/judge.conf
sed -i "s|OJ_HOST_NAME=.*|OJ_HOST_NAME=127.0.0.1|"  "$CONF"
sed -i "s|OJ_USER_NAME=.*|OJ_USER_NAME=$DB_USER|"    "$CONF"
sed -i "s|OJ_PASSWORD=.*|OJ_PASSWORD=$DB_PASS|"       "$CONF"
sed -i "s|OJ_DB_NAME=.*|OJ_DB_NAME=$DB_NAME|"         "$CONF"

# 关键：按 CPU 核心数自动设置判题并发（来自官方 autocpu.sh）
COMPENSATION=$(grep 'mips' /proc/cpuinfo 2>/dev/null | head -1 \
    | awk -F: '{printf("%.2f",$2/5000)}')
COMPENSATION=${COMPENSATION:-1.0}
sed -i "s|OJ_RUNNING=.*|OJ_RUNNING=$CPU|"                          "$CONF"
sed -i "s|OJ_CPU_COMPENSATION=.*|OJ_CPU_COMPENSATION=$COMPENSATION|" "$CONF"
sed -i "s|OJ_COMPILE_CHROOT=.*|OJ_COMPILE_CHROOT=0|"               "$CONF"
sed -i "s|OJ_SHM_RUN=.*|OJ_SHM_RUN=0|"                            "$CONF"

chmod 700 "$CONF"
info "判题并发数: $CPU，CPU补偿系数: $COMPENSATION"

# db_info.inc.php
CFG=/home/judge/src/web/include/db_info.inc.php
sed -i "s|DB_USER\s*=\s*\".*\"|DB_USER=\"$DB_USER\"|"     "$CFG"
sed -i "s|DB_PASS\s*=\s*\".*\"|DB_PASS=\"$DB_PASS\"|"     "$CFG"
sed -i "s|OJ_NAME\s*=\s*\".*\"|OJ_NAME=\"$OJ_NAME\"|"     "$CFG"
sed -i "s|OJ_TEMPLATE\s*=\s*\".*\"|OJ_TEMPLATE=\"$OJ_TEMPLATE\"|" "$CFG"
chown www-data "$CFG"
chmod 640 "$CFG"

step "第7步：编译判题程序"
cd /home/judge/src/core
bash make.sh
cp judged/judged judge_client/judge_client /usr/bin/
chmod +x /usr/bin/judged /usr/bin/judge_client
info "judged 编译完成"

step "第8步：配置 Nginx"
cat > /etc/nginx/sites-enabled/default <<'NGINX'
server {
    listen 80 default_server;
    root /home/judge/src/web;
    index index.php;
    client_max_body_size 280m;

    # 日志
    access_log /var/log/nginx/hustoj.access.log;
    error_log  /var/log/nginx/hustoj.error.log;

    location / { try_files $uri $uri/ =404; }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_buffer_size 256k;
        fastcgi_buffers 512 64k;
    }

    # 保护配置文件
    location ~* /include/db_info\.inc\.php { deny all; }
}
NGINX

# PHP 上传限制
PHP_INI="/etc/php/8.3/fpm/php.ini"
sed -i "s/post_max_size = 8M/post_max_size = 500M/"           "$PHP_INI"
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 500M/" "$PHP_INI"

# Nginx body 大小
grep -q "client_max_body_size" /etc/nginx/nginx.conf || \
    sed -i "s|include /etc/nginx/mime.types;|client_max_body_size 280m;\n\tinclude /etc/nginx/mime.types;|" \
    /etc/nginx/nginx.conf

step "第9步：设置文件权限"
chown -R www-data:www-data /home/judge/src/web/
chown -R www-data:judge    /home/judge/data/
chmod -R 755 /home/judge/src/web/
chmod 750 -R /home/judge/data/
chmod o+x /home/ /home/judge/ /home/judge/src/
chmod +x /home/judge/src/deploy/*.sh

step "第10步：配置 judged 开机自启"
cat > /etc/systemd/system/judged.service <<'SYSTEMD'
[Unit]
Description=HUSTOJ Judge Daemon
After=network.target mariadb.service

[Service]
Type=simple
ExecStart=/usr/bin/judged
Restart=always
RestartSec=5
StandardOutput=append:/home/judge/log/judge.log
StandardError=append:/home/judge/log/judge.log

[Install]
WantedBy=multi-user.target
SYSTEMD
systemctl daemon-reload
systemctl enable judged

step "第11步：配置每日自动备份"
DEPLOY_DIR=/home/judge/src/deploy
cat > /etc/cron.d/hustoj-bak <<EOF
# 每天凌晨 3 点自动备份（来自官方 bak.sh 推荐做法）
0 3 * * * root bash $DEPLOY_DIR/bak.sh >> /home/judge/log/bak.log 2>&1
EOF

step "第12步：启动所有服务"
systemctl enable nginx php8.3-fpm
systemctl restart mariadb nginx php8.3-fpm
systemctl start judged

# 保存密码到安全位置
cat > /home/judge/etc/credentials.txt <<EOF
DB_USER=$DB_USER
DB_PASS=$DB_PASS
EOF
chmod 600 /home/judge/etc/credentials.txt

PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "未知")

echo ""
echo "============================================"
echo "  ✅ 安装完成！"
echo "--------------------------------------------"
echo "  数据库用户: $DB_USER"
echo "  数据库密码: $DB_PASS"
echo "  ⚠️  密码已保存到 /home/judge/etc/credentials.txt"
echo "--------------------------------------------"
echo "  下一步："
echo "  1. 访问 http://$PUBLIC_IP/"
echo "  2. 点击【注册】，用户名填 admin"
echo "  3. 注册后即可进入��台 /admin"
echo "============================================"
```

---

### `deploy/update.sh` — 代码热更新

```bash name=deploy/update.sh
#!/bin/bash
# ============================================================
# HUSTOJ 代码热更新脚本
# 整合官方 fixing.sh 的关键逻辑：
#   1. 更新前自动备份
#   2. git pull 拉取最新代码（含模板子模块）
#   3. 执行 update.sql 更新数据库结构
#   4. 按 CPU 核心数自动调整判题并发
#   5. 按需重新编译判题程序
#   6. 修复文件权限
# ============================================================
set -e

[ "$(whoami)" != "root" ] && echo "请用 sudo 执行" && exit 1

SRC=/home/judge/src
WWW=$(grep www /etc/passwd | awk -F: '{print $1}')
DEPLOY=$(dirname "$(realpath "$0")")

log() { echo "[$(date '+%F %T')] $*"; }

log "开始更新..."

# ── 读取数据库配置（官方标准读法）──
conf_get() { grep "$1" /home/judge/etc/judge.conf | awk -F= '{print $2}'; }
DB_SERVER=$(conf_get OJ_HOST_NAME)
DB_USER=$(conf_get OJ_USER_NAME)
DB_PASS=$(conf_get OJ_PASSWORD)
DB_NAME=$(conf_get OJ_DB_NAME)
DB_PORT=$(conf_get OJ_PORT_NUMBER); DB_PORT=${DB_PORT:-3306}

# ── 第1步：更新前备份（来自官方 fixing.sh 思路）──
log "更新前执行备份..."
bash "$DEPLOY/bak.sh" >> /home/judge/log/bak.log 2>&1 || \
    log "警告：备份失败，继续更新（建议检查备份日志）"

# ── 第2步：拉取代码（替代官方 wget hustoj.tar.gz）──
log "拉取最新代码..."
cd "$SRC"
git stash 2>/dev/null || true
git pull origin master
# 同步模板子模块（这是我们额外做的）
git submodule update --remote --merge
git stash pop 2>/dev/null || true

# ── 第3步：检测 core 是否变化，有则重���译（来自官方 fixing.sh）──
CORE_CHANGED=$(git diff HEAD@{1} HEAD --name-only 2>/dev/null \
    | grep "^core/" | wc -l)
if [ "$CORE_CHANGED" -gt "0" ]; then
    log "检测到判题核心更新，重新编译..."
    systemctl stop judged 2>/dev/null || pkill -9 judged 2>/dev/null || true
    sleep 1
    cd "$SRC/core" && bash make.sh
    cp judged/judged judge_client/judge_client /usr/bin/
    systemctl start judged
    log "judged 已重新编译并重启"
fi

# ── 第4步：执行数据库结构更新（来自官方 fixing.sh：source update.sql）──
UPDATE_SQL="$SRC/install/update.sql"
if [ -f "$UPDATE_SQL" ]; then
    log "执行数据库结构更新..."
    mysql -h "$DB_SERVER" -P "$DB_PORT" \
        -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        < "$UPDATE_SQL" 2>/dev/null || log "update.sql 有警告（通常正常）"
fi

# ── 第5步：按 CPU 核心数调整判题并发（来自官方 autocpu.sh）──
CPU=$(grep "cpu cores" /proc/cpuinfo | head -1 | awk '{print $4}')
CPU=${CPU:-1}
COMPENSATION=$(grep 'mips' /proc/cpuinfo 2>/dev/null | head -1 \
    | awk -F: '{printf("%.2f",$2/5000)}')
COMPENSATION=${COMPENSATION:-1.0}
CONF=/home/judge/etc/judge.conf
sed -i "s|OJ_RUNNING=.*|OJ_RUNNING=$CPU|"                           "$CONF"
sed -i "s|OJ_CPU_COMPENSATION=.*|OJ_CPU_COMPENSATION=$COMPENSATION|" "$CONF"

# ── 第6步：修复文件权限（来自官方 fixing.sh）──
log "修复文件权限..."
chown -R "$WWW":"$WWW" "$SRC/web/"
chown -R "$WWW":judge  /home/judge/data/
chmod 750 -R /home/judge/data/
chmod 700 /home/judge/etc/judge.conf
chmod o+x /home/ /home/judge/ "$SRC/"

# ── 第7步：平滑重载 Web 服务（零停机）──
log "重载 Web 服务..."
nginx -t && nginx -s reload
systemctl reload php8.3-fpm 2>/dev/null || true

log "✅ 更新完成！"
```

---

### `deploy/bak.sh` — 备份脚本

```bash name=deploy/bak.sh
#!/bin/bash
# ============================================================
# HUSTOJ 增强备份脚本
# 完整吸收官方 bak.sh 的所有逻辑，并增加：
#   - --single-transaction 保证数据库一致性
#   - 月度备份长期保留（每月1日的备份保留30天）
# 使用：sudo bash deploy/bak.sh
# ============================================================
set -e

DATE=$(date +%Y%m%d)
BAKDIR=/var/backups
KEEP_DAYS=3      # 普通备份保留天数（与官方一致）
KEEP_LONG=30     # 月度备份保留天数

# 读取数据库配置（官方标准读法）
config="/home/judge/etc/judge.conf"
SERVER=$(grep 'OJ_HOST_NAME'  $config | awk -F= '{print $2}')
USER=$(grep 'OJ_USER_NAME'    $config | awk -F= '{print $2}')
PASSWORD=$(grep 'OJ_PASSWORD' $config | awk -F= '{print $2}')
DATABASE=$(grep 'OJ_DB_NAME'  $config | awk -F= '{print $2}')
PORT=$(grep 'OJ_PORT_NUMBER'  $config | awk -F= '{print $2}')
PORT=${PORT:-3306}

echo "[$(date '+%F %T')] 开始备份..."

# ── 第1步：清理垃圾数据（来自官方 bak.sh）──
journalctl --vacuum-time=7d 2>/dev/null || true

mysql -h "$SERVER" -P "$PORT" -u"$USER" -p"$PASSWORD" "$DATABASE" 2>/dev/null <<SQL || true
-- 清理无效提交（problem_id=0 的僵尸数据）
DELETE FROM source_code WHERE solution_id IN (
    SELECT solution_id FROM solution WHERE problem_id=0 AND result>4);
DELETE FROM source_code_user WHERE solution_id IN (
    SELECT solution_id FROM solution WHERE problem_id=0 AND result>4);
DELETE FROM runtimeinfo WHERE solution_id IN (
    SELECT solution_id FROM solution WHERE problem_id=0 AND result>4);
DELETE FROM compileinfo WHERE solution_id IN (
    SELECT solution_id FROM solution WHERE problem_id=0 AND result>4);
-- 3天前还在等待的提交标为 CE
UPDATE solution SET result=5
    WHERE result<4 AND in_date < CURDATE() - INTERVAL 3 DAY;
DELETE FROM solution WHERE problem_id=0 AND result>4;
-- 清理6个月前的登录日志
DELETE FROM loginlog WHERE time < CURDATE() - INTERVAL 6 MONTH;
DELETE FROM compileinfo WHERE solution_id < (
    SELECT solution_id FROM solution WHERE result=11
    AND in_date < CURDATE() - INTERVAL 6 MONTH
    ORDER BY solution_id DESC LIMIT 1);
DELETE FROM runtimeinfo WHERE solution_id < (
    SELECT solution_id FROM solution WHERE result=11
    AND in_date < CURDATE() - INTERVAL 6 MONTH
    ORDER BY solution_id DESC LIMIT 1);
SQL

# ── 第2步：REPAIR + OPTIMIZE 表（来自官方 bak.sh）──
TABLES="compileinfo,contest,contest_problem,loginlog,news,privilege,problem,solution,source_code,users,topic,reply,online,sim,mail"
mysql -h "$SERVER" -P "$PORT" -u"$USER" -p"$PASSWORD" "$DATABASE" \
    -e "REPAIR TABLE $TABLES;" 2>/dev/null || true
mysql -h "$SERVER" -P "$PORT" -u"$USER" -p"$PASSWORD" "$DATABASE" \
    -e "OPTIMIZE TABLE $TABLES;" 2>/dev/null || true

# ── 第3步：导出数据库（增加 --single-transaction 保证一致性）──
mkdir -p "$BAKDIR"
mysqldump \
    --default-character-set=utf8mb4 \
    --single-transaction \
    -h "$SERVER" -P "$PORT" \
    -u"$USER" -p"$PASSWORD" \
    "$DATABASE" | bzip2 > "$BAKDIR/db_${DATE}.sql.bz2"

# ── 第4步：打包完整备份（对齐官方打包范围）──
echo "正在打包（时间较长，请耐心等待）..."
tar cjf "$BAKDIR/hustoj_${DATE}.tar.bz2" \
    /home/judge/data \
    /home/judge/src/web \
    /home/judge/etc \
    "$BAKDIR/db_${DATE}.sql.bz2" \
    2>/dev/null || true

# ── 第5步：清理旧备份（月度备份长期保留）──
# 删除超过3天的普通备份，但保留每月1日的
find "$BAKDIR" -name "hustoj_*.tar.bz2" -mtime +"$KEEP_DAYS" \
    ! -name "hustoj_$(date +%Y%m)01.tar.bz2" -delete 2>/dev/null || true
# 删除超过30天的月度备份
find "$BAKDIR" -name "hustoj_*01.tar.bz2" \
    -mtime +"$KEEP_LONG" -delete 2>/dev/null || true
find "$BAKDIR" -name "db_*.sql.bz2" \
    -mtime +"$KEEP_DAYS" -delete 2>/dev/null || true

SIZE=$(du -sh "$BAKDIR/hustoj_${DATE}.tar.bz2" 2>/dev/null | cut -f1)
echo "[$(date '+%F %T')] ✅ 备份完成！文件：$BAKDIR/hustoj_${DATE}.tar.bz2 ($SIZE)"
echo "提示：用 FileZilla（sftp）连接服务器下载备份文件"
```

---

### `deploy/restore.sh` — 数据恢复

```bash name=deploy/restore.sh
#!/bin/bash
# ============================================================
# HUSTOJ 数据恢复脚本
# 基于官方 restore.sh，修复字符集兼容问题
# 使用：sudo bash deploy/restore.sh /var/backups/hustoj_20250226.tar.bz2
# ============================================================
set -e

[ "$(whoami)" != "root" ] && echo "请用 sudo 执行" && exit 1

if [ $# -ne 1 ]; then
    echo "用法: sudo bash $0 <备份文件路径>"
    echo ""
    echo "可用的备份："
    ls -lh /var/backups/hustoj_*.tar.bz2 2>/dev/null || echo "  (无备份文件)"
    exit 1
fi

BAKFILE="$1"
DATE=$(date +%Y%m%d%H%M%S)
BAKDATE=$(basename "$BAKFILE" | sed 's/hustoj_\([0-9]*\).*/\1/')

config="/home/judge/etc/judge.conf"
SERVER=$(grep 'OJ_HOST_NAME'  $config | awk -F= '{print $2}')
USER=$(grep 'OJ_USER_NAME'    $config | awk -F= '{print $2}')
PASSWORD=$(grep 'OJ_PASSWORD' $config | awk -F= '{print $2}')
DATABASE=$(grep 'OJ_DB_NAME'  $config | awk -F= '{print $2}')
PORT=$(grep 'OJ_PORT_NUMBER'  $config | awk -F= '{print $2}'); PORT=${PORT:-3306}
WWW=$(grep www /etc/passwd | awk -F: '{print $1}')
DEPLOY=$(dirname "$(realpath "$0")")

echo "⚠️  恢复会覆盖当前数据！"
echo "   备份文件：$BAKFILE"
read -p "确认继续？(输入 yes): " CONFIRM
[ "$CONFIRM" != "yes" ] && echo "已取消" && exit 0

echo "恢复前备份当前数据..."
bash "$DEPLOY/bak.sh" || true

TMPDIR=$(mktemp -d)
cd "$TMPDIR"
tar xjf "$BAKFILE"

# 恢复题目数据
mv /home/judge/data "/home/judge/data.bak.$DATE" 2>/dev/null || true
cp -a home/judge/data /home/judge/
chown -R "$WWW":judge /home/judge/data/
chmod 750 -R /home/judge/data/

# 恢复上传文件
mv /home/judge/src/web/upload "/home/judge/src/web/upload.bak.$DATE" 2>/dev/null || true
[ -d home/judge/src/web/upload ] && cp -a home/judge/src/web/upload /home/judge/src/web/
chown -R "$WWW":"$WWW" /home/judge/src/web/upload/ 2>/dev/null || true

# 恢复数据库（官方 restore.sh 的字符集修复）
SQLFILE=$(find var/backups -name "db_${BAKDATE}*.sql" 2>/dev/null | head -1)
[ -z "$SQLFILE" ] && bzip2 -d "var/backups/db_${BAKDATE}.sql.bz2" 2>/dev/null && \
    SQLFILE="var/backups/db_${BAKDATE}.sql"

sed -i 's/COLLATE=utf8mb4_0900_ai_ci//g'           "$SQLFILE"
sed -i 's/COLLATE utf8mb4_0900_ai_ci//g'            "$SQLFILE"
sed -i 's/utf8mb4_0900_ai_ci/utf8mb4_general_ci/g'  "$SQLFILE"

mysql -h "$SERVER" -P "$PORT" -u"$USER" -p"$PASSWORD" "$DATABASE" < "$SQLFILE"

UPDATE_SQL=/home/judge/src/install/update.sql
[ -f "$UPDATE_SQL" ] && mysql -h "$SERVER" -P "$PORT" \
    -u"$USER" -p"$PASSWORD" "$DATABASE" < "$UPDATE_SQL" 2>/dev/null || true

cd / && rm -rf "$TMPDIR"
echo "✅ 恢复完成！"
```

---

### `deploy/oj.sh` — 统一运维入口

```bash name=deploy/oj.sh
#!/bin/bash
# ============================================================
# HUSTOJ 运维统一入口
# 使用：sudo bash deploy/oj.sh <命令>
# ============================================================

DEPLOY=$(dirname "$(realpath "$0")")
SRC=/home/judge/src

# 从 judge.conf 读配置（官方标准读法）
conf_get() { grep "$1" /home/judge/etc/judge.conf 2>/dev/null | awk -F= '{print $2}'; }

case "$1" in
update)  bash "$DEPLOY/update.sh" ;;
bak|backup) bash "$DEPLOY/bak.sh" ;;
restore) bash "$DEPLOY/restore.sh" "$2" ;;

start)
    systemctl start mariadb nginx php8.3-fpm
    systemctl start judged
    echo "✅ 服务已启动" ;;

stop)
    systemctl stop judged nginx php8.3-fpm 2>/dev/null || true
    echo "✅ 服务已停止（数据库保持运行）" ;;

restart)
    bash "$0" stop; sleep 2; bash "$0" start ;;

status)
    echo "=== 服务状态 ==="
    for s in mariadb nginx php8.3-fpm judged; do
        st=$(systemctl is-active "$s" 2>/dev/null || echo "unknown")
        printf "  %-18s %s\n" "$s" "$st"
    done ;;

db|mysql)
    mysql \
        -h "$(conf_get OJ_HOST_NAME)" \
        -P "$(conf_get OJ_PORT_NUMBER)" \
        -u"$(conf_get OJ_USER_NAME)" \
        -p"$(conf_get OJ_PASSWORD)" \
        "$(conf_get OJ_DB_NAME)" ;;

log)
    case "$2" in
        judge)  tail -f /home/judge/log/judge.log ;;
        nginx)  tail -f /var/log/nginx/hustoj.error.log ;;
        bak)    tail -f /home/judge/log/bak.log ;;
        deploy) tail -f /home/judge/log/deploy.log ;;
        *)      tail -f /home/judge/log/judge.log ;;
    esac ;;

check)
    echo "=== 系统总览 ==="
    echo "-- 磁盘 --"
    df -h / | tail -1
    echo "-- 题目数据大小 --"
    du -sh /home/judge/data/ 2>/dev/null
    echo "-- 最近备份 --"
    ls -lht /var/backups/hustoj_*.tar.bz2 2>/dev/null | head -3 || echo "  无备份"
    echo "-- 代码版本 --"
    cd "$SRC" && git log --oneline -3
    echo "-- 模板版本 --"
    cd "$SRC/web/template/mytheme" 2>/dev/null \
        && git log --oneline -2 || echo "  无自定义模板" ;;

*)
    echo "HUSTOJ 运维工具"
    echo ""
    echo "用法: sudo bash deploy/oj.sh <命令>"
    echo ""
    printf "  %-12s %s\n" "update"   "更新代码（含模板）"
    printf "  %-12s %s\n" "bak"      "立即备份"
    printf "  %-12s %s\n" "restore"  "从备份恢复 (需指定文件)"
    printf "  %-12s %s\n" "start"    "启动所有服务"
    printf "  %-12s %s\n" "stop"     "停止服务"
    printf "  %-12s %s\n" "restart"  "���启服务"
    printf "  %-12s %s\n" "status"   "查看服务状态"
    printf "  %-12s %s\n" "db"       "进入数据库命令行"
    printf "  %-12s %s\n" "log"      "查看日志 (judge/nginx/bak/deploy)"
    printf "  %-12s %s\n" "check"    "系统状态总览"
    ;;
esac
```
