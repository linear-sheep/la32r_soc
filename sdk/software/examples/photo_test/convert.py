from PIL import Image
import os
import argparse

# 自动查找输入图片，优先使用 test.png/jpg/jpeg，其次使用文件夹中第一个支持的图片格式。
def resolve_input_image(script_dir):
    # Prefer test.* names, then fall back to any supported image in the folder.
    candidates = ['test.png', 'test.jpg', 'test.jpeg']
    for name in candidates:
        path = os.path.join(script_dir, name)
        if os.path.isfile(path):
            return path

    supported_ext = ('.png', '.jpg', '.jpeg')
    for name in sorted(os.listdir(script_dir)):
        if name.lower().endswith(supported_ext):
            return os.path.join(script_dir, name)

    raise FileNotFoundError(
        'No input image found. Please provide a .png/.jpg/.jpeg file in this folder, '
        'or use --input to specify a file path.'
    )

def parse_args(script_dir):
    parser = argparse.ArgumentParser(
        description='Convert an image to RGB332 C header data (default size: 400x300).'
    )
    parser.add_argument(
        '-i', '--input',
        help='Input image path (.png/.jpg/.jpeg). Defaults to auto-detect in script folder.'
    )
    parser.add_argument(
        '-o', '--output',
        default=os.path.join(script_dir, 'image.h'),
        help='Output header path (default: image.h in script folder).'
    )
    parser.add_argument(
        '--width',
        type=int,
        default=400,
        help='Target image width (default: 400).'
    )
    parser.add_argument(
        '--height',
        type=int,
        default=300,
        help='Target image height (default: 300).'
    )
    return parser.parse_args()

def convert_image(input_path, output_path, width=400, height=300):
    img = Image.open(input_path).convert('RGB')
    
    # 保持比例缩放并居中贴到目标画布
    img.thumbnail((width, height), Image.ANTIALIAS)
    new_img = Image.new('RGB', (width, height), (0, 0, 0))
    paste_x = (width - img.width) // 2
    paste_y = (height - img.height) // 2
    new_img.paste(img, (paste_x, paste_y))
    
    with open(output_path, 'w') as f:
        f.write('#ifndef IMAGE_H\n')
        f.write('#define IMAGE_H\n\n')
        f.write('static const unsigned char image_data[%d * %d] = {\n' % (width, height))
        
        pixels = new_img.load()
        count = 0
        for y in range(height):
            for x in range(width):
                r, g, b = pixels[x, y]
                # RGB332
                r3 = (r & 0xE0)
                g3 = (g & 0xE0) >> 3
                b2 = (b & 0xC0) >> 6
                pixel = r3 | g3 | b2
                
                f.write(f'0x{pixel:02x}, ')
                count += 1
                if count % 16 == 0:
                    f.write('\n')
        
        f.write('\n};\n\n')
        f.write('#endif\n')

if __name__ == '__main__':
    script_dir = os.path.dirname(os.path.abspath(__file__))
    args = parse_args(script_dir)
    input_image = args.input if args.input else resolve_input_image(script_dir)
    convert_image(input_image, args.output, width=args.width, height=args.height)
