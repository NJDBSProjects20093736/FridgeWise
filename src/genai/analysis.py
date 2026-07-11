"""
Generative AI comparative analysis for FridgeWise (CA Part 3).

Compares traditional recommenders vs generative approaches (VAE, GAN, LLM)
in the context of food-waste recipe recommendation.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class GenAIApproach:
    name: str
    type: str
    fit_for_fridgewise: str
    pros: list[str]
    cons: list[str]
    implemented: bool


def genai_comparison_table() -> list[GenAIApproach]:
    """Structured comparison for report §12."""
    return [
        GenAIApproach(
            name="SVD (traditional CF)",
            type="Matrix factorisation",
            fit_for_fridgewise="Core System 2 — rating prediction",
            pros=["Interpretable latent factors", "Fast inference", "Proven on Food.com"],
            cons=["Cold-start for new users", "No ingredient awareness alone"],
            implemented=True,
        ),
        GenAIApproach(
            name="Mult-VAE",
            type="Variational autoencoder",
            fit_for_fridgewise="Extension — generative user preference model",
            pros=["Handles sparse data", "Can generate diverse lists", "Research-grade CF"],
            cons=["Heavy training cost", "Black-box", "Needs GPU for scale"],
            implemented=False,
        ),
        GenAIApproach(
            name="Recipe GAN",
            type="Generative adversarial network",
            fit_for_fridgewise="Creative leftover combinations (research only)",
            pros=["Novel recipe text/ingredient combos", "Creative waste reduction ideas"],
            cons=["Hallucinated ingredients", "Allergen risk", "Hard to evaluate offline"],
            implemented=False,
        ),
        GenAIApproach(
            name="LLM explanations (Ollama/GPT)",
            type="Large language model",
            fit_for_fridgewise="Natural-language 'why recommended' + substitutions",
            pros=["User-friendly explanations", "Substitution suggestions", "Adapts to context"],
            cons=["Nutrition misinformation risk", "Latency", "Needs validation against DB"],
            implemented=False,
        ),
        GenAIApproach(
            name="Template explanations (FridgeWise)",
            type="Rule-based / structured",
            fit_for_fridgewise="Production default in API",
            pros=["Reliable", "No hallucination", "Fast"],
            cons=["Less conversational", "Fixed phrasing"],
            implemented=True,
        ),
    ]


def recommend_genai_strategy() -> dict[str, str]:
    """Project recommendation for CA and beyond."""
    return {
        "core_ca": "Traditional hybrid (content + SVD + rules) meets all rubric requirements.",
        "extension": "Mult-VAE as optional notebook 05b — compare NDCG vs SVD on same split.",
        "llm_layer": "Optional Ollama wrapper rewrites template explanations; always validate against structured fields.",
        "gan": "Discuss only — not recommended for allergen-sensitive food domain without human review.",
        "responsible_ai": "Hard filters (allergens, diet) must remain non-generative; GenAI augments UX only.",
    }


def sample_llm_prompt(recipe_name: str, match_pct: float, expiring: list[str]) -> str:
    """Example prompt for optional local LLM (Ollama) — not called by default."""
    exp = ", ".join(expiring[:3]) if expiring else "none"
    return (
        f"Explain in 2 sentences why '{recipe_name}' is recommended. "
        f"Fridge match: {match_pct:.0%}. Expiring items used: {exp}. "
        f"Do not invent ingredients or nutrition claims."
    )
