#!/usr/bin/env  python3 
from jutlandia_site import app, db
from os.path import exists

def main():
    db_path = app.config["SQLALCHEMY_DATABASE_URI"]
    db_path = db_path[10:]
    if exists(db_path):
        print("[DB]: Database exists")
    else:
        print("[DB]: Database doesn't exists")
        print("[DB]: Creating database")
        db.create_all()

    app.run(debug=True)

if __name__ == "__main__":
    main()
