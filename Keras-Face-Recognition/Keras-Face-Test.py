# ---------------------------------------------------------------------------------
"""
@author: Jakub Tlach
"""
# ---------------------------------------------------------------------------------

import cv2
import numpy as np
from keras.models import load_model


# Load the model/image
loaded_model = load_model('kerasFacesModel.hdf5')
test_image = cv2.imread('test-faces/other/4472.png')


# Set the number of channels
# 1 for B&W images
# 4 for RGB images
num_channel = 4


# ----------------------------------------------------
# Comment, when RGB images
# ----------------------------------------------------
#test_image = cv2.cvtColor(test_image, cv2.COLOR_BGR2GRAY)
#test_image = cv2.resize(test_image, (100, 100))

test_image = np.array(test_image)
test_image = test_image.astype('float32')
test_image /= 255
print (test_image.shape)


if num_channel == 1:

	test_image = np.expand_dims(test_image, axis=3)
	test_image = np.expand_dims(test_image, axis=0)
	print (test_image.shape)

else:

	test_image = np.expand_dims(test_image, axis=0)
	print (test_image.shape)


# ---------------------------------------------------------------------------------
print("\n---------------> Prediction\n")
# ---------------------------------------------------------------------------------

print((loaded_model.predict(test_image)))
print(loaded_model.predict_classes(test_image))


