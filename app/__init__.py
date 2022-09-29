from flask import (
    Flask,
    render_template,
    session,
    request,
    redirect,
    url_for
)
from flask_sqlalchemy import SQLAlchemy

from werkzeug.security import check_password_hash, generate_password_hash

from os import environ



app = Flask(__name__)

try:
    app.secret_key = environ['APP_SECRET_KEY']
except KeyError as e:
    print("Caught KeyError, 'APP_SECRET_KEY' not set.\nUsing default")
    app.secret_key = "super Strong and Secret Key"

app.config["SQLALCHEMY_DATABASE_URI"] = "sqlite:///jutlandia.db"
db = SQLAlchemy(app)

class Admins(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.Text, unique=True, nullable=False)
    password = db.Column(db.Text, nullable=False)

    def __init__(self, user, password):
        self.user = user
        self.password = password

class Events(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name     = db.Column(db.Text, nullable=True)
    link     = db.Column(db.Text, nullable=True)
    date     = db.Column(db.Text, nullable=True)
    location = db.Column(db.Text, nullable=True)
    over     = db.Column(db.Boolean, nullable=True)

    def __init__(self, name, date, link, location, over=False):
        self.name     = name
        self.link     = link
        self.date     = date
        self.location = location
        self.over     = over
    

@app.route("/", methods=["GET"])
def index():
    db.session.add(Event("AAA","BBBB","LLLL","ASDF", True))
    db.session.add(Event("ewijjli","BsdfBBB","LLLL","ASDF", True))
    db.session.add(Event("AAA","BBBB","LLLL","AsdklfjSDF"))
    db.session.add(Event("AAA","BBBB","LksldjfLLL","ASDF"))
    db.session.commit()

    upcoming = Event.query.filter_by(over=False).all()
    finished = Event.query.filter_by(over=True).all()
    return render_template("index.html",
                           upcoming_events=upcoming,
                           finished_events=finished)

@app.route("/admin", methods=["GET"])
def admin():
   if "username" in session:
       return render_template(
           "admin.html",
       )

   return redirect(url_for('login'))

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        user = request.form["username"]
        passwd = request.form["password"]

        result = Admins.query.filter_by(user=user).first()
        if result is None:
            return "Wrong username or password"
        elif check_password_hash(result.password, passwd):
            session["username"] = user
            return redirect(url_for('admin'))
        else:
            return "Wrong username or password"

    if request.method == "GET":
        if "username" not in session:
            return render_template("login.html")
        else:
            return redirect(url_for('admin'))
