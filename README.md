# 局域网共享中心

这是一个轻量级局域网文件共享网页。电脑端启动后，同一局域网内的手机、平板和其他电脑可以通过浏览器访问页面，上传、下载、打开或删除共享文件。

## 快速运行

Windows 下双击：

```text
一键启动局域网共享网页.bat
```

也可以运行：

```text
start-server.bat
```

服务启动后会自动打开浏览器，并在项目目录生成 `lan-share-url.txt`，里面包含本机访问地址和局域网访问地址。

## 停止服务

双击：

```text
stop-server.bat
```

## 访问方式

本机访问：

```text
http://127.0.0.1:8000/
```

局域网访问地址以启动脚本生成的 `lan-share-url.txt` 为准。其他设备需要和这台电脑处在同一个局域网内，并允许 Windows 防火墙放行 8000 端口。

## 共享文件目录

上传后的文件会保存在：

```text
files/
```

该目录中的实际文件属于运行数据，默认不会提交到 GitHub。

## 配置端口

如需修改端口，可以在启动前设置环境变量：

```powershell
$env:LAN_SHARE_PORT = "8010"
.\start-lan-share.ps1
```

## 隐私说明

本项目上传 GitHub 时会排除：

- `files/` 中的真实共享文件
- `logs/` 日志
- `server.log`
- `lan-share-url.txt`
- 本机路径、局域网 IP、账号密码和 token
- 打包生成的 ZIP 文件
