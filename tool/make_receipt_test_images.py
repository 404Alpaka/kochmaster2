from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
Path('build/design').mkdir(parents=True, exist_ok=True)
code='4006381333931'
l=['0001101','0011001','0010011','0111101','0100011','0110001','0101111','0111011','0110111','0001011']
g=['0100111','0110011','0011011','0100001','0011101','0111001','0000101','0010001','0001001','0010111']
r=['1110010','1100110','1101100','1000010','1011100','1001110','1010000','1000100','1001000','1110100']
parity=['LLLLLL','LLGLGG','LLGGLG','LLGGGL','LGLLGG','LGGLLG','LGGGLL','LGLGLG','LGLGGL','LGGLGL'][int(code[0])]
bits='101'+''.join((l if p=='L' else g)[int(c)] for c,p in zip(code[1:7],parity))+'01010'+''.join(r[int(c)] for c in code[7:])+'101'
im=Image.new('RGB',(600,260),'white');d=ImageDraw.Draw(im)
for i,b in enumerate(bits):
    if b=='1': d.rectangle((60+i*5,20,64+i*5,210),fill='black')
im.save('build/design/test-ean.png')
im=Image.new('RGB',(1100,600),'white');d=ImageDraw.Draw(im);f=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',34)
d.multiline_text((50,40),'REWE\nJOGHURT              1,29 B\nMILCH                2,18 B\n    2 Stk x 1,09\nSUMME EUR            3,47',font=f,fill='black',spacing=18)
im.save('build/design/test-ocr-receipt.png')
