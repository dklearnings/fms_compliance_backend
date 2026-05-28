import logging

logging.basicConfig(
    filename="app.log",
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)

logger = logging.getLogger("fms-api")


def get_logger(name: str | None = None):
    """Return a logger. If `name` is provided, return a named logger."""
    if name:
        return logging.getLogger(name)
    return logger
