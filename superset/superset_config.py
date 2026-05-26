"""Superset configuration."""
import os

SECRET_KEY = os.environ["SECRET_KEY"]
SQLALCHEMY_DATABASE_URI = os.environ["DATABASE_URI"]
