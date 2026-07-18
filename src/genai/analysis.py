"""
Generative AI comparative analysis for ThriftyChef.

Compares traditional recommenders with generative approaches (VAE, GAN, LLM)
for food-waste recipe recommendation.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class GenAIApproach:
    name: str
    type: str
    role: str
    pros: list[str]
    cons: list[str]
    implemented: bool

    # Back-compat for older notebooks
    @property
    def fit_for_fridgewise(self) -> str:
        return self.role


def genai_comparison_table() -> list[GenAIApproach]:
    """Structured comparison of generative vs traditional approaches."""
    return [
        GenAIApproach(
            name="SVD (traditional CF)",
            type="Matrix factorisation",
            role="Core collaborative rating prediction",
            pros=["Interpretable latent factors", "Fast inference", "Proven on Food.com"],
            cons=["Cold-start for new users", "No ingredient awareness alone"],
            implemented=True,
        ),
        GenAIApproach(
            name="Mult-VAE",
            type="Variational autoencoder",
            role="Optional generative collaborative model (future)",
            pros=["Handles sparse data", "Can generate diverse lists", "Strong CF research baseline"],
            cons=["Heavy training cost", "Less interpretable", "Needs GPU for scale"],
            implemented=False,
        ),
        GenAIApproach(
            name="Recipe GAN",
            type="Generative adversarial network",
            role="Creative leftover combinations (discussion only)",
            pros=["Novel recipe text/ingredient combos", "Creative waste reduction ideas"],
            cons=["Hallucinated ingredients", "Allergen risk", "Hard to evaluate offline"],
            implemented=False,
        ),
        GenAIApproach(
            name="LLM explanations",
            type="Large language model",
            role="Natural-language explanations and substitutions (optional UX)",
            pros=["User-friendly explanations", "Substitution suggestions", "Adapts to context"],
            cons=["Nutrition misinformation risk", "Latency", "Needs validation against structured fields"],
            implemented=False,
        ),
        GenAIApproach(
            name="Template explanations (ThriftyChef)",
            type="Rule-based / structured",
            role="Default production explanations in the API",
            pros=["Reliable", "No hallucination", "Fast"],
            cons=["Less conversational", "Fixed phrasing"],
            implemented=True,
        ),
    ]


def recommend_genai_strategy() -> dict[str, str]:
    """Recommended GenAI posture for ThriftyChef."""
    return {
        "core": "Keep the traditional hybrid (content + SVD + rules) as the ranking engine.",
        "future_model": "Mult-VAE is a possible future comparison on the same evaluation split.",
        "llm_layer": "Optional LLM text may rewrite template explanations; always validate against structured fields.",
        "gan": "Discussion only — not recommended for allergen-sensitive food domains without human review.",
        "safety": "Hard filters (allergens, diet) must remain deterministic; generative layers augment UX only.",
    }


def sample_llm_prompt(recipe_name: str, match_pct: float, expiring: list[str]) -> str:
    """Example constrained prompt for an optional local LLM — not called by default."""
    exp = ", ".join(expiring[:3]) if expiring else "none"
    return (
        f"Explain in 2 sentences why '{recipe_name}' is recommended. "
        f"Fridge match: {match_pct:.0%}. Expiring items used: {exp}. "
        f"Do not invent ingredients or nutrition claims."
    )
