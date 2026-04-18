from PIL import Image
import os

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
    convert_image(os.path.join(script_dir, 'test.png'), os.path.join(script_dir, 'image.h'))
