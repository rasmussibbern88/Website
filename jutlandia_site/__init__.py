from flask import (
    Flask,
    render_template,
    session,
    request,
    redirect,
    url_for,
    Response,
)
from markupsafe import escape
from flask_sqlalchemy import SQLAlchemy

from functools import wraps
import logging
import requests as r

from pprint import pprint

from werkzeug.security import check_password_hash, generate_password_hash

from os import environ
from os.path import exists
from ics import Calendar, Event
from datetime import timedelta
import discord
import asyncio

app = Flask(__name__)

app.config["GUILD_ID"] = environ["DISCORD_GUILD_ID"]
app.config["CLIENT_ID"] = environ["DISCORD_CLIENT_ID"]
app.config["CLIENT_SECRET"] = environ["DISCORD_CLIENT_SECRET"]
app.config["INFRA_CLIENT_SECRET"] = environ["DISCORD_INFRA_CLIENT_SECRET"]
app.config["ADMIN_ROLE_ID"] = environ["DISCORD_ADMIN_ROLE_ID"]
app.config["REDIRECT_URI"] = environ["DISCORD_REDIRECT_URI"]
app.config["SQLALCHEMY_DATABASE_URI"] = environ["SQL_DB_URI"]
try:
    app.secret_key = environ["APP_SECRET_KEY"]
except KeyError as e:
    print("Caught KeyError, 'APP_SECRET_KEY' not set.\nUsing default")
    app.secret_key = "super Strong and Secret Key"


db = SQLAlchemy(app)


class ICSEvents:
    def __init__(self, calendar: Calendar):
        self.calendar = Calendar()

    @classmethod
    def new(cls):
        c = Calendar()
        return cls(c)

    def add_event(self, name, location, begin, url):
        event = Event()
        event.name = name
        event.location = location
        event.url = url
        event.begin = begin
        event.begin = event.begin.replace(tzinfo="Europe/Copenhagen")

        if len(str(begin)) < 12:
            event.duration = timedelta(hours=3)
        else:
            event.duration = timedelta(hours=10)
        print(event)
        self.calendar.events.add(event)
        return self

    def update_event(self, name):
        return self

    def remove_event(self, name):
        # calendar events is a set, so we have to iterate and find it so that it can be removed by the objech hash.
        for event in self.calendar.events:
            if event.name == name:
                self.calendar.events.remove(event)
                break
        return self

    def get_events(self, event):
        return self.calendar.events

    def ics(self) -> str:
        return self.calendar.serialize()

ics_events = ICSEvents.new()


class Events(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Text, nullable=True)
    link = db.Column(db.Text, nullable=True)
    date = db.Column(db.Text, nullable=True)
    location = db.Column(db.Text, nullable=True)
    over = db.Column(db.Boolean, nullable=True)

    def __init__(self, name, date, link, location, over=False):
        self.name = name
        self.link = link
        self.date = date
        self.location = location
        self.over = over

    def __repr__(self):
        return f"<Events: {self.name}>"


def session_filter(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        if "token" not in session:
            return redirect(url_for("oauth_get_token"))

        if "roles" not in session:
            get_discord_roles()

        admin_role = app.config["ADMIN_ROLE_ID"]
        if admin_role in session["roles"]:
            return func(*args, **kwargs)
        else:
            abort(401)

    return wrapper


@app.route("/", methods=["GET"])
def index():
    upcoming = Events.query.filter_by(over=False).all()
    finished = Events.query.filter_by(over=True).all()
    return render_template(
        "index.html", upcoming_events=upcoming, finished_events=finished
    )

@app.route("/kalender.ics", methods=["GET"])
def calendar():
    data: str = ics_events.ics()
    return Response(data)


def get_discord_roles():
    guild_id = app.config["GUILD_ID"]
    api_endpoint = f"/users/@me/guilds/{guild_id}/member"
    headers = {"Authorization": f"Bearer {session['token']}"}
    result = r.get(f"http://discord.com/api/{api_endpoint}", headers=headers)
    result = result.json()
    session["roles"] = result["roles"]


@app.route("/admin", methods=["GET"])
@session_filter
def admin():
    all_events = Events.query.order_by(Events.id).all()
    pprint(all_events)
    return render_template("admin.html", events=all_events)


@app.route("/admin/edit_event/<int:event_id>")
@session_filter
def admin_edit_event(event_id):
    event = Events.query.filter_by(id=event_id).first()
    return render_template("edit.html", event=event)


@app.route("/api/add_event", methods=["POST"])
@session_filter
def add_event():
    name = escape(request.form["name"])
    link = escape(request.form["link"])
    date = escape(request.form["date"])
    time = escape(request.form["time"])
    location = escape(request.form["location"])

    try:
        ics_events.add_event(name, location, f"{date} {time}", link)
    except Exception as error:
        print("error", error)

    event = Events(name, f"{date} {time}", link, location)
    db.session.add(event)
    db.session.commit()
    return redirect(url_for("admin"))


@app.route("/api/update_event", methods=["POST"])
@session_filter
def update_event():
    id = escape(request.form["id"])
    name = escape(request.form["name"])
    date = escape(request.form["date"])
    location = escape(request.form["location"])
    link = escape(request.form["link"])
    name = escape(request.form["name"])
    over = request.form.get("over", "")

    if not over:
        over = False
    else:
        over = True

    event = Events.query.filter_by(id=id).first()
    event.name = name
    event.date = date
    event.location = location
    event.link = link
    event.name = name
    event.over = over

    db.session.commit()
    return redirect(url_for("admin"))


@app.route("/api/delete_event", methods=["GET"])
@session_filter
def delete_event():
    id = escape(request.args.get("id", ""))
    if id:
        event = Events.query.filter_by(id=id).first()
        try:
            ics_events.remove_event(event.date)
        except Exception as error:
            print("error", error)
        db.session.delete(event)
        db.session.commit()
        return redirect(url_for("admin"))

    return redirect(url_for("admin"))


@app.route("/oauth")
def oauth_get_token():
    redirect_uri = app.config["REDIRECT_URI"]
    client_id = app.config["CLIENT_ID"]
    client_secret = app.config["CLIENT_SECRET"]
    code = request.args.get("code", "")

    if "token" in session:
        return redirect(url_for("admin"))

    if not code:
        return redirect(
            "https://discord.com/oauth2/authorize?client_id="
            + client_id
            + "&redirect_uri="
            + redirect_uri
            + "&response_type=code&scope=guilds.members.read"
        )
    else:
        code = request.args["code"]
        data = {
            "client_id": client_id,
            "client_secret": client_secret,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirect_uri,
        }
        headers = {"Content-Type": "application/x-www-form-urlencoded"}
        result = r.post(
            "https://discord.com/api/oauth2/token", data=data, headers=headers
        ).json()
        session["token"] = result["access_token"]
        return redirect(url_for("oauth_get_token"))


async def main():
    db_path = app.config["SQLALCHEMY_DATABASE_URI"]
    db_path = db_path[10:]
    print(db_path)
    if exists(db_path):
        print("[DB]: Database exists")
    else:
        print("[DB]: Database doesn't exists")
        print("[DB]: Creating database")
        with app.app_context():
            db.create_all()

    async def run_discord_client():
        # discord.Intents(guild_scheduled_events=True)
        intents = discord.Intents.none()
        intents.guild_scheduled_events = True
        # intents = discord.Intents.default()
        # intents.message_content = True

        client = MyClient(intents=intents)
        async with client:
            missing = discord.utils.MISSING
            discord.utils.setup_logging(
                handler=missing,
                formatter=missing,
                level=logging.DEBUG,
                root=True,
            )
            await client.start(
                app.config["INFRA_CLIENT_SECRET"],
                reconnect=True,
            )

    client = asyncio.create_task(run_discord_client())

    website = asyncio.to_thread(app.run)

    await asyncio.gather(client, website)


class MyClient(discord.Client):
    async def on_ready(self):
        print(f"Logged on as {self.user}!")

    async def on_scheduled_event_create(self, event: discord.ScheduledEvent):
        print(
            f"Scheduled event created: {event.name} at {event.start_time} to {event.end_time}"
        )
        self.add_event(event)

    async def on_scheduled_event_update(
        self, before: discord.ScheduledEvent, after: discord.ScheduledEvent
    ):
        print(f"Scheduled event updated: {before.name} to {after.name}")
        self.update_event(before, after)

    async def on_scheduled_event_delete(self, event: discord.ScheduledEvent):
        print(f"Scheduled event deleted: {event.name}")
        self.remove_event(event)

    def remove_event(self, event: discord.ScheduledEvent):
        print(f"Scheduled event removed: {event.name}")
        try:
            ics_events.remove_event(event.name)
            event = Events.query.filter_by(name=event.name).first()
            db.session.delete(event)
            db.session.commit()
        except Exception as error:
            print("error", error)

    def add_event(self, event: discord.ScheduledEvent):
        # TODO keep data datetime objects for calendar, and only convert to string for the database.
        print(f"Scheduled event added: {event.name}")
        name = event.name
        location = event.location if event.location else "Online"
        date = event.start_time.strftime("%Y-%m-%d")
        time = event.start_time.strftime("%H:%M")

        try:
            ics_events.add_event(name, location, f"{date} {time}", "")
            event = Events(name, f"{date} {time}", "", location)
            db.session.add(event)
            db.session.commit()
        except Exception as error:
            print("error", error)

    def update_event(
        self, before: discord.ScheduledEvent, after: discord.ScheduledEvent
    ):
        print(
            f"Scheduled event updated: {before.name}"
        )  # TODO combine with date, to avoid deleting all tirsdagshacking events
        location = after.location if after.location else "Online"
        date = after.start_time.strftime("%Y-%m-%d")
        time = after.start_time.strftime("%H:%M")
        try:
            ics_events.remove_event(before.name)
            ics_events.add_event(after.name, location, f"{date} {time}", "")
            event = Events.query.filter_by(name=before.name).first()
            db.session.delete(event)
            db.session.add(Events(after.name, f"{date} {time}", "", location))
            db.session.commit()
        except Exception as error:
            print("error", error)


# ics_events.add_event(name, location, f"{date} {time}", link)
# ics_events.remove_event(event.date)


if __name__ == "__main__":
    asyncio.run(main())
    # main()
