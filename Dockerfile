FROM ubuntu:26.04@sha256:3595d7fc4286a33fad0fd853a4063e654287a9c3787437d7937c94ca3f7a804e

COPY --from=ghcr.io/astral-sh/uv:0.12.22@sha256:f513a91fc62fe7c17567eee97230dd198e43edb8a9fbecca843714a4358fe1bc /uv /uvx /bin/

WORKDIR /app/

ENV UV_FROZEN=1 UV_LINK_MODE=copy UV_COMPILE_BYTECODE=1 UV_NO_DEV=1 UV_PYTHON_INSTALL_DIR=/opt/python

RUN useradd --system --create-home app

COPY pyproject.toml uv.lock ./

RUN --mount=type=cache,target=/root/.cache/uv uv sync

ENV PATH=/app/.venv/bin:$PATH

COPY templates ./templates
COPY main.py ./

USER app
EXPOSE 8000
# The base image has no curl, but the venv's interpreter is already on PATH.
# Checks the key listing rather than /, which creates a keypair as a side effect.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:8000/meta/public_keys/token_scanning')"]
CMD ["uvicorn", "main:app", "--host=0.0.0.0"]
