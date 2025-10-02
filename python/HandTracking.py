# Right hand tracking controls
import cv2
import socket
import HandTrackingModule as htm
import math

HOST  = '127.0.0.1'
PORT = 65432

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect((HOST, PORT))
print("Connected to Godot")

wCam, hCam = 640, 480
pTime = 0
tipIds = [4, 8, 12, 16, 20]

detector = htm.handDetector(detectionCon = 0.75)

cap = cv2.VideoCapture(0)
cap.set(3, wCam)
cap.set(4, hCam)

def get_command(lmList):
    # walking
    if lmList[8][2] < lmList[7][2] and lmList[12][2] < lmList[11][2] and not(lmList[16][2] < lmList[15][2]):
        fingers = ""
        if lmList[8][1] < lmList[12][1]:
            fingers = "walking forward"
        elif lmList[8][1] > lmList[12][1]:
            fingers = "walking backward"
        #speed
        x1, y1 = lmList[8][1], lmList[8][2]
        x2, y2 = lmList[12][1], lmList[12][2]
        cv2.line(img, (x1, y1), (x2, y2), (255, 0, 0), 2)
        length = math.hypot(x2 - x1, y2 - y1)
        if length < 30:
            return "slow " + fingers
        else:
            return "fast " + fingers

    # turn left
    elif lmList[8][1] < lmList[7][1] and lmList[8][2] < lmList[18][2]:
        return "turning left"
    # turn right
    elif lmList[8][1] > lmList[7][1] and lmList[8][2] > lmList[18][2]:
        return "turning right"

    # jump TODO:
    elif lmList[4][1] < lmList[3][1]:
        count = 0
        for id in range(1, 5):
            if lmList[tipIds[id]][2] < lmList[tipIds[id] - 1][2]:
                count += 1
        if count == 4:
            return "jump"

    # stop TODO:
    elif lmList[4][1] > lmList[8][1]:
        count = 0
        for id in range(1, 5):
            if lmList[tipIds[id]][2] > lmList[tipIds[id] - 1][2]:
                count += 1
        if count == 4:
            return "stop"

    return "idle"

try:
    while True:
        success, img = cap.read()
        img = detector.findHands(img)
        lmList = detector.findPosition(img, draw=False)
        if len(lmList) != 0:
            results = get_command(lmList)
            print(results)
            sock.sendall(results.encode() + b'\n')
        cv2.imshow("Img", img)
        cv2.waitKey(1)

except KeyboardInterrupt:
    pass
finally:
    cap.release()
    sock.close()
