FROM ubuntu:26.04@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b

COPY --from=ghcr.io/astral-sh/uv:0.12.10@sha256:2bb3ebca0a796a155094a27773d290c4b074572e6107f171d88d086682fd2500 /uv /uvx /bin/

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
