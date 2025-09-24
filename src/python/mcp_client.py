import asyncio
import json
import os
from dotenv import load_dotenv
from fastmcp.client import Client
from fastmcp.client.transports import StreamableHttpTransport

load_dotenv()

SETLISTAPI_MCP_ENDPOINT = str(os.getenv("SETLISTAPI_MCP_ENDPOINT"))
SETLISTAPI_SUBSCRIPTION_KEY = str(os.getenv("SETLISTAPI_SUBSCRIPTION_KEY"))

# SETLISTAPI_MCP_ENDPOINT = "https://mcp-azure-apim-api-management-dev.azure-api.net/setlistfm-mcp/mcp"
print(f"🔗 Testing connection to {SETLISTAPI_MCP_ENDPOINT}...")


def _render_artist_table(raw_payload: str, limit: int = 5) -> str:
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


def _render_setlist(raw_payload: str) -> str:
    try:
        payload = json.loads(raw_payload)
    except json.JSONDecodeError:
        return raw_payload

    setlists = payload.get("setlist") or []
    for setlist in setlists:
        raw_sets = setlist.get("sets", {}).get("set") or []
        structured_sets = []

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


async def main():
    try:
        async with Client(transport=StreamableHttpTransport(
            SETLISTAPI_MCP_ENDPOINT,
            headers={"Ocp-Apim-Subscription-Key": SETLISTAPI_SUBSCRIPTION_KEY},
        ), ) as client:
            assert await client.ping()
            print("✅ Successfully authenticated!")

            tools = await client.list_tools()
            print(f"🔧 Available tools ({len(tools)}):")
            for tool in tools:
                print(f"   - {tool.name}")
                # print(f"     {tool.description}")
                print(f"     Input Schema: {tool.inputSchema}")

            print("-------" * 18)
            print("🔗 Search for artists with 'Coldplay' in the name")
            searchForArtists = await client.call_tool(
                "searchForArtists", arguments={'artistName': 'Coldplay'}
            )
            artist_payload = searchForArtists.content[0].text if searchForArtists.content else ""
            print(_render_artist_table(artist_payload))

            print("-------" * 18)
            print("🔗 Get a list of setlists for Blondshell")
            searchForSetlists = await client.call_tool(
                "searchForSetlists", arguments={'artistName': 'Wolf Alice', 'p': 1}
            )
            setlist_payload = searchForSetlists.content[0].text if searchForSetlists.content else ""
            print(_render_setlist(setlist_payload))
    except Exception as e:
        print(f"❌ failure : {e}")
        raise
    finally:
        print("👋 Closing client...")
        await client.close()


if __name__ == "__main__":
    asyncio.run(main())
