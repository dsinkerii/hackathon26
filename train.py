"""
RUN THIS FILE ONCE, THEN FORGET IT
THIS FILE TRAINS MODEL. THAT'S IT. NOTHING ELSE

Requirements:
-ultralytics
-opencv-python
"""

from ultralytics import YOLO

model = YOLO('yolo26n.pt')
model.train(data='coco8.yaml', epochs=3)