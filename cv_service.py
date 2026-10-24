import cv2
from ultralytics import YOLO

model = YOLO('yolo26n.pt')

results = model(0, stream=True, show=True)
for result in results:
    pass