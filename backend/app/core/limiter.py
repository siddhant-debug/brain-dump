"""
Rate limiter instance — imported by both main.py and routers.
Lives here to prevent circular imports (main -> routers -> main).
"""
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
