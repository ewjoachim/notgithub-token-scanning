import base64
import hashlib
import json
import os

import httpx
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.hashes import SHA256
from fastapi import FastAPI, Form, Request, responses
from fastapi.templating import Jinja2Templates

app = FastAPI()

templates = Jinja2Templates(directory="templates")

keys: list = []
latest_response = None
errors: list = []


def create_keypair():
    private_key = ec.generate_private_key(ec.SECP256R1(), backend=default_backend())
    public_key = private_key.public_key()
    pem_public_key = public_key.public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()
    is_current = not any(k["is_current"] for k in keys)
    keys.append(
        {
            "id": hashlib.sha256(f"{id(private_key)}".encode()).hexdigest(),
            "private_key": private_key,
            "public_key": pem_public_key,
            "is_current": is_current,
        }
    )


def sign(key, payload: list):
    return base64.b64encode(
        key["private_key"].sign(
            json.dumps(payload).encode("utf-8"),
            signature_algorithm=ec.ECDSA(algorithm=SHA256()),
        )
    ).decode()


async def disclose(url, payload):
    key = next(iter(k for k in keys if k["is_current"]))
    signature = sign(key=key, payload=payload)

    try:
        async with httpx.AsyncClient() as client:
            r = await client.post(
                url,
                headers={
                    "GITHUB-PUBLIC-KEY-IDENTIFIER": key["id"],
                    "GITHUB-PUBLIC-KEY-SIGNATURE": signature,
                },
                json=payload,
            )
    except httpx.TransportError as exc:
        return {"status_code": "-", "text": str(exc)}
    return {"status_code": r.status_code, "text": r.text}


@app.get("/", response_class=responses.HTMLResponse)
async def home_view(request: Request):
    context: dict = {}
    global latest_response
    if latest_response:
        context["response"] = latest_response
        latest_response = None
    if errors:
        context["errors"] = errors[:]
        print(context["errors"])
        errors.clear()

    context["default_url"] = os.environ.get(
        "NOTGITHUB_DEFAULT_URL", "http://somewhere/_/github/disclose"
    )

    return templates.TemplateResponse(
        "home.html.j2", {"request": request, "keys": keys, **context}
    )


@app.post("/disclose")
async def disclose_view(url: str = Form(""), payload: str = Form("")):
    global latest_response, errors
    if not url:
        errors.append("url")
    if not payload:
        errors.append("payload")

    if not errors and keys:
        latest_response = await disclose(url=url, payload=payload)

    return responses.RedirectResponse("/", status_code=302)


@app.post("/add-key")
async def add_key_view():
    create_keypair()
    return responses.RedirectResponse("/", status_code=302)


@app.post("/edit-key/{i}")
async def edit_key_view(
    i: int,
    action: str = Form(...),
):
    redir = responses.RedirectResponse("/", status_code=302)
    if not 0 <= i < len(keys):
        return redir
    if action == "up" and i != 0:
        keys.insert(i - 1, keys.pop(i))
    if action == "down" and i != len(keys) - 1:
        keys.insert(i + 1, keys.pop(i))
    if action == "delete":
        k = keys.pop(i)
        if keys and k["is_current"]:
            keys[0]["is_current"] = True
    if action == "current":
        for j, k in enumerate(keys):
            k["is_current"] = i == j
    return redir


@app.get("/meta/public_keys/token_scanning")
def meta_list_keys():
    return {
        "public_keys": [
            {
                "key_identifier": key["id"],
                "key": key["public_key"],
                "is_current": key["is_current"],
            }
            for key in keys
        ]
    }
