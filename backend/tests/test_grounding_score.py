# backend/tests/test_grounding_score.py
"""
Eval for compute_grounding_score() / async_compute_grounding_score()
(backend/app/services/rag_engine.py) — the drift tripwire added to the RAG
chat stream (rag.py) but not exercised by any existing test.

Deliberately uses the REAL embedding model (BAAI/bge-base-en-v1.5, already
cached locally under ~/.cache/huggingface) rather than mocking it — the point
is to check the scoring function actually separates grounded from ungrounded
answers at the configured GROUNDING_WARN_THRESHOLD, not just that it calls
its dependencies correctly.
"""
import pytest

from app.services import rag_engine


@pytest.fixture(autouse=True)
def real_embedding_model():
    """
    Other tests in this suite monkeypatch rag_engine.SentenceTransformer and
    leave a MagicMock cached on the _rag_service singleton's _emb_model. Force
    a fresh real load here so this eval is measuring the actual model.
    """
    rag_engine._rag_service._emb_model = None
    yield
    rag_engine._rag_service._emb_model = None


def test_grounding_score_high_when_answer_paraphrases_context():
    """A generated answer that restates the retrieved context should score
    comfortably above the grounding threshold."""
    context = (
        "On March 3rd the user noted they went for a 5k run in the morning "
        "and felt energized afterwards, then had a smoothie for breakfast."
    )
    answer = (
        "You went for a 5k run in the morning on March 3rd and felt "
        "energized, then had a smoothie afterwards."
    )
    score = rag_engine.compute_grounding_score(answer, context)
    assert score >= rag_engine.GROUNDING_WARN_THRESHOLD, (
        f"Expected a paraphrased answer to be flagged grounded (score >= "
        f"{rag_engine.GROUNDING_WARN_THRESHOLD}), got {score:.3f}"
    )


def test_grounding_score_low_when_answer_ignores_context():
    """An answer that has nothing to do with the retrieved context (e.g. the
    model answered from general knowledge instead) should score below the
    threshold — this is the actual failure mode the tripwire exists to catch."""
    context = (
        "On March 3rd the user noted they went for a 5k run in the morning "
        "and felt energized afterwards, then had a smoothie for breakfast."
    )
    answer = (
        "The capital of France is Paris, and the Eiffel Tower was completed "
        "in 1889 for the World's Fair."
    )
    score = rag_engine.compute_grounding_score(answer, context)
    assert score < rag_engine.GROUNDING_WARN_THRESHOLD, (
        f"Expected an unrelated answer to be flagged ungrounded (score < "
        f"{rag_engine.GROUNDING_WARN_THRESHOLD}), got {score:.3f}"
    )


def test_grounding_score_empty_inputs_return_zero():
    assert rag_engine.compute_grounding_score("", "some context") == 0.0
    assert rag_engine.compute_grounding_score("some answer", "") == 0.0
    assert rag_engine.compute_grounding_score("", "") == 0.0


def test_async_grounding_score_matches_sync_result():
    import anyio

    context = "The user's resting heart rate this week averaged 58 bpm."
    answer = "Your resting heart rate averaged 58 bpm this week."

    sync_score = rag_engine.compute_grounding_score(answer, context)
    async_score = anyio.run(
        rag_engine.async_compute_grounding_score, answer, context
    )

    assert async_score == pytest.approx(sync_score, abs=1e-6)
