#!/usr/bin/env python3
"""Writes made-up PowerView reports for the App Store screenshots.

Every number is simulated minute by minute from an invented daily routine, so the screenshots
show realistic, self-consistent data without anyone's real usage in them.

    python3 sample_report.py <output directory>

Writes `<id>.json` and `<id>.summary.json` for each report, the same files `ReportFiles` saves.
"""

import json
import math
import random
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

TZ_OFFSET = -7 * 3600  # Pacific Daylight Time
TZ = timezone(timedelta(seconds=TZ_OFFSET))
WH_PER_PERCENT = 0.1804  # 4,685 mAh at 3.85 V

# bundle ID: (name, %/h with the screen on, Wi-Fi MB per minute on screen, weight by part of day)
APPS = {
    "com.google.ios.youtube": ("YouTube", 15.5, 4.2, {"morning": 0.3, "day": 0.6, "evening": 3.2}),
    "com.burbn.instagram": ("Instagram", 14.0, 1.8, {"morning": 1.4, "day": 1.2, "evening": 1.6}),
    "com.apple.mobilesafari": ("Safari", 10.5, 0.6, {"morning": 1.2, "day": 1.6, "evening": 1.0}),
    "com.apple.MobileSMS": ("Messages", 8.5, 0.1, {"morning": 1.5, "day": 1.6, "evening": 1.4}),
    "net.whatsapp.WhatsApp": ("WhatsApp", 9.5, 0.2, {"morning": 0.9, "day": 1.0, "evening": 1.0}),
    "com.apple.mobilemail": ("Mail", 8.5, 0.2, {"morning": 1.6, "day": 1.1, "evening": 0.3}),
    "com.tinyspeck.chatlyio": ("Slack", 10.0, 0.2, {"morning": 0.6, "day": 1.8, "evening": 0.2}),
    "com.apple.Maps": ("Maps", 18.0, 0.3, {"morning": 0.1, "day": 0.3, "evening": 0.1}),
    "com.apple.mobileslideshow": ("Photos", 12.0, 0.2, {"morning": 0.2, "day": 0.3, "evening": 0.5}),
    "com.apple.camera": ("Camera", 21.0, 0.0, {"morning": 0.1, "day": 0.3, "evening": 0.2}),
    "com.apple.Music": ("Music", 8.0, 0.2, {"morning": 0.3, "day": 0.2, "evening": 0.2}),
    "com.apple.podcasts": ("Podcasts", 8.0, 0.2, {"morning": 0.2, "day": 0.1, "evening": 0.2}),
    "com.apple.weather": ("Weather", 9.0, 0.1, {"morning": 0.5, "day": 0.1, "evening": 0.1}),
}
LOCK_SCREEN = "com.apple.lock-screen"
HOME_SCREEN = "com.apple.springboard.home-screen"
SYSTEM_NAMES = {LOCK_SCREEN: "Lock Screen", HOME_SCREEN: "Home Screen"}

# Energy used with the screen off, shared out as background energy.
BACKGROUND_SHARES = [
    ("WiFi-Idle", "Wi-Fi Idle", 0.20),
    ("com.apple.springboard", "SpringBoard (Home/Lock)", 0.10),
    ("CPU", "System (unattributed CPU)", 0.11),
    ("BB-Standard", "Cellular (standby)", 0.08),
    ("apsd", "apsd (push)", 0.06),
    ("backboardd", "backboardd (input/display)", 0.05),
    ("com.apple.mobilemail", "Mail", 0.05),
    ("net.whatsapp.WhatsApp", "WhatsApp", 0.045),
    ("com.burbn.instagram", "Instagram", 0.04),
    ("com.apple.mobileslideshow", "Photos", 0.035),
    ("com.tinyspeck.chatlyio", "Slack", 0.035),
    ("mDNSResponder", "mDNSResponder (DNS)", 0.03),
    ("com.apple.MobileSMS", "Messages", 0.025),
    ("com.apple.geod", "geod (Maps data)", 0.02),
    ("com.apple.sharingd", "sharingd (AirDrop/Continuity)", 0.02),
    ("com.apple.weather", "Weather", 0.015),
]

NOTIFIERS = [
    ("com.tinyspeck.chatlyio", "Slack", 34, True),
    ("com.apple.MobileSMS", "Messages", 26, False),
    ("com.apple.mobilemail", "Mail", 24, False),
    ("net.whatsapp.WhatsApp", "WhatsApp", 21, False),
    ("com.burbn.instagram", "Instagram", 12, False),
    ("com.apple.mobilecal", "Calendar", 5, True),
    ("com.apple.news", "News", 6, False),
    ("com.apple.Fitness", "Fitness", 3, False),
    ("com.apple.weather", "Weather", 2, False),
    ("com.apple.reminders", "Reminders", 2, False),
    ("com.apple.Wallet", "Wallet", 2, False),
    ("com.apple.mobileslideshow", "Photos", 1, False),
]

DAEMONS = ["dasd", "suggestd", "photoanalysisd", "mediaanalysisd", "assetsd", "searchd", "spotlightknowledged", "cloudd"]
KILLABLE = [("Instagram", "com.burbn.instagram"), ("Safari", "com.apple.mobilesafari"), ("YouTube", "com.google.ios.youtube"),
            ("Maps", "com.apple.Maps"), ("Photos", "com.apple.mobileslideshow"), ("Mail", "com.apple.mobilemail")]


def part_of_day(minute):
    hour = minute / 60
    return "morning" if hour < 11 else "day" if hour < 18 else "evening"


def pick(rng, weights):
    total = sum(weights.values())
    roll = rng.uniform(0, total)
    for key, weight in weights.items():
        roll -= weight
        if roll <= 0:
            return key
    return key


def r1(value, digits=1):
    return round(value, digits)


class Day:
    """One simulated day, minute by minute."""

    def __init__(self, date, rng, start_level, plugged_at_start, special):
        self.date = date
        self.rng = rng
        self.special = special
        weekday = date.weekday() < 5
        self.weekday = weekday

        self.wake = int(rng.gauss(7 * 60 if weekday else 8 * 60 + 15, 15))
        self.bed = int(rng.gauss(23 * 60 + 5, 20))
        self.screen = [None] * 1440  # app on screen
        self.charging = [False] * 1440
        self.cellular = [False] * 1440  # away from Wi-Fi
        self.audio = [False] * 1440
        self.outdoors = [False] * 1440

        # Away from Wi-Fi: a commute on weekdays, an afternoon out at the weekend.
        if weekday:
            for start, length in ((8 * 60 + 15, 40), (18 * 60, 40)):
                start += rng.randint(-10, 10)
                for m in range(start, start + length):
                    self.cellular[m] = self.audio[m] = True
                    self.outdoors[m] = rng.random() < 0.4
        else:
            start = 13 * 60 + rng.randint(-30, 30)
            for m in range(start, start + rng.randint(150, 220)):
                self.cellular[m] = self.outdoors[m] = True
        if special.get("outing"):
            for m in range(12 * 60, 16 * 60 + 30):
                self.cellular[m] = self.outdoors[m] = True

        # Plugged in overnight, and sometimes topped up during the day.
        for m in range(0, self.wake if plugged_at_start else 0):
            self.charging[m] = True
        for m in range(self.bed, 1440):
            self.charging[m] = True
        if rng.random() < 0.3 or special.get("topUp"):
            start = rng.choice([12 * 60 + 40, 15 * 60, 19 * 60 + 30])
            for m in range(start, start + rng.randint(25, 50)):
                self.charging[m] = True

        self._place_sessions()
        self._simulate_battery(start_level)

    def _place_sessions(self):
        rng = self.rng
        target = rng.gauss(205 if self.weekday else 245, 25) * self.special.get("screenScale", 1)
        placed = 0
        attempts = 0
        while placed < target and attempts < 4000:
            attempts += 1
            start = rng.randint(self.wake, self.bed + 25)
            if start >= 1440:
                continue
            part = part_of_day(start)
            # Longer sessions in the evening, quick glances during the day.
            if rng.random() < 0.35:
                app, length = LOCK_SCREEN, rng.randint(1, 2)
            else:
                weights = {k: v[3][part] for k, v in APPS.items()}
                if self.cellular[start]:
                    weights["com.apple.Maps"] *= 6
                    weights["com.apple.Music"] *= 3
                    weights["com.apple.camera"] *= 4 if self.outdoors[start] else 1
                if self.weekday and 9 * 60 <= start <= 18 * 60:
                    weights["com.google.ios.youtube"] *= 0.3
                for key, factor in self.special.get("appBoost", {}).items():
                    weights[key] *= factor
                app = pick(rng, weights)
                mean = 34 if app == "com.google.ios.youtube" and part == "evening" else 6
                length = max(1, int(rng.lognormvariate(math.log(mean), 0.6)))
            end = min(1440, start + length)
            if any(self.screen[m] for m in range(max(0, start - 1), min(1440, end + 1))):
                continue
            for m in range(start, end):
                self.screen[m] = app
            # A moment on the Home Screen around app sessions.
            if app != LOCK_SCREEN and end < 1440 and not self.screen[end]:
                self.screen[end] = HOME_SCREEN
            placed += end - start

    def _simulate_battery(self, start_level):
        rng = self.rng
        level = start_level
        self.levels = []
        self.energy = [0.0] * 1440  # mWh used each minute
        self.aod = [False] * 1440
        self.photos_sync = [False] * 1440
        sync = self.special.get("photosSync")
        if sync:
            for m in range(sync[0], sync[1]):
                self.photos_sync[m] = True

        for m in range(1440):
            app = self.screen[m]
            awake = self.wake <= m < self.bed
            if app:
                rate = (APPS[app][1] if app in APPS else 7.0) * 0.85
                if self.outdoors[m]:
                    rate *= 1.25
            else:
                rate = 0.78 + (0.4 if self.cellular[m] else 0) + (0.25 if self.audio[m] else 0)
                if awake:
                    self.aod[m] = True
                    rate += 0.32
                if self.photos_sync[m]:
                    rate += 2.6
            rate *= rng.uniform(0.85, 1.15)
            self.energy[m] = rate / 60 * WH_PER_PERCENT * 1000

            if self.charging[m]:
                if level < 50:
                    level += 1.3
                elif level < 80:
                    level += 0.85
                elif level < 95:
                    level += 0.35
                else:
                    level += 0.12
                level = min(100.0, level)
            else:
                level = max(1.0, level - rate / 60)
            self.levels.append(level)

    # MARK: Outputs

    def battery(self, end_minute=1440):
        samples = []
        for m in range(0, end_minute, 5):
            jitter = min(end_minute - 1, m + self.rng.randint(0, 2))
            samples.append({"hour": r1(jitter / 60, 3), "level": int(round(self.levels[jitter])), "charging": self.charging[jitter]})
        return samples

    def charging_spans(self):
        spans, start = [], None
        for m in range(1440):
            if self.charging[m] and start is None:
                start = m
            elif not self.charging[m] and start is not None:
                spans.append((start, m))
                start = None
        if start is not None:
            spans.append((start, 1440))
        return spans


def build_day(sim, tier, end_minute, all_days, index, flagged):
    rng = sim.rng
    end = end_minute
    minutes = range(end)
    energy_mwh = sum(sim.energy[m] for m in minutes)
    screen_mwh = sum(sim.energy[m] for m in minutes if sim.screen[m])
    aod_mwh = sum(0.32 / 60 * WH_PER_PERCENT * 1000 for m in minutes if sim.aod[m])
    off_mwh = energy_mwh - screen_mwh - aod_mwh

    # Apps: on-screen energy from the simulation, background energy shared out by role.
    apps = {}
    for m in minutes:
        app = sim.screen[m]
        if app in APPS:
            entry = apps.setdefault(app, {"bundleID": app, "name": APPS[app][0], "total": 0, "screen": 0, "background": 0,
                                          "foregroundMinutes": 0, "backgroundMinutes": 0, "audioMinutes": 0})
            entry["screen"] += sim.energy[m] * 0.82
            entry["foregroundMinutes"] += 1
    sync_mwh = sum(2.6 / 60 * WH_PER_PERCENT * 1000 for m in minutes if sim.photos_sync[m])
    for bundle, name, share in BACKGROUND_SHARES:
        entry = apps.setdefault(bundle, {"bundleID": bundle, "name": name, "total": 0, "screen": 0, "background": 0,
                                         "foregroundMinutes": 0, "backgroundMinutes": 0, "audioMinutes": 0})
        entry["background"] += (off_mwh - sync_mwh) * share * rng.uniform(0.8, 1.2)
        if not bundle[0].isupper() and "." in bundle:
            entry["backgroundMinutes"] += int(share * 600 * rng.uniform(0.6, 1.4))
    apps["com.apple.mobileslideshow"]["background"] += sync_mwh
    apps["com.apple.mobileslideshow"]["backgroundMinutes"] += sum(1 for m in minutes if sim.photos_sync[m])
    music = apps.setdefault("com.apple.Music", {"bundleID": "com.apple.Music", "name": "Music", "total": 0, "screen": 0,
                                                "background": 0, "foregroundMinutes": 0, "backgroundMinutes": 0, "audioMinutes": 0})
    audio_minutes = sum(1 for m in minutes if sim.audio[m])
    music["audioMinutes"] = audio_minutes
    music["backgroundMinutes"] += audio_minutes
    music["background"] += audio_minutes * 0.25 / 60 * WH_PER_PERCENT * 1000
    apps["com.apple.lock-screen.aod"] = {"bundleID": "com.apple.lock-screen.aod", "name": "Always-On Display", "total": 0,
                                         "screen": aod_mwh, "background": 0, "foregroundMinutes": 0, "backgroundMinutes": 0,
                                         "audioMinutes": 0}
    for entry in apps.values():
        entry["screen"] = int(entry["screen"])
        entry["background"] = int(entry["background"])
        entry["total"] = entry["screen"] + entry["background"]
    app_list = sorted((a for a in apps.values() if a["total"] > 0), key=lambda a: -a["total"])
    app_list = app_list[:12 if tier == "daily" else 20]

    energy_wh = energy_mwh / 1000
    components = [
        ("Processor (CPU/GPU/NPU)", 0.37), ("Display", 0.24), ("Memory & Rest of Chip", 0.15),
        ("Wi-Fi", 0.11), ("Cellular Modem", 0.07), ("Other", 0.06),
    ]
    day = {
        "date": sim.date.strftime("%Y-%m-%d"),
        "battery": sim.battery(end),
        "tier": tier,
        "components": [{"name": n, "wh": r1(energy_wh * s * rng.uniform(0.9, 1.1), 2)} for n, s in components],
        "energyWh": r1(energy_wh, 2),
        "apps": app_list,
        "screenEnergyWh": r1((screen_mwh + aod_mwh) / 1000, 2),
        "aodEnergyWh": r1(aod_mwh / 1000, 2),
        "hasUsageTime": True,
        "hasKeepAlive": True,
        "partial": end < 1440,
    }
    if tier == "daily":
        return day

    # Hourly lanes
    def per_hour(fn):
        return [int(sum(fn(m) for m in range(h * 60, min(end, h * 60 + 60)))) for h in range(24)]

    day["hourly"] = {
        "screen": per_hour(lambda m: 60 if sim.screen[m] else 0),
        "plugged": per_hour(lambda m: 60 if sim.charging[m] else 0),
        "aod": per_hour(lambda m: 60 if sim.aod[m] else 0),
        "audio": per_hour(lambda m: 60 if sim.audio[m] else 0),
        "keepAliveCellular": per_hour(lambda m: 0.25 if sim.cellular[m] else 0.02),
        "keepAliveWiFi": per_hour(lambda m: 0 if sim.cellular[m] else 0.9),
        "systemCPU": per_hour(lambda m: sim.energy[m] * 0.12),
        "total": per_hour(lambda m: sim.energy[m]),
        "modem": per_hour(lambda m: sim.energy[m] * (0.25 if sim.cellular[m] else 0.03)),
        "wifi": per_hour(lambda m: sim.energy[m] * (0.02 if sim.cellular[m] else 0.12)),
        "display": per_hour(lambda m: sim.energy[m] * 0.45 if sim.screen[m] else (6 if sim.aod[m] else 0)),
    }

    # Notifications
    boost = sim.special.get("notificationScale", 1)
    by_hour = [0] * 24
    notes = []
    for bundle, name, mean, work in NOTIFIERS:
        scale = (1.0 if sim.weekday else 0.15) if work else 1.0
        count = max(0, int(rng.gauss(mean * scale * boost, mean * 0.2) * end / 1440))
        if bundle == "com.apple.MobileSMS":
            count = int(count * sim.special.get("messagesScale", 1))
        if count == 0:
            continue
        woke = 0
        for _ in range(count):
            m = rng.randint(min(sim.wake, end - 1), min(end, sim.bed) - 1) if rng.random() < 0.92 else rng.randint(0, end - 1)
            by_hour[m // 60] += 1
            if not sim.screen[m] and not sim.charging[m] and rng.random() < 0.55:
                woke += 1
        notes.append({"bundleID": bundle, "name": name, "count": count, "wokePhone": woke})
    day["notifications"] = sorted(notes, key=lambda n: -n["count"])
    day["notificationsByHour"] = by_hour

    if index >= len(all_days) - 8:
        day["temperature"] = temperature(sim, end)
        day["events"] = [{"hour": 0.0, "text": "Always-On Display on"}]
        for hour, text in sim.special.get("events", []):
            day["events"].append({"hour": hour, "text": text})
        day["aodAtStart"] = True

    if tier != "detailed":
        return day

    day["detail"] = detail(sim, end)
    day["screenApps"] = screen_apps(sim, end)
    day["brightness"] = brightness(sim, end)
    wake_hours = [0] * 24
    for h in range(24):
        if h * 60 < end:
            wake_hours[h] = max(0, int(rng.gauss(16 if 7 <= h <= 23 else 11, 4) * sim.special.get("wakeScale", 1)))
    total = sum(wake_hours)
    reasons = [("Wi-Fi", 0.36), ("Bluetooth", 0.27), ("Scheduled Timer", 0.15), ("Touch, Button or Raise", 0.12),
               ("Cellular", 0.07), ("Other", 0.03)]
    day["wakes"] = {"byHour": wake_hours, "reasons": [{"name": n, "count": int(total * s)} for n, s in reasons]}
    return day


def temperature(sim, end):
    rng = sim.rng
    bins = []
    temp = 29.0
    for b in range(end // 15):
        span = range(b * 15, b * 15 + 15)
        load = sum(sim.energy[m] for m in span) / 15
        target = 27.5 + load * 0.07 + (5.5 if any(sim.charging[m] for m in span) and sim.levels[b * 15] < 80 else 0)
        target += 4.5 if any(sim.outdoors[m] for m in span) else 0
        temp += (target - temp) * 0.45
        bins.append({"bin": b, "average": r1(temp + rng.uniform(-0.3, 0.3)), "maximum": r1(temp + rng.uniform(0.4, 1.6))})
    return {"bins": bins, "isSparse": False}


def detail(sim, end):
    rng = sim.rng
    screen, start = [], None
    for m in range(end):
        if sim.screen[m] and start is None:
            start = m
        elif not sim.screen[m] and start is not None:
            screen.append({"start": r1(start / 60, 3), "end": r1(m / 60, 3)})
            start = None
    if start is not None:
        screen.append({"start": r1(start / 60, 3), "end": r1(end / 60, 3)})

    radio, tech = [{"hour": 0.0, "technology": "5G"}], "5G"
    switch_rate = sim.special.get("radioSwitchRate", 0.05)
    for m in range(1, end):
        chance = switch_rate if sim.cellular[m] else 0.004
        if rng.random() < chance:
            tech = "4G" if tech == "5G" else "5G"
            radio.append({"hour": r1(m / 60, 3), "technology": tech})

    data, bars, app_data = [], [], {}
    for b in range(end // 15):
        wifi = cell = 0.0
        for m in range(b * 15, b * 15 + 15):
            app = sim.screen[m]
            per_minute = APPS[app][2] if app in APPS else 0.05
            if sim.photos_sync[m]:
                upload = 9.0 if not sim.cellular[m] else 0
                wifi += upload
                app_data["Photos"] = app_data.get("Photos", [0, 0])
                app_data["Photos"][0] += upload
            if sim.cellular[m]:
                used = per_minute * 0.35 + (0.9 if sim.audio[m] else 0)
                cell += used
            else:
                used = per_minute + 0.02
                wifi += used
            name = APPS[app][0] if app in APPS else ("Music" if sim.audio[m] else None)
            if name:
                entry = app_data.setdefault(name, [0, 0])
                entry[1 if sim.cellular[m] else 0] += used
        data.append({"bin": b, "wifiMB": r1(wifi, 2), "cellularMB": r1(cell, 3)})
        away = any(sim.cellular[m] for m in range(b * 15, b * 15 + 15))
        bars.append({"bin": b, "bars": r1(rng.uniform(2.2, 4.2) if away else rng.uniform(3.8, 5.0))})
    data_apps = sorted(({"name": n, "wifiMB": r1(v[0]), "cellularMB": r1(v[1], 2)} for n, v in app_data.items()),
                       key=lambda a: -(a["wifiMB"] + a["cellularMB"]))[:8]
    return {"screen": screen, "radio": radio, "data": data, "bars": bars, "dataApps": data_apps}


def screen_apps(sim, end):
    segments, start, current = [], None, None
    for m in range(end + 1):
        app = sim.screen[m] if m < end else None
        if app != current:
            if current is not None:
                segments.append({"start": r1(start / 60, 4), "end": r1(m / 60, 4), "appID": current})
            start, current = m, app
    minutes = {}
    for segment in segments:
        minutes[segment["appID"]] = minutes.get(segment["appID"], 0) + (segment["end"] - segment["start"]) * 60
    totals = [{"appID": k, "name": APPS[k][0] if k in APPS else SYSTEM_NAMES[k], "minutes": r1(v)}
              for k, v in sorted(minutes.items(), key=lambda kv: -kv[1])]
    return {"segments": segments, "totals": totals}


def brightness(sim, end):
    rng = sim.rng
    bins = []
    for b in range(end // 15):
        on = [m for m in range(b * 15, b * 15 + 15) if sim.screen[m]]
        if not on:
            continue
        hour = b / 4
        outdoors = any(sim.outdoors[m] for m in on)
        if outdoors:
            lux = rng.uniform(3000, 18000)
            nits = rng.uniform(700, 1100)
        elif 8 <= hour < 18:
            lux = rng.uniform(180, 600)
            nits = rng.uniform(160, 320)
        elif hour >= 21 or hour < 6:
            lux = rng.uniform(4, 40)
            nits = rng.uniform(18, 60)
        else:
            lux = rng.uniform(60, 220)
            nits = rng.uniform(80, 170)
        bins.append({"bin": b, "nits": int(nits), "maxNits": int(nits * rng.uniform(1.05, 1.4)), "lux": int(lux)})
    return bins


def epoch(date, minute):
    local = datetime(date.year, date.month, date.day, tzinfo=TZ) + timedelta(minutes=minute)
    return local.timestamp()


def make_report(report_id, last_date, day_count, capture_minute, device, product, build, imported_at, seed, specials):
    rng = random.Random(seed)
    dates = [last_date - timedelta(days=day_count - 1 - i) for i in range(day_count)]
    sims, level, plugged = [], 100.0, True
    for date in dates:
        special = specials.get(date.strftime("%Y-%m-%d"), {})
        sim = Day(date, random.Random(rng.random()), level, plugged, special)
        sims.append(sim)
        level, plugged = sim.levels[-1], sim.charging[-1]

    days, flagged = [], []
    for index, sim in enumerate(sims):
        tier = "daily" if index < day_count - 16 else "hourly" if index < day_count - 4 else "detailed"
        end = capture_minute if index == day_count - 1 else 1440
        days.append(build_day(sim, tier, end, sims, index, flagged))

    # Charging sessions, joining spans that cross midnight.
    sessions = []
    for index, sim in enumerate(sims):
        last = index == day_count - 1
        for start, stop in sim.charging_spans():
            if last and start >= capture_minute:
                continue
            stop = min(stop, capture_minute) if last else stop
            start_epoch, stop_epoch = epoch(sim.date, start), epoch(sim.date, stop)
            at_full = sum(1 for m in range(start, stop) if sim.levels[m] >= 99.5)
            if sessions and start == 0 and abs(sessions[-1]["end"] - start_epoch) < 1:
                sessions[-1]["end"] = stop_epoch
                sessions[-1]["endLevel"] = int(round(sim.levels[stop - 1]))
                sessions[-1]["minutesAtFull"] += at_full
                continue
            sessions.append({"start": start_epoch, "end": stop_epoch, "startLevel": int(round(sim.levels[max(0, start - 1)])),
                             "endLevel": int(round(sim.levels[stop - 1])), "minutesAtFull": at_full,
                             "_index": index, "_wireless": start > 20 * 60 or start == 0})
    for session in sessions:
        index, wireless = session.pop("_index"), session.pop("_wireless")
        if index >= day_count - 5:
            session["isWireless"] = wireless
            session["watts"] = 15 if wireless else rng.choice([20, 27])

    # Diagnostic reports.
    stability = []
    for index, sim in enumerate(sims):
        end = capture_minute if index == day_count - 1 else 1440
        for _ in range(rng.randint(2, 5)):
            stability.append({"date": epoch(sim.date, rng.randint(0, end - 1)), "kind": "memoryLimit", "process": rng.choice(DAEMONS),
                              "detail": "Reached its memory warning level while active"})
        for _ in range(rng.randint(1, 3)):
            name, bundle = rng.choice(KILLABLE)
            stability.append({"date": epoch(sim.date, rng.randint(sim.wake, min(end, sim.bed) - 1)), "kind": "memoryKill",
                              "process": name, "bundleID": bundle, "detail": "Closed because memory was under heavy pressure"})
        for event in sim.special.get("stability", []):
            stability.append({"date": epoch(sim.date, event["minute"]), **{k: v for k, v in event.items() if k != "minute"}})
    stability.sort(key=lambda e: -e["date"])

    capture_epoch = epoch(dates[-1], capture_minute)
    report = {
        "id": report_id,
        "importedAt": imported_at,
        "sourceName": f"sysdiagnose_{dates[-1]:%Y.%m.%d}_{capture_minute // 60:02d}-{capture_minute % 60:02d}-12-0700_iPhone-OS_iPhone_{build}.tar.gz",
        "meta": {
            "captured": capture_epoch, "deviceName": device, "productType": product, "build": build,
            "timeZoneOffset": TZ_OFFSET, "whPerPercent": WH_PER_PERCENT,
            "battery": {"cycleCount": 214, "designCapacity": 4685, "maximumCapacity": 4401},
        },
        "days": days,
        "charging": sessions,
        "stability": stability,
    }
    summary = {
        "id": report_id, "importedAt": imported_at, "sourceName": report["sourceName"], "deviceName": device,
        "build": build, "captured": capture_epoch, "dayCount": len(days), "firstDay": days[0]["date"], "lastDay": days[-1]["date"],
    }
    return report, summary


def main():
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "Sample")
    out.mkdir(parents=True, exist_ok=True)

    # The day the report opens on: a busy Thursday with a big Photos upload, a long YouTube evening,
    # an afternoon out in the sun and lots of 5G/4G switching.
    featured = {
        "2026-10-01": {
            "photosSync": (9 * 60 + 30, 15 * 60),
            "appBoost": {"com.google.ios.youtube": 1.8, "com.apple.camera": 2.0},
            "screenScale": 1.15,
            "outing": True,
            "messagesScale": 2.2,
            "notificationScale": 1.3,
            "wakeScale": 1.6,
            "radioSwitchRate": 0.16,
            "events": [(17.4, "Low Power Mode on"), (23.2, "Low Power Mode off")],
            "stability": [
                {"minute": 11 * 60 + 42, "kind": "cpuLimit", "process": "Photos", "bundleID": "com.apple.mobileslideshow",
                 "detail": "96 seconds cpu time over 104 seconds (92% cpu average), exceeding limit of 50% cpu over 180 seconds"},
                {"minute": 20 * 60 + 13, "kind": "crash", "process": "Maps", "bundleID": "com.apple.Maps",
                 "detail": "Stopped by the watchdog for not responding"},
            ],
        },
        "2026-09-26": {"stability": [{"minute": 14 * 60 + 5, "kind": "accessoryCrash", "process": "Audio Accessory"}]},
        "2026-09-22": {"stability": [{"minute": 9 * 60 + 51, "kind": "hang", "process": "SpringBoard", "bundleID": "com.apple.springboard",
                                      "detail": "Blown CA Fence Hang, 1.12s"}]},
        "2026-09-18": {"stability": [{"minute": 16 * 60 + 2, "kind": "crash", "process": "Instagram", "bundleID": "com.burbn.instagram",
                                      "detail": "EXC_BAD_ACCESS (SIGSEGV)"}]},
        "2026-09-30": {"events": [(21.5, "Low Power Mode on"), (23.4, "Low Power Mode off")], "topUp": True},
    }

    reports = [
        make_report("4E0F7C2A-1B3D-4C5E-9F60-7A8B9C0D1E2F", datetime(2026, 10, 2), 32, 9 * 60 + 30,
                    "iPhone 17 Pro", "iPhone18,1", "24A335", epoch(datetime(2026, 10, 2), 9 * 60 + 41), 17, featured),
        make_report("6A1B2C3D-4E5F-4061-8273-94A5B6C7D8E9", datetime(2026, 9, 12), 30, 21 * 60 + 5,
                    "iPhone 17 Pro", "iPhone18,1", "24A5355d", epoch(datetime(2026, 9, 12), 21 * 60 + 12), 5, {}),
        make_report("8C9D0E1F-2A3B-4C4D-8E5F-6A7B8C9D0E1F", datetime(2026, 8, 20), 28, 18 * 60 + 47,
                    "iPhone 16 Pro", "iPhone17,1", "23G80", epoch(datetime(2026, 8, 20), 18 * 60 + 55), 9, {}),
    ]
    for report, summary in reports:
        (out / f"{report['id']}.json").write_text(json.dumps(report))
        (out / f"{report['id']}.summary.json").write_text(json.dumps(summary))
        print(f"wrote {report['id']} ({summary['deviceName']}, {summary['firstDay']} to {summary['lastDay']})")


if __name__ == "__main__":
    main()
