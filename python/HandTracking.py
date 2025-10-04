# Hand tracking controlling yaw/pitch
import cv2
import socket
import HandTrackingModule as htm

HOST = '127.0.0.1'
PORT = 65432

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect((HOST, PORT))
print("Connected to Godot")

wCam, hCam = 640, 480
detector = htm.handDetector(detectionCon=0.75)

cap = cv2.VideoCapture(0)
cap.set(3, wCam)
cap.set(4, hCam)

try:
    while True:
        success, img = cap.read()
        img = detector.findHands(img)
        lmList = detector.findPosition(img, draw=False)

        if len(lmList) != 0:
            # Get index finger tip position (landmark 8)
            x, y = lmList[8][1], lmList[8][2]

            # Normalize to -1..1 range
            norm_x = (x - wCam // 2) / (wCam // 2)  # left = -1, right = 1
            norm_y = (y - hCam // 2) / (hCam // 2)  # up = -1, down = 1

            msg = f"{norm_x:.2f},{norm_y:.2f}"
            sock.sendall(msg.encode() + b'\n')
            cv2.circle(img, (x, y), 10, (0, 255, 0), cv2.FILLED)

        cv2.imshow("Img", img)
        if cv2.waitKey(1) & 0xFF == 27:
            break

except KeyboardInterrupt:
    pass
finally:
    cap.release()
    sock.close()
