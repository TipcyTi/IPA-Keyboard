# 图标

- `Chatgo.png`：App 图标原图（白底 CHAT 字标，2048×2048，无透明通道）。
- `make_icons.py`：把原图重采样成 `AppIcon.appiconset` 的全部尺寸（20/29/40/60 的 @2x、@3x 与 1024 营销图）。

重新生成：

```sh
python3 Design/make_icons.py
```
