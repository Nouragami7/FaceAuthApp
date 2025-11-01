# Face Recognition Flutter App

## Overview

A Flutter-based face recognition app that enables users to enroll, recognize, update, and manage face data locally using the device camera and database.

## Features

### 1. Enroll New User

* Add new users by entering an ID and name.
* Capture exactly **5 clear face photos** using a fullscreen camera.
* Validate that all 5 images are captured before saving.
* Prevent duplicate IDs — shows a message if the same ID already exists.

### 2. Face Detection Feedback

* If the camera does not detect any face, a SnackBar appears with the message:
  *“No face detected — please face the camera clearly.”*

### 3. Recognize User

* Open the camera to detect and recognize faces.
* Compare live face vectors with stored data.
* Display the recognized user’s name or show “Unknown” if no match is found.

### 4. Re-Enroll (Update Existing User)

* From the Home screen, users can select **Re-Enroll** to update their photos.
* Capture 5 new images for the same user ID.
* The app replaces old images and vectors with the new ones automatically.
* Show confirmation message when update is complete.

### 5. Manage Users

* **Edit:** Change the name of any user.
* **Delete:** Remove a user and all their related data.
* **Re-Enroll:** Re-capture new photos for better recognition accuracy.

### 6. Home Screen

* Displays all enrolled users with their names, IDs, and profile images.
* Provides full control to edit, delete, or re-enroll users.
* Includes quick access buttons:

  * **Enroll:** Add a new user.
  * **Recognize:** Identify faces in real time.


## Technical Details

* **Language:** Dart
* **Framework:** Flutter
* **Architecture:** Bloc (State Management)
* **Database:** Drift (SQLite local database)
* **Face Detection:** Google ML Kit
* **Image Processing:** `package:image`


## Recent Updates

* Added re-enroll flow to update existing users’ photos and vectors.
* Added SnackBar alert for “No face detected”.
* Enabled back navigation in fullscreen camera.
* Improved UI/UX for Enroll and Home screens.
* Enhanced database logic for replacing and validating user data.
