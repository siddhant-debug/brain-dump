import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models import models
from app.services import rag_engine

db = SessionLocal()
uid = 5
notes = db.query(models.Note).filter(models.Note.user_id == uid).all()

if not notes:
    print("No notes")
    sys.exit()

valid_notes = [n for n in notes if n.content and len(n.content.strip()) >= 40]
print(f"User 5 has {len(valid_notes)} valid notes over 40 chars.")

emb_model = rag_engine.get_emb_fn()
query_embeddings = emb_model.encode([n.content for n in valid_notes]).tolist()

from app.models.models import BrainEmbedding

for q_emb, query_note in zip(query_embeddings, valid_notes):
    db_results = (
        db.query(
            BrainEmbedding.id,
            BrainEmbedding.embedding.l2_distance(q_emb).label("distance"),
            BrainEmbedding.metadata_,
        )
        .filter(BrainEmbedding.metadata_.op("->>")("user_id") == str(uid))
        .order_by("distance")
        .limit(5)
        .all()
    )

    print(f"\nQuery: {query_note.content[:60]}...")
    for r in db_results:
        print(f"  - Dist {r.distance:.4f} | ID: {r.id}")
