"""
conftest.py — runs before every test in this directory.

Patches `importlib.util.find_spec` to silently return None when torch raises
`ValueError: torch.__spec__ is not set` on Python 3.13. This allows the
`transformers` library (imported via langchain + sentence_transformers) to
treat torch as unavailable and skip torch-specific code, rather than crashing
the entire test collection.
"""

import importlib.util

_real_find_spec = importlib.util.find_spec


def _safe_find_spec(name, package=None):
    try:
        return _real_find_spec(name, package=package)
    except (ValueError, AttributeError):
        # torch.__spec__ is not set on Python 3.13 with some torch builds
        return None


importlib.util.find_spec = _safe_find_spec
