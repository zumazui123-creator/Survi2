import asyncio
import websockets


async def send_commands():
    async with websockets.connect("ws://localhost:8765") as ws:
        await ws.send("links")  # Send "links", "rechts", etc.
        response = await ws.recv()  # Wait for Godot's reply
        print("Godot replied:", response)

asyncio.get_event_loop().run_until_complete(send_commands())