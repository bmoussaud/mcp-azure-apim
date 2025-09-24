from __future__ import annotations

import json
from typing import List, Optional, Sequence, Tuple


def render_artist_table(raw_payload: str, limit: int = 5) -> str:
    try:
        payload = json.loads(raw_payload)
    except json.JSONDecodeError:
        return raw_payload

    artists = payload.get("artist") or []
    rows = [
        (
            str(artist.get("name", "")).strip(),
            str(artist.get("url", "")).strip(),
        )
        for artist in artists
    ]

    rows = [(name, url) for name, url in rows if name or url]
    if not rows:
        return "(no artist entries returned)"

    if limit > 0:
        rows = rows[:limit]

    name_width = max(len("Name"), *(len(name) for name, _ in rows))
    url_width = max(len("URL"), *(len(url) for _, url in rows))

    header = f"| {'Name'.ljust(name_width)} | {'URL'.ljust(url_width)} |"
    separator = f"| {'-' * name_width} | {'-' * url_width} |"
    body = [
        f"| {name.ljust(name_width)} | {url.ljust(url_width)} |"
        for name, url in rows
    ]

    return "\n".join([header, separator, *body])


def render_setlist(raw_payload: str) -> str:
    try:
        payload = json.loads(raw_payload)
    except json.JSONDecodeError:
        return raw_payload

    setlists = payload.get("setlist") or []
    for setlist in setlists:
        raw_sets = setlist.get("sets", {}).get("set") or []
        structured_sets: List[Tuple[Optional[str], Sequence[str]]] = []

        for raw_set in raw_sets:
            songs = [
                str(song.get("name", "")).strip()
                for song in (raw_set.get("song") or [])
                if str(song.get("name", "")).strip()
            ]
            if songs:
                structured_sets.append((raw_set.get("name"), songs))

        if not structured_sets:
            continue

        event_date = setlist.get("eventDate") or "Unknown date"
        venue = setlist.get("venue", {}).get("name") or "Unknown venue"
        city = setlist.get("venue", {}).get("city", {}).get("name") or ""
        location = f"{venue} ({city})" if city else venue
        tour = setlist.get("tour", {}).get("name")
        url = setlist.get("url")

        lines = [f"🎤 {event_date} · {location}"]
        if tour:
            lines.append(f"Tour: {tour}")
        if url:
            lines.append(f"Link: {url}")

        for idx, (set_name, songs) in enumerate(structured_sets, start=1):
            title = set_name or ("Encore" if idx > 1 else "Set")
            lines.append("")
            lines.append(f"{title}:")
            for song_idx, song_name in enumerate(songs, start=1):
                lines.append(f"  {song_idx}. {song_name}")

        return "\n".join(lines)

    return "(no setlists with songs found)"
