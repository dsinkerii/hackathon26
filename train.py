import cv2
from ultralytics import YOLO

model = YOLO('yolo26n.pt')
model.train(data='coco8.yaml', epochs=3)