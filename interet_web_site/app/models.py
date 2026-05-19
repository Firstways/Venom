from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

class Device(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    hostname = db.Column(db.String(100))
    ip = db.Column(db.String(50))
    os = db.Column(db.String(100))
    name = db.Column(db.String(200))

    user = db.Column(db.String(100))
    hardware = db.Column(db.Text)
    software = db.Column(db.Text)
    processes  = db.Column(db.Text)
    credentials = db.relationship('Credential', backref='device', lazy=True)
    files = db.relationship('File', backref='device', lazy=True)
    networks = db.relationship('Network', backref='device', lazy=True)


class Credential(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    data = db.Column(db.String(200))
    device_id = db.Column(db.Integer, db.ForeignKey('device.id'))


class File(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    filename = db.Column(db.String(200))
    data = db.Column(db.LargeBinary, nullable=False)
    device_id = db.Column(db.Integer, db.ForeignKey('device.id'))


class Network(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    connection = db.Column(db.String(200))
    device_id = db.Column(db.Integer, db.ForeignKey('device.id'))