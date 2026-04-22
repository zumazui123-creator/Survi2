import asyncio
import websockets
import json

directions = ["links", "rechts", "hoch", "runter"]

async def handler(websocket):
    try:
        for i in range(3):


            action = "links"
            await websocket.send(json.dumps(action))
            print(f"Sent action: {action}")

            # Wait to receive a message from the client
            msg = await websocket.recv()
            try:
                data = json.loads(msg)
            except json.JSONDecodeError:
                data = msg  # fallback to raw msg if not JSON
            print(f"Received from client: {data}")

            websocket.close()

    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    async with websockets.serve(handler, "localhost", 8765):
        print("Server started on ws://localhost:8765")
        await asyncio.Future()  # Run forever

if __name__ == "__main__":
    asyncio.run(main())