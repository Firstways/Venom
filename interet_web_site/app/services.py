
from .models import db


def get_device(os, hostname, user):
    return Device.query.filter_by(
        hostname=hostname,
        os=os,
        user=user
    ).first()