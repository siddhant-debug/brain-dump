import sys
import os

# Add backend to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.models.models import BrainEmbedding
from app.services.rag_engine import _rag_service


def test_models():
    print("Testing BrainEmbedding model schema...")
    assert hasattr(BrainEmbedding, "user_id"), "BrainEmbedding should have user_id"
    print("BrainEmbedding user_id exists.")


def test_rag_service():
    print("Testing RAGService singleton...")
    assert _rag_service is not None, "RAGService should be initialized"
    assert hasattr(_rag_service, "bm25_store"), "RAGService should have bm25_store"
    print("RAGService singleton looks good.")


if __name__ == "__main__":
    test_models()
    test_rag_service()
    print("All structural offline tests passed!")
