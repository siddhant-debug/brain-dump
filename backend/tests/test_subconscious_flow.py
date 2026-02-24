import sys
import unittest
from datetime import datetime
from unittest.mock import MagicMock, patch
import os

# Add parent directory to path to import modules
# calculated relative to this file: ../tests/test_subconscious_flow.py -> ../tests -> .. (backend)
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import functions to test
try:
    from app.services.rag_engine import (
        get_temporal_context,
        analyze_emotional_tone,
        get_tone_guidance,
        find_associative_memories,
        datetime as rag_datetime,  # import the one used in module if needed, or just patch string
    )
except ImportError as e:
    print(f"ImportError: {e}")
    # Fallback if running from root without package structure?
    # But usually app.services... requires backend/ in sys.path
    pass


class TestSubconsciousFlow(unittest.TestCase):

    def test_get_temporal_context_morning(self):
        """Test temporal context for morning hours"""
        # Create a real datetime object for the return value
        fixed_dt = datetime(2023, 10, 11, 9, 0, 0)  # Wednesday (weekday=2)

        class MockDt:
            @classmethod
            def now(cls):
                return fixed_dt

        # Patch 'app.services.rag_engine.datetime'
        with patch("app.services.rag_engine.datetime", MockDt):
            context = get_temporal_context(1)
            self.assertIn("Morning thoughts hit different", context)

    def test_get_temporal_context_night(self):
        """Test temporal context for late night hours"""
        fixed_dt = datetime(2023, 10, 11, 23, 0, 0)

        class MockDt:
            @classmethod
            def now(cls):
                return fixed_dt

        with patch("app.services.rag_engine.datetime", MockDt):
            context = get_temporal_context(1)
            self.assertIn("Late night", context)

    def test_get_temporal_context_sunday(self):
        """Test temporal context for Sunday"""
        fixed_dt = datetime(2023, 10, 15, 14, 0, 0)  # Sunday

        class MockDt:
            @classmethod
            def now(cls):
                return fixed_dt

        with patch("app.services.rag_engine.datetime", MockDt):
            context = get_temporal_context(1)
            self.assertIn("Sunday. Planning mode", context)

    def test_analyze_emotional_tone_positive(self):
        """Test positive emotion detection"""
        text = (
            "I am feeling great about this project! Optimization is working perfectly."
        )
        tone = analyze_emotional_tone(text)
        self.assertEqual(tone, "energized_optimistic")

    def test_analyze_emotional_tone_negative(self):
        """Test negative emotion detection"""
        text = "I am failing at this. Everything is broken and I'm stressed."
        tone = analyze_emotional_tone(text)
        self.assertEqual(tone, "reflective_concerned")

    def test_analyze_emotional_tone_neutral(self):
        """Test neutral emotion detection"""
        text = "The server is running on port 8000."
        tone = analyze_emotional_tone(text)
        self.assertEqual(tone, "contemplative_neutral")

    def test_get_tone_guidance(self):
        """Test tone guidance mapping"""
        guidance = get_tone_guidance("reflective_concerned")
        self.assertIn("Be gentle", guidance)

        guidance = get_tone_guidance("energized_optimistic")
        self.assertIn("Match the energy", guidance)

        guidance = get_tone_guidance("unknown_state")
        self.assertEqual(guidance, "Be authentic and direct.")

    @patch("app.services.rag_engine.get_emb_fn")
    def test_find_associative_memories(self, mock_get_emb_fn):
        """Test associative memory logic"""
        # Mock the embedding function and DB session
        mock_emb_model = MagicMock()
        mock_emb_result = MagicMock()
        mock_emb_result.tolist.return_value = [[0.1, 0.2, 0.3]]
        mock_emb_model.encode.return_value = mock_emb_result
        mock_get_emb_fn.return_value = mock_emb_model

        mock_db = MagicMock()
        mock_query = MagicMock()
        mock_filter = MagicMock()
        mock_order_by = MagicMock()
        mock_limit = MagicMock()

        mock_db.query.return_value = mock_query
        mock_query.filter.return_value = mock_filter
        mock_filter.order_by.return_value = mock_order_by
        mock_order_by.limit.return_value = mock_limit

        # Setup mock return value (2 items)
        mock_result1 = MagicMock()
        mock_result1.document = "Fitness is key"
        mock_result2 = MagicMock()
        mock_result2.document = "Running helps clear mind"

        mock_limit.all.return_value = [mock_result1, mock_result2]

        query = "I want to improve my health"
        user_id = 1
        primary_context = "Gym schedule is set."

        associations = find_associative_memories(
            query, user_id, primary_context, db=mock_db
        )

        # Should find associations based on 'health' keyword
        self.assertTrue(len(associations) > 0)
        # Should filter out duplicates if any (logic check)


if __name__ == "__main__":
    unittest.main()
