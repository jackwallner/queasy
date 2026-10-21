package com.jackwallner.queasy.content

import com.jackwallner.queasy.model.ReliefMode

data class LearnSource(val title: String, val url: String)

data class LearnCard(
    val id: String,
    /** The mode this topic explains, for its icon; null for the non-mode topics. */
    val mode: ReliefMode?,
    val title: String,
    val hook: String,
    val detail: String,
    val sources: List<LearnSource> = emptyList(),
)

/**
 * The Learn tab, from `LearnView.swift`. The copy is the iOS copy except the
 * wearing card, which on Android is about holding the phone, since there is
 * no watch to turn around.
 */
object LearnContent {
    val cards: List<LearnCard> = listOf(
        LearnCard(
            id = "pulse",
            mode = ReliefMode.PULSE,
            title = "Pulse, and what it is not",
            hook = "A steady tap to rest your attention on.",
            detail = "Pulse taps on a regular, unhurried beat. That is the whole of it. Nudge the level until the tap is clear but not annoying, and let it be the thing you notice instead of your stomach, the way you might count breaths or stare at the horizon.\n\nWorth being straight about: a phone tapping your wrist is not acupressure and not nerve stimulation. Those are different things, done by bands that press or by cleared devices that deliver current, and no trial has tested a phone's vibration in their place. Pulse is here because a predictable sensation is easy to focus on, not because it does something to you.",
        ),
        LearnCard(
            id = "breathe",
            mode = ReliefMode.BREATHE,
            title = "Breathe",
            hook = "Out for longer than in, paced by a tap you feel.",
            detail = "Your phone taps a long swell in, then a longer fade out, so you can keep your eyes shut and follow it. Queasy suggests three seconds in and five out when things are mild, and four in and eight out when they are not. Breathing out for longer than you breathe in is the whole technique.\n\nSmall trials of slow diaphragmatic breathing during chemotherapy and after surgery have reported lower nausea scores. They are small, and the reviewers say so.",
            sources = listOf(
                LearnSource("Breathing interventions for nausea (2026 trial)", "https://pubmed.ncbi.nlm.nih.gov/41811802/"),
                LearnSource("Diaphragmatic breathing during chemotherapy", "https://www.sciencedirect.com/science/article/abs/pii/S1462388924000462"),
            ),
        ),
        LearnCard(
            id = "tone",
            mode = ReliefMode.TONE,
            title = "The 100 Hz tone",
            hook = "One minute, headphones, low volume.",
            detail = "In 2025 a Nagoya University group published a paper whose title says it plainly: \"Just 1-min exposure to a pure tone at 100 Hz with daily exposable sound pressure levels may improve motion sickness\". They measured posture, heart rhythm and questionnaire scores after a minute of a 100 Hz tone at everyday volume.\n\nQueasy generates that tone. May improve is the authors' own wording, and it is worth keeping. Headphones, volume low enough that it sits under the noise around you.",
            sources = listOf(
                LearnSource("Nagoya University: a unique sound alleviates motion sickness", "https://en.nagoya-u.ac.jp/news/articles/research_information_267/"),
                LearnSource("Environmental Health and Preventive Medicine (DOI)", "https://doi.org/10.1265/ehpm.24-00247"),
            ),
        ),
        LearnCard(
            id = "press",
            mode = ReliefMode.PRESS,
            title = "Press, and the P6 spot",
            hook = "The spot an acupressure band sits on.",
            detail = "Nei-Kuan, or P6, sits on the inside of the forearm about three finger-widths below the wrist crease, in the dip between the two tendons. It is where the stud of an acupressure band lands, and where the trials put their pressure.\n\nPress does not press for you. It shows you the spot, then times a three-minute hold while you use your thumb or line up a band you already own. The wristband trials spaced their holds through the day rather than doing one long one.\n\nThe evidence is genuinely mixed. Some trials in pregnancy and after surgery report lower nausea scores; the Cochrane review of early-pregnancy trials calls the P6 evidence limited and inconsistent. Both of those things are true at once.",
            sources = listOf(
                LearnSource("Cochrane: nausea and vomiting in early pregnancy", "https://www.cochranelibrary.com/cdsr/doi/10.1002/14651858.CD007575.pub4/full"),
                LearnSource("Cochrane: PC6 wrist stimulation evidence", "https://www.cochrane.org/evidence/CD003281_what-are-benefits-and-risks-different-wrist-pc6-acupoint-stimulation-techniques-preventing-nausea"),
                LearnSource("Memorial Sloan Kettering: locating P6", "https://www.mskcc.org/cancer-care/patient-education/acupressure-nausea-and-vomiting"),
            ),
        ),
        LearnCard(
            id = "hold",
            mode = null,
            title = "How to hold your phone",
            hook = "Against the inside of your wrist, or resting on you.",
            detail = "For Pulse, hold the phone so its back rests on the inside of your wrist, three finger-widths below the crease, or rest your wrist on it on a table. You only need to feel each tap clearly. The screen stays on while a session runs.\n\nBreathe does not care where the phone is. Rest it on your chest or in your lap and shut your eyes.",
        ),
        LearnCard(
            id = "morning",
            mode = null,
            title = "Morning sickness",
            hook = "What tends to help, and when to call someone.",
            detail = "It is rarely only mornings, and an empty stomach is the usual trigger, so small and often beats three meals. Plain crackers before you sit up, cold food rather than hot because it carries less smell, fluids between meals rather than with them. Acupressure bands are one of the drug-free things people try; so is vitamin B6, which your midwife or doctor can advise on.\n\nCall your midwife or doctor if you cannot keep fluids down for a day, if you are losing weight, if you feel faint, or if you are passing very dark urine. Severe pregnancy sickness has a name, hyperemesis gravidarum, and it has treatment. An app is not it.",
            sources = listOf(
                LearnSource("NHS: vomiting and morning sickness", "https://www.nhs.uk/pregnancy/related-conditions/common-symptoms/vomiting-and-morning-sickness/"),
                LearnSource("ACOG: morning sickness", "https://www.acog.org/womens-health/faqs/morning-sickness-nausea-and-vomiting-of-pregnancy"),
            ),
        ),
    )

    const val DISCLAIMER =
        "Queasy is a set of drug-free comfort techniques you run yourself. It is not a medical device and holds no clearance. It does not diagnose, treat, cure or prevent anything, and it may not change how you feel. Acupressure bands and electrical wristbands sold for nausea are cleared medical devices; Queasy is not one of them and is not a substitute for one. If nausea is severe, persistent, comes with other symptoms, or you cannot keep fluids down, see a doctor."
}

/** External links, from `PaywallLinks` and `AppStoreReviewLinks`, with Play in place of the App Store. */
object Links {
    const val PRIVACY = "https://jackwallner.github.io/queasy/privacy-policy.html"
    const val TERMS = "https://jackwallner.github.io/queasy/terms.html"
    const val SUPPORT_EMAIL = "jackwallner+q@gmail.com"
    const val PLAY_LISTING = "https://play.google.com/store/apps/details?id=com.jackwallner.queasy"

    fun manageSubscription(productId: String?): String =
        if (productId == null) "https://play.google.com/store/account/subscriptions"
        else "https://play.google.com/store/account/subscriptions?sku=${productId.substringBefore(":")}&package=com.jackwallner.queasy"
}
