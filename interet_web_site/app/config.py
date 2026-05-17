import os

class Config:
    SQLALCHEMY_DATABASE_URI = "sqlite:///devices.db"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    BASE_DIR = os.path.abspath(os.path.dirname(__file__))

    UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")