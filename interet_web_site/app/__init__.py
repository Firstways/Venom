from flask import Flask
from .config import Config
from .models import db
from .routes import main

def create_app():
    app = Flask(__name__, template_folder="../templates") 
    app.config.from_object(Config)

    db.init_app(app)
    app.register_blueprint(main)

    with app.app_context():
        db.create_all()


    

    return app

