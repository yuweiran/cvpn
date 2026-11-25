# cvpn 个人 VPN 项目

本仓库是 [wg-easy/wg-easy](https://github.com/wg-easy/wg-easy) 的 Fork，包含完整应用源码、Docker 构建配置和本项目的部署入口。WireGuard 和网页管理功能直接使用开源实现，服务器信息独立配置。

## 1. 当前使用方式

- 本地 Windows：管理源码、配置和 Git；也可运行脚本检查配置。
- 实际 VPN 服务端：部署到具备公网 IP 的 Linux 主机，例如 Azure Ubuntu VM。
- 默认镜像：`ghcr.io/wg-easy/wg-easy:15.5.0`，固定到初始化时核实的稳定版本。
- Fork 源码跟随上游 `master`，可能包含稳定镜像之后的改动。修改源码后需自行构建镜像，官方镜像不会包含你的改动。
- 保留上游 AGPL-3.0-only 许可证和原始文档。

本次初始化不要求填写服务器地址，不会创建云资源或启动公网 VPN。

## 2. 项目入口

| 路径 | 用途 |
|---|---|
| `deploy/compose.yaml` | 本项目使用的部署配置 |
| `deploy/.env.example` | 可提交的参数模板 |
| `deploy/.env` | 自己的配置，不提交 Git |
| `scripts/cvpn.ps1` | Windows PowerShell 管理脚本 |
| `scripts/cvpn.sh` | Linux Bash 管理脚本 |
| `scripts/sync-fork.ps1` | 本地 Git 元数据与远程 Fork 的同步脚本 |
| `src/` | 上游完整前后端源码 |
| `Dockerfile` | 从 Fork 源码构建镜像 |
| `docker-compose.dev.yml` | 上游开发环境 |
| `docs/` | 上游功能与部署文档 |

使用下方脚本或明确指定 `deploy/compose.yaml`。根目录的 `docker-compose.yml` 是上游原样配置，它没有本项目的管理端口限制，不要混用这两个部署入口。

## 3. 本地初始化配置

在项目根目录运行：

```powershell
.\scripts\cvpn.ps1 init
```

脚本只会在配置不存在时创建 `deploy/.env`，不会覆盖已填写内容。没有服务器时保留 `INIT_ENABLED=false` 即可。

安装 Docker Engine/Compose v2 后，可以检查配置：

```powershell
.\scripts\cvpn.ps1 check
```

检查命令使用 `config --quiet`，避免把初始化密码输出到终端。Windows 上的配置检查不能替代 Linux 主机上的真实 VPN 测试；正式部署建议原生 Linux。

## 4. 配置项

| 参数 | 默认值 | 说明 |
|---|---|---|
| `WG_EASY_IMAGE` | `ghcr.io/wg-easy/wg-easy:15.5.0` | 稳定镜像，或自行构建的镜像名称 |
| `COMPOSE_PROJECT_NAME` | `cvpn` | 决定资源和数据卷名称；部署后保持不变 |
| `VPN_PORT` | `51820` | 主机和容器使用相同 UDP 端口；网页初始化时也选这个端口 |
| `WEB_UI_PORT` | `51821` | 仅绑定服务器 `127.0.0.1` 的管理端口 |
| `INIT_ENABLED` | `false` | 是否在新数据卷首次启动时自动初始化 |
| `INIT_USERNAME` | 空 | 自动初始化管理员用户名 |
| `INIT_PASSWORD` | 空 | 自动初始化密码，使用自己的强密码 |
| `VPN_HOST` | 空 | 自动初始化的客户端连接地址，填写服务器公网 IP 或域名 |
| `INIT_DNS` | `1.1.1.1,1.0.0.1` | 自动初始化 DNS |
| `INIT_ALLOWED_IPS` | `0.0.0.0/0,::/0` | 自动初始化全局路由 |

两种初始化方式任选一种：

1. **网页初始化（默认）**：保持 `INIT_ENABLED=false`，通过 SSH 转发打开页面，设置管理员、Host 和端口。
2. **配置初始化**：首次使用空数据卷前设置 `INIT_ENABLED=true`，同时填写 `INIT_USERNAME`、`INIT_PASSWORD`、`VPN_HOST`；端口沿用 `VPN_PORT`。

`.env` 中密码若有 `$` 或 `#`，用单引号包裹以避免变量插值，例如 `INIT_PASSWORD='replace-with-your-own-long-password'`。不要直接使用示例密码。

`INIT_*` 仅初始化新安装，不会修改已有数据库。初始化完成后把 `INIT_ENABLED` 改回 `false`、清空 `INIT_USERNAME`、`INIT_PASSWORD` 和 `VPN_HOST`，再运行 `up` 重建容器以移除其中的凭据。以后修改账号、Host 或 VPN 监听端口，应在网页中修改，并同步 Compose 映射和云防火墙；单改 `.env` 不会改写数据库中的端口。

## 5. 将来在 Azure Ubuntu 上部署

准备官方 Ubuntu LTS VM、公网 IPv4、SSH 密钥，并安装 [Docker Engine 和 Compose 插件](https://docs.docker.com/engine/install/ubuntu/)。

云安全组/NSG 规则：

| 端口 | 来源 |
|---|---|
| TCP 22 | 自己的公网 IP，尽量限制到 `/32` |
| UDP `VPN_PORT` | 需要接入的设备网络 |
| TCP `WEB_UI_PORT` | 不开放公网入站 |

在 Linux 主机执行：

```bash
git clone https://github.com/yuweiran/cvpn.git
cd cvpn
bash scripts/cvpn.sh init
# 按需要编辑 deploy/.env
bash scripts/cvpn.sh check
bash scripts/cvpn.sh pull
bash scripts/cvpn.sh up
bash scripts/cvpn.sh status
```

普通用户若没有 Docker 操作权限，可在上述 Docker 操作脚本前使用 `sudo`，例如 `sudo bash scripts/cvpn.sh up`。`init` 可由当前用户运行。

在自己的电脑上打开 SSH 转发；替换用户名、密钥和服务器地址：

```powershell
ssh -i "PATH_TO_KEY" -N -L 127.0.0.1:51821:127.0.0.1:51821 ADMIN_USER@SERVER_IP
```

保持 SSH 窗口运行，在浏览器打开 <http://127.0.0.1:51821>。若修改了 `WEB_UI_PORT`，同步修改转发目标端口和本地访问端口。

`INSECURE=true` 只用于这条本机 HTTP + SSH 加密管理链路。管理页面始终绑定回环地址，不能直接映射到公网。使用当前受支持的 Docker 版本；Docker 发布端口的行为与 UFW 不完全相同，应同时检查 NSG 和监听地址。

## 6. 客户端与验收

从 [WireGuard 官网](https://www.wireguard.com/install/) 获取客户端。每台设备单独生成配置，通过文件或二维码导入，不共用同一组密钥。

- 确认近期握手与收发计数增长。
- 确认普通 HTTPS 网站、DNS 解析和所需目标网站的实际功能正常。
- 确认 IPv4 出口是服务器地址。
- 确认 IPv6 走服务器或明确被客户端阻断，不从本地绕行。Compose 的私有 IPv6 网段不代表服务器已具备公网 IPv6 出口。
- 检查移动网络切换、主机重启后的恢复。
- 确认公网不能访问管理端口。

标准 WireGuard 依赖 UDP 可达性。目标网站可用性还取决于其服务地区、账号条件和出口风控，不能只用“隧道连接成功”来判定。

## 7. 常用操作和数据

| 操作 | PowerShell | Linux Bash |
|---|---|---|
| 初始化配置 | `.\scripts\cvpn.ps1 init` | `bash scripts/cvpn.sh init` |
| 配置检查 | `.\scripts\cvpn.ps1 check` | `bash scripts/cvpn.sh check` |
| 拉取镜像 | `.\scripts\cvpn.ps1 pull` | `bash scripts/cvpn.sh pull` |
| 启动或应用配置 | `.\scripts\cvpn.ps1 up` | `bash scripts/cvpn.sh up` |
| 查看状态 | `.\scripts\cvpn.ps1 status` | `bash scripts/cvpn.sh status` |
| 跟随日志 | `.\scripts\cvpn.ps1 logs` | `bash scripts/cvpn.sh logs` |
| 停止并移除容器 | `.\scripts\cvpn.ps1 down` | `bash scripts/cvpn.sh down` |

默认数据卷是 `cvpn_wireguard`。`down` 保留数据卷；不要附加 `-v`。改项目名称、改 Docker 主机或新建卷会造成读到另一份数据库，先备份再调整。

升级前保存镜像版本和完整数据卷备份。数据库升级后回滚可能需要恢复旧数据，不能只改回镜像标签。配置、密钥、二维码和备份都不能提交到公开仓库。

Azure 新人额度和 VM 免费用量应以自己订阅的门户为准。长期费用需要同时核算 VM、磁盘、公网 IP、出站流量和备份；关机不代表所有资源停止计费。

## 8. 从 Fork 源码构建

在具备 Docker 的构建主机上，在仓库根目录运行：

```bash
docker build -t cvpn/wg-easy:local .
```

将 `deploy/.env` 的 `WG_EASY_IMAGE` 改成 `cvpn/wg-easy:local`，然后运行 `up`，不要对尚未发布的本地镜像运行 `pull`。本地镜像必须构建在运行 Compose 的同一 Docker 主机上，或先自行发布到可访问的镜像仓库。

开发环境、依赖安装和应用检查沿用上游 [README](README.md#development) 和 [contributing.md](contributing.md)。只调整部署文件时不必安装全部前端依赖。

## 9. 同步上游

如果初始化会话不能写入本地 `.git`，而文件已经提交到 GitHub，可在具备当前目录 Git 写权限的本机 PowerShell 中执行：

```powershell
.\scripts\sync-fork.ps1
```

脚本只接受预期的远程地址，拒绝覆盖已暂存的改动或丢弃本地分叉提交。它先获取远程，再用保留工作文件的 mixed reset 将本地分支与已发布提交对齐；不使用 hard reset，也不会推送到上游。若工作文件有额外修改，它们会保留为未提交改动。

本地远程关系应为：

| 名称 | 地址 | 用途 |
|---|---|---|
| `origin` | `https://github.com/yuweiran/cvpn.git` | 自己的 Fork，推送本项目改动 |
| `upstream` | `https://github.com/wg-easy/wg-easy.git` | 获取上游更新 |

在工作区干净时合并更新：

```bash
git fetch upstream
git switch master
git merge upstream/master
# 检查冲突、发布说明并完成相关验证
git push origin master
```

不要向上游原仓库推送。镜像版本是否升级应单独决定，不随源码合并自动改变。
