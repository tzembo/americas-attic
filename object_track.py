# import the necessary packages
import json
import sys
import signal	
import numpy as np
import cv2
import argparse
import socket
import imutils
from imutils import contours
from skimage import measure

# Socket info
TCP_IP = '127.0.0.1'
TCP_PORT = 5005

# For OpenCV2 image display
WINDOW_NAME = 'Orb Tracking' 

parser = argparse.ArgumentParser(description='OpenCV script for America\'s Attic.')
parser.add_argument("-c", metavar="CAMERA", help="specify external camera")
parser.add_argument("--debug", help="visualize script output", action="store_true")

# close connectio on interrupt
def handler(signum, frame):
	conn.close()
	sys.exit(0)

# return tracked points in frame
def track(frame, debug):

	# return list 
	points = []


	# load the frame, convert it to grayscale, and blur it
	gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
	blurred = cv2.GaussianBlur(gray, (11, 11), 0)

	# threshold the frame to reveal light regions in the
	# blurred frame
	thresh = cv2.threshold(blurred, 200, 255, cv2.THRESH_BINARY)[1]

	# perform a series of erosions and dilations to remove
	# any small blobs of noise from the thresholded frame
	thresh = cv2.erode(thresh, None, iterations=3)
	thresh = cv2.dilate(thresh, None, iterations=4)


	im2, cnts, hierarchy = cv2.findContours(thresh.copy(), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
	
	output = cv2.cvtColor(thresh, cv2.COLOR_GRAY2BGR)

	try:
		cnts = contours.sort_contours(cnts)[0]
	except ValueError:
		return points;
	 
	# loop over the contours
	for c in cnts:

		# draw the bright spot on the frame
		((cX, cY), radius) = cv2.minEnclosingCircle(c)
		points.append((int(cX), int(cY), int(radius)))
		if debug:
			cv2.circle(output, (int(cX), int(cY)), int(radius), (0, 0, 255), 2)
			cv2.line(output, (int(cX), int(cY)), (int(cX + radius), int(cY)), (0, 0, 255), 2)
			cv2.putText(output, "{}".format(int(radius)), (int(cX + 0.5 * radius), int(cY) + 5), cv2.FONT_HERSHEY_PLAIN, 1, (0, 255, 0))

	if debug:
		cv2.imshow(WINDOW_NAME, output)
		cv2.waitKey(1)

	return points

if __name__ == '__main__':

	args = parser.parse_args()

	if args.c:
		camera = args.c
	else:
		camera = 0

	if not args.debug:
		s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
		s.bind((TCP_IP, TCP_PORT))
		s.listen(1)
		conn, addr = s.accept()
		print 'Connection address:', addr

		signal.signal(signal.SIGINT, handler)

	capture = cv2.VideoCapture(1)

	while True:

		okay, frame = capture.read()

		if okay:

			frame = cv2.flip(frame, 1)

			msg = {}
			msg['pts'] = track(frame, args.debug)
			if not args.debug:
				conn.sendall(json.dumps(msg) + "\n")

		else:
			print("capture failed")
			if not args.debug:
				conn.close()
			break