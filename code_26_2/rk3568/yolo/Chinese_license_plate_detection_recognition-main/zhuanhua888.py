import cv2
import numpy as np
import sys

def convert_image(CCPD,s result):
    img = cv2.imread(CCPD)
    if img is None:
        print(f"Failed to load {CCPD}")
        return
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    r = (rgb[:,:,0] >> 3).astype(np.uint16)
    g = (rgb[:,:,1] >> 2).astype(np.uint16)
    b = (rgb[:,:,2] >> 3).astype(np.uint16)
    rgb565 = ((r << 11) | (g << 5) | b).astype('<u2')
    rgb565.tofile(result)
    print(f"Saved {result}")

if __name__ == "__main__":
    convert_image(CCPD, result)