import cv2
import mediapipe as mp
import time
import math
import socket

HOST  = '127.0.0.1'
PORT = 65432

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
sock.connect((HOST, PORT))
print("Connected to Godot")

class handDetector():
    def __init__(self, mode=False, maxHands=2, detectionCon=0.5, trackCon=0.5):
        self.mode = mode
        self.maxHands = maxHands
        self.detectionCon = detectionCon
        self.trackCon = trackCon

        self.mpHands = mp.solutions.hands
        self.hands = self.mpHands.Hands(
            static_image_mode=self.mode,
            max_num_hands=self.maxHands,
            min_detection_confidence=self.detectionCon,
            min_tracking_confidence=self.trackCon
        )
        self.mpDraw = mp.solutions.drawing_utils

    def findHands(self, img, draw=True):
        imgRGB = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        self.results = self.hands.process(imgRGB)

        if self.results.multi_hand_landmarks and draw:
            for handLms in self.results.multi_hand_landmarks:
                self.mpDraw.draw_landmarks(img, handLms, self.mpHands.HAND_CONNECTIONS)
        return img
    
    def findMiddleFingerDistance(self, img, draw=True):
        distances = []
        if self.results.multi_hand_landmarks:
            h, w, c = img.shape
            for handLms in self.results.multi_hand_landmarks:
                # Wrist and middle finger tip
                wrist = handLms.landmark[0]
                middle_tip = handLms.landmark[9]

                x0, y0 = int(wrist.x * w), int(wrist.y * h)
                x1, y1 = int(middle_tip.x * w), int(middle_tip.y * h)

                # Compute midpoint
                mid_x = (x0 + x1) // 2
                mid_y = (y0 + y1) // 2

                # Draw line and midpoint
                if draw:
                    cv2.line(img, (x0, y0), (x1, y1), (0, 0, 255), 2)  # red line
                    cv2.circle(img, (mid_x, mid_y), 12, (0, 255, 0), cv2.FILLED)  # green midpoint

                # Compute distance
                dist = math.hypot(x1 - x0, y1 - y0)
                distances.append(dist)
        return distances

    def findFingertips(self, img, draw=True):
        tipIds = [4, 8, 12, 16, 20]  # Thumb, Index, Middle, Ring, Pinky
        fingertip_positions = []

        if self.results.multi_hand_landmarks:
            h, w, c = img.shape
            for handLms in self.results.multi_hand_landmarks:
                hand_tips = []
                for tipId in tipIds:
                    lm = handLms.landmark[tipId]
                    cx, cy = int(lm.x * w), int(lm.y * h)
                    hand_tips.append((cx, cy))
                    if draw:
                        cv2.circle(img, (cx, cy), 10, (255, 0, 0), cv2.FILLED)  # blue dots
                fingertip_positions.append(hand_tips)

        return fingertip_positions

def get_command(lmList):
    pass 


def main():
    pTime = 0
    cap = cv2.VideoCapture(0)
    detector = handDetector()

    while True:
        success, img = cap.read()
        if not success or img is None:
            print("Failed to grab frame")
            continue

        img = detector.findHands(img)

        # Middle finger distance with midpoint
        distances = detector.findMiddleFingerDistance(img, draw=True)
        if distances:
            for i, d in enumerate(distances):
                print(f"Hand {i} wrist→middle distance: {d:.1f} px")

        # Fingertips
        fingertips = detector.findFingertips(img, draw=True)
        if fingertips:
            for i, hand in enumerate(fingertips):
                print(f"Hand {i} fingertips:", hand)

        # FPS display
        cTime = time.time()
        fps = 1 / (cTime - pTime) if (cTime - pTime) != 0 else 0
        pTime = cTime
        cv2.putText(img, str(int(fps)), (10, 70), cv2.FONT_HERSHEY_PLAIN, 3,
                    (255, 0, 255), 3)

        cv2.imshow("Image", img)
        cv2.waitKey(1)


if __name__ == "__main__":
    main()

