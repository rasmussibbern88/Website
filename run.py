from app import app, db
from os.path import exists


if __name__ == "__main__":
    db_path = app.config["SQLALCHEMY_DATABASE_URI"]
    db_path = db_path[10:]
    if exists(db_path):
        print("[DB]: Database exists")
    else:
        print("[DB]: Database doesn't exists")
        print("[DB]: Creating database")
        db.create_all()

    app.run()
