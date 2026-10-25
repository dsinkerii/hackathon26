import cv2
import time

camera_n = 0

def capture_image():
    input('Press ENTER to add face to DB')
    cap = cv2.VideoCapture(camera_n) # well, camera capture
    ret, frame = cap.read() # returns a single frame

    l_tm = time.localtime()
    date = f"{l_tm.tm_year}_{l_tm.tm_mon}_{l_tm.tm_mday}_{l_tm.tm_hour}_{l_tm.tm_min}_{l_tm.tm_sec}"

    cv2.imwrite(f'data/{date}_face.png', frame) # writes to file(hopefully)
    cap.release()

capture_image()