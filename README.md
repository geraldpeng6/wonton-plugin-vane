# 云吞插件：Vane

开发流程见[插件开发指南](https://github.com/geraldpeng6/wonton-docs/blob/main/develop.md)。

Vane 的云吞插件：先搜网页，再由模型总结并标注出处。应用没有自己的用户体系，也不读身份头，访问控制由核心网关完成；
网页始终在网关登录后面。冷启动要从 Hugging Face 拉模型，容器要能出网（冒烟时配 `WONTON_DEV_EGRESS_PROXY`）。

`icon.png` 来自 Vane 官方标志，未用图片模型生成；来源、版权、处理方式、上游 MIT 全文和商标说明见 [NOTICE](NOTICE)。
Vane 名称与标志是其权利人的商标；本插件不代表与 Vane 或 ItzCrazyKns 存在官方合作、授权背书或隶属关系。

## 先跑起来

```bash
scripts/dev.sh up
scripts/dev.sh install
```

`up` 在本机起一套云吞，打印它的地址，浏览器打开后用 `scripts/dev.sh token` 输出的用户令牌登录；`install` 先列出插件要的
权限，确认后装上，打印插件网页的地址。Chrome、Firefox 和 curl 把 `*.localhost` 直接解析到本机，不用改 hosts。

## 仓库里有什么

| 路径 | 内容 |
| --- | --- |
| `docker-compose.yml` | 插件本身：compose 加上 `x-wonton` 清单 |
| `icon.png`、`web/` | 清单和 compose 引用的文件：图标、交给容器的配置和网页 |
| `screenshots/` | 商店详情页里的截图 |
| `scripts/check.sh` | 检查插件包，规则和安装时一样 |
| `scripts/dev.sh` | 开发环境：起一套云吞，装、重装、卸载插件，看日志 |
| `scripts/publish.sh` | 发布一个版本：构建自己的镜像、按摘要写回、打 tag、推送 |
| `scripts/smoke-probes.sh` | `scripts/dev.sh smoke` 对这个插件逐项的探测 |
| `AGENTS.md` | 给人和 AI 编程代理的规则 |
| `NOTICE` | 图标等第三方素材的许可和声明 |
| `.wonton/` | 开发环境的设置、密钥和数据，不提交 |
