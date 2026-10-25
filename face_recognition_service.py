from deepface import DeepFace as df
import cv2
import pandas as pd

# DeepFace cfg
backend = 'retinaface'
model = 'ArcFace'

# cfg
camera_n = 0

# functions
def capture_face(): # later: show webcam before capture, photo after 5s
    input('Press ENTER to capture face for recognition')
    cap = cv2.VideoCapture(camera_n) # well, camera capture
    ret, frame = cap.read() # returns a single frame
    if ret == True:
        return frame
    
    cap.release()


face = df.find(img_path=capture_face(),
               db_path='data',
               detector_backend=backend,
               model_name=model,
               anti_spoofing=False,
               similarity_search=True,
               return_type='dict')

confidence = face[0][0].get('confidence')

if confidence < 80:
    print('NOT IN DB! GET OUT!')
else:
    print('hmmm you do live here welcome')