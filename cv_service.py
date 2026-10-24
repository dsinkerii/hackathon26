#imports
import time
import cv2
from ultralytics import YOLO

#variables(or smth)
webcam_n = int(input("Enter the number of webcam number for testing(-1 = in-code URL): "))
# can use several webcams for test, so have to switch between

url = None # <-------------- Dsinkerii put your API stuff here pls pls pls pls

if webcam_n == -1:
    source = url
else:
    source = webcam_n

#functions


def capture_image():
    cap = cv2.VideoCapture(source) # well, camera capture
    ret, frame = cap.read() # returns a single frame

    l_tm = time.localtime()
    date = f"{l_tm.tm_year}_{l_tm.tm_mon}_{l_tm.tm_mday}_{l_tm.tm_hour}_{l_tm.tm_min}_{l_tm.tm_sec}"
    print(date)

    cv2.imwrite(f'alert_images/{date}.png', frame) # writes to file(hopefully)
    print("CAUGHT EM!!! KIDNAPPERS!!!!!!")
    cap.release()


#main code
model = YOLO('yolo26n.pt') # initialises model
print(model.names) # prints dictionary

results = model(source, stream=True, show=True, stream_buffer=False) # checks for dangerous objects
#test camera: 'http://109.206.96.58:8080/cam_1.cgi'

for result in results:
    class_list = result.boxes.cls.tolist()
    for cl in class_list:
        if model.names.get(cl) in ['car', 'truck', 'bus']:
            print("CHILD SAFETY ALERT or smth idk they don't pay me")
            capture_image()
            time.sleep(5)