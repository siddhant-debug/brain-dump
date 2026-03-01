import sys
import os
from sqlalchemy import create_engine
from passlib.context import CryptContext

sys.path.append(os.path.abspath(os.path.join(os.getcwd())))

from app.models.models import UserDirective
from app.core.database import Base, engine  # Assuming these exist


def run_migration():
    print("Creating UserDirective table in the database...")
    UserDirective.__table__.create(bind=engine, checkfirst=True)
    print("Migration successful! UserDirective table created if it didn't exist.")


if __name__ == "__main__":
    run_migration()
