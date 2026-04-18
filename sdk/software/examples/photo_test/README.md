# Photo Test

这是一个用于测试 DVI 图像显示的示例程序。该程序主要用于在屏幕上显示一张静态图片，以验证显存（VRAM）和 DVI 显示模块的正确性。

## 主要功能
- 将分辨率为 400x300 的静态图片（硬编码在 `image.h` 中的 `image_data` 数组）渲染到目标分辨率 800x600 的屏幕中央。
- 图像数据采用 8 位颜色深度格式 (RGB332)。
- 通过设置 VRAM 基地址并使能 DVI 控制器，单次写入显存后持续保持输出（无刷新的静态显示）。

## 运行与现象
- 编译并下载运行后，外接显示器上将会显示出一张居中的图片。
- 背景其他区域默认被填充为黑色。

## 编译与运行命令
在本目录下，执行以下命令进行编译（运行前请检查是否运行了 convert.py 脚本）：
```bash
make
```
编译完成后，生成的目标文件存放在 `obj/` 目录下（通常为可以下载的二进制文件），可通过下载工具烧录或者串口传送到板子上运行。

## 如何引入其他图片
`photo_test` 使用了 `convert.py` 这个 Python 脚本将普通图片转换为 C 语言的数组格式并保存在 `image.h` 中。如果想更换显示的图片，请按照以下步骤操作：

1. 准备一张你喜欢的图片（例如 `my_pic.jpg` 或 `my_pic.png`），将它放到当前 `photo_test` 目录下。
2. 打开 `convert.py`，定位到文件最末尾的这行代码：
   ```python
   convert_image(os.path.join(script_dir, 'test.png'), os.path.join(script_dir, 'image.h'))
   ```
   **将其中的 `'test.png'` 替换为你准备的图片名称**（例如 `'my_pic.jpg'`）。
3. 运行该 Python 脚本生成新的 `image.h` 头文件：
   ```bash
   python convert.py
   ```
   *(注意：该脚本依赖于 Pillow 库，如果没有可通过 `pip install Pillow` 安装。若在新版本 Pillow 遇到 `Image.ANTIALIAS` 报错，请将其修改为 `Image.Resampling.LANCZOS`)*
4. 重新执行 `make` 编译工程即可生效。
