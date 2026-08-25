# 12 — Source Library

**Research snapshot:** 24 August 2026  
**Citation convention:** documents refer to entries as `[S###]`.  
**Scope note:** this is a curated evidence library for product design, not a formal systematic-review bibliography. Links were selected for primary papers, official guidance, standards, regulators, platform documentation and official product descriptions.

## How to interpret this library

- A source may support a direction without proving a precise timer dose.
- Acute biomarker findings do not establish long-term disease prevention.
- Professional and occupational guidance supports practical design choices but may not be based on randomized disease-outcome trials.
- Competitor sources describe product features only; they do not validate health claims.
- Platform and regulatory sources should be checked again immediately before implementation or launch.

## Accessibility

### [S080] Apple Developer. Human Interface Guidelines—Accessibility.

- **Year/status:** Current
- **Evidence/source type:** Platform design guidance
- **Link:** https://developer.apple.com/design/human-interface-guidelines/accessibility
- **Product use and limitation:** Interfaces should remain usable with assistive technologies and accessibility settings.

## Accessibility / flashing

### [S045] W3C. Web Content Accessibility Guidelines (WCAG) 2.2.

- **Year/status:** 2023
- **Evidence/source type:** Accessibility standard
- **Link:** https://www.w3.org/TR/WCAG22/
- **Product use and limitation:** Avoid flashing, provide pause and stop controls, respect reduced motion, and support perceivable and operable alternatives.

## Accessibility / motion

### [S046] Apple Developer. Accessibility and Reduce Motion guidance.

- **Year/status:** Current
- **Evidence/source type:** Platform accessibility guidance
- **Link:** https://developer.apple.com/accessibility/
- **Product use and limitation:** Honor system accessibility settings and build keyboard, VoiceOver, contrast, text-size and reduced-motion support from the start.

## Active microbreaks

### [S009] Radwan A, et al. The effectiveness of active microbreaks in improving occupational health and work performance: a systematic review. Cogent Engineering. 2022. doi:10.1080/23311916.2022.2026206.

- **Year/status:** 2022
- **Evidence/source type:** Systematic review
- **Link:** https://doi.org/10.1080/23311916.2022.2026206
- **Product use and limitation:** Potential benefits were reported, but the controlled evidence base was small and heterogeneous.

## Active workstation performance

### [S035] Podrekar N, et al. The effects of cycle and treadmill desks on work performance and cognitive function: a meta-analysis. Work. 2020. PMID:32116273.

- **Year/status:** 2020
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/32116273/
- **Product use and limitation:** Active workstations can affect work performance, often through motor and typing demands rather than broad cognitive impairment.

### [S036] Medina-Inojosa JR, et al. Effect of Active Workstations on Neurocognitive Performance and Typing Capabilities: A Randomized Clinical Trial. 2024. PMCID:PMC11262529.

- **Year/status:** 2024
- **Evidence/source type:** Randomized crossover study
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC11262529/
- **Product use and limitation:** Active workstations may be feasible for some tasks, but device type and task demands matter.

## Apple health integration

### [S066] Apple Developer. HealthKit.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/healthkit
- **Product use and limitation:** HealthKit is centered on iPhone and Apple Watch and requires user permission; any Mac integration should use a companion app.

### [S067] Apple Developer. HKHealthStore.isHealthDataAvailable().

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/healthkit/hkhealthstore/ishealthdataavailable()
- **Product use and limitation:** On macOS the framework may be present but apps cannot read or write HealthKit data; do not architect direct Mac HealthKit access.

## Blink reminders

### [S017] Ashwini DL, et al. Evaluation of a blink-reminder software in digital device users. 2021. PMCID:PMC8597488.

- **Year/status:** 2021
- **Evidence/source type:** Small software intervention study
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC8597488/
- **Product use and limitation:** Software cues may increase blink behaviour and improve subjective symptoms, but the evidence is limited and does not validate constant high-frequency nudging.

## Blue light / eye health

### [S021] American Academy of Ophthalmology. Digital Devices and Your Eyes.

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/tips-prevention/digital-devices-your-eyes
- **Product use and limitation:** Current consumer digital-device blue light has not been shown to cause eye disease; discomfort should not be marketed as retinal damage.

### [S022] American Academy of Ophthalmology. Should You Be Worried About Blue Light?

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/tips-prevention/should-you-be-worried-about-blue-light
- **Product use and limitation:** Do not use blue-light fear as the product health rationale.

## Blue-light filtering

### [S018] Downie LE, et al. Blue-light filtering spectacle lenses for visual performance, sleep, and macular health in adults. Cochrane Database Syst Rev. 2023. PMID:37593770.

- **Year/status:** 2023
- **Evidence/source type:** Cochrane systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/37593770/
- **Product use and limitation:** Blue-light filtering lenses probably provide little or no short-term benefit for eye strain; evidence for sleep and retinal outcomes is uncertain.

## Breathing / stress

### [S039] Fincham GW, et al. Effect of breathwork on stress and mental health: A meta-analysis of randomised-controlled trials. Sci Rep. 2023. PMID:36624160.

- **Year/status:** 2023
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/36624160/
- **Product use and limitation:** Breathwork showed modest self-reported benefits, with heterogeneity and bias concerns. Use as an optional calming exercise, not treatment.

## Competitor

### [S073] LookAway. Smart Break Reminder App for Mac.

- **Year/status:** Current
- **Evidence/source type:** Official product documentation
- **Link:** https://lookaway.com/
- **Product use and limitation:** Strong product patterns include heads-up notices, snooze, idle awareness, app and context suppression, planned breaks, Focus integration and native Mac design.

### [S074] Dejal. Time Out—Break Reminders.

- **Year/status:** Current
- **Evidence/source type:** Official product documentation
- **Link:** https://www.dejal.com/timeout/
- **Product use and limitation:** Mature flexible model with micro and normal breaks, natural-break handling and user customization.

### [S075] Hovancik J. Stretchly—The break time reminder app.

- **Year/status:** Current
- **Evidence/source type:** Official open-source repository
- **Link:** https://github.com/hovancik/stretchly
- **Product use and limitation:** Cross-platform open-source patterns include idle awareness, do-not-disturb suppression, postpone or skip, and configurable schedules.

### [S076] BreakTimer. Break reminder app.

- **Year/status:** Current
- **Evidence/source type:** Official product documentation
- **Link:** https://breaktimer.app/
- **Product use and limitation:** Simple customizable schedules, working hours, heads-up notifications and custom messages.

## Digital eye strain

### [S012] Sheppard AL, Wolffsohn JS. Digital eye strain: prevalence, measurement and amelioration. BMJ Open Ophthalmol. 2018;3:e000146. doi:10.1136/bmjophth-2018-000146. PMID:29963645.

- **Year/status:** 2018
- **Evidence/source type:** Narrative review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/29963645/
- **Product use and limitation:** Digital eye strain is multifactorial; viewing behaviour, dry-eye mechanisms, refractive correction, environment and ergonomics all matter.

### [S013] Kaur K, et al. Digital Eye Strain—A Comprehensive Review. Ophthalmol Ther. 2022. PMCID:PMC9434525.

- **Year/status:** 2022
- **Evidence/source type:** Review
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC9434525/
- **Product use and limitation:** Supports a multi-factor model and cautious use of break, viewing, blink and workstation advice.

### [S020] American Academy of Ophthalmology. Computers, Digital Devices, and Eye Strain.

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/tips-prevention/computer-usage
- **Product use and limitation:** Practical comfort guidance: breaks, appropriate viewing, glare and brightness management, and evaluation of persistent symptoms.

## Digital eye strain interventions

### [S019] Mataftsi A, et al. Digital eye strain interventions: systematic review. 2023. PMID:36977430.

- **Year/status:** 2023
- **Evidence/source type:** Systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/36977430/
- **Product use and limitation:** Blue filters were not clearly effective; ergonomic and exposure-management measures are more defensible, though evidence quality varies.

## Dry eye / screens

### [S015] Al-Mohtaseb Z, et al. The Relationship Between Dry Eye Disease and Digital Screen Use. Clin Ophthalmol. 2021. PMID:34531649.

- **Year/status:** 2021
- **Evidence/source type:** Review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/34531649/
- **Product use and limitation:** Reduced or incomplete blinking and ocular-surface exposure are plausible contributors to screen-related dry-eye symptoms.

### [S016] Pucker AD, et al. Digital Screen Use and Dry Eye: Updated Perspectives. 2024. PMCID:PMC11416787.

- **Year/status:** 2024
- **Evidence/source type:** Review
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC11416787/
- **Product use and limitation:** The screen–dry-eye relationship is real but heterogeneous; product advice should avoid implying one universal mechanism or cure.

## Emergency symptoms

### [S050] American Heart Association. Warning Signs of a Heart Attack.

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.heart.org/en/health-topics/heart-attack/warning-signs-of-a-heart-attack
- **Product use and limitation:** Movement content must instruct users to stop and seek urgent help for chest discomfort, severe unusual shortness of breath, fainting or similar acute symptoms.

## Ergonomics

### [S023] Hoe VCW, et al. Ergonomic interventions for preventing work-related musculoskeletal disorders of the upper limb and neck among office workers. Cochrane Database Syst Rev. 2018. PMID:30350850.

- **Year/status:** 2018
- **Evidence/source type:** Cochrane systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/30350850/
- **Product use and limitation:** Evidence for many office ergonomic interventions is low or unclear; arm support or alternative mouse and supplementary breaks may help in some contexts, but broad prevention claims are not justified.

## Exercise / neck pain

### [S025] Louw S, et al. Effectiveness of exercise in office workers with neck pain: A systematic review and meta-analysis. S Afr J Physiother. 2017. PMID:30135909.

- **Year/status:** 2017
- **Evidence/source type:** Systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/30135909/
- **Product use and limitation:** Strengthening may reduce pain in symptomatic office workers, but this does not make generic exercise reminders preventive treatment.

### [S027] Jones LB, et al. The influence of exercise on pain, disability and quality of life in office workers with chronic neck pain: a systematic review and meta-analysis. Appl Ergon. 2024. PMID:38219373.

- **Year/status:** 2024
- **Evidence/source type:** Updated systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/38219373/
- **Product use and limitation:** Recent evidence remains heterogeneous and certainty is limited; avoid treatment claims in a general wellness app.

## Eye red flags

### [S052] American Academy of Ophthalmology. What Are Floaters and Flashes?

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/diseases/what-are-floaters-flashes
- **Product use and limitation:** Sudden new or increased floaters or flashes can indicate retinal tear or detachment and require prompt eye assessment.

### [S053] NHS. Detached retina (retinal detachment).

- **Year/status:** Current
- **Evidence/source type:** Public-health clinical guidance
- **Link:** https://www.nhs.uk/conditions/detached-retina-retinal-detachment/
- **Product use and limitation:** A dark curtain or shadow, sudden blur, flashes or a sudden increase in floaters requires urgent eye care.

### [S078] American Academy of Ophthalmology. Eye Symptoms.

- **Year/status:** Current
- **Evidence/source type:** Professional medical guidance
- **Link:** https://www.aao.org/eye-health/symptoms-list
- **Product use and limitation:** Sudden vision changes or loss and eye pain can require emergency attention.

## Hearing safety

### [S049] World Health Organization and International Telecommunication Union. Global standard for safe listening devices and systems.

- **Year/status:** 2019
- **Evidence/source type:** International technical standard and guidance
- **Link:** https://www.who.int/publications/i/item/9789241515276
- **Product use and limitation:** Safe-listening features require exposure information; a desktop app should not infer acoustic dose from an arbitrary volume percentage.

## Hydration

### [S047] National Academies. Dietary Reference Intakes for Water, Potassium, Sodium, Chloride, and Sulfate.

- **Year/status:** 2005
- **Evidence/source type:** National dietary reference report
- **Link:** https://nap.nationalacademies.org/catalog/10925/dietary-reference-intakes-for-water-potassium-sodium-chloride-and-sulfate
- **Product use and limitation:** Water needs vary and healthy adults usually regulate intake through thirst and food and fluid sources; arbitrary desktop quotas are not research-backed personalization.

## Hydration safety

### [S048] Mayo Clinic. Hyponatremia—Symptoms and causes.

- **Year/status:** Current
- **Evidence/source type:** Clinical consumer guidance
- **Link:** https://www.mayoclinic.org/diseases-conditions/hyponatremia/symptoms-causes/syc-20373711
- **Product use and limitation:** Excessive water intake can be harmful; hydration reminders should be user-defined and off by default.

## Keyboard ergonomics

### [S031] US Occupational Safety and Health Administration. Computer Workstations: Keyboards.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations/components/keyboards
- **Product use and limitation:** Keep input devices close enough for relaxed shoulders and elbows and relatively neutral wrists.

## Microbreaks / fatigue

### [S008] Albulescu P, et al. Give me a break! A systematic review and meta-analysis on the efficacy of micro-breaks for increasing well-being and performance. PLoS One. 2022;17:e0272460. doi:10.1371/journal.pone.0272460.

- **Year/status:** 2022
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0272460
- **Product use and limitation:** Microbreaks showed small benefits for vigor and fatigue; the pooled performance effect was not significant overall and depended on task and break features.

## Migraine / photosensitivity

### [S044] American Migraine Foundation. Photophobia, light sensitivity and screens.

- **Year/status:** Current
- **Evidence/source type:** Patient guidance from a specialist nonprofit
- **Link:** https://americanmigrainefoundation.org/resource-library/photophobia/
- **Product use and limitation:** Bright or flickering light can exacerbate symptoms for some people; provide a dim, static, reduced-motion break mode.

## Monitor ergonomics

### [S030] US Occupational Safety and Health Administration. Computer Workstations: Monitors.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations/components/monitors
- **Product use and limitation:** Monitor placement should reduce awkward neck positions and glare; guidance is a starting point, not a personalized prescription.

## Mouse ergonomics

### [S032] US Occupational Safety and Health Administration. Computer Workstations: Pointer/Mouse.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations/components/pointer-mouse
- **Product use and limitation:** Reduce reaching and support a comfortable, relatively neutral wrist and forearm position.

## Movement / sedentary behaviour

### [S001] World Health Organization. WHO guidelines on physical activity and sedentary behaviour. 2020.

- **Year/status:** 2020
- **Evidence/source type:** International guideline
- **Link:** https://www.who.int/publications/i/item/9789240015128
- **Product use and limitation:** Adults should limit sedentary time and replace it with physical activity of any intensity; the guideline does not prescribe a universal break interval.

### [S002] US Centers for Disease Control and Prevention. Adult Activity: An Overview.

- **Year/status:** Current
- **Evidence/source type:** Government guideline summary
- **Link:** https://www.cdc.gov/physical-activity-basics/guidelines/adults.html
- **Product use and limitation:** Move more and sit less; some activity is better than none. Break reminders do not replace weekly aerobic and strengthening recommendations.

### [S003] Gale JT, Martin H, Haszard JJ, Peddie MC. The Acute Effects of Interrupting Prolonged Sitting With Regular Activity Breaks on Postprandial Glucose and Insulin in Adults. Obesity Reviews. 2026. doi:10.1111/obr.70152. PMID:42070794.

- **Year/status:** 2026
- **Evidence/source type:** Systematic review and meta-analysis of acute randomized crossover studies
- **Link:** https://pubmed.ncbi.nlm.nih.gov/42070794/
- **Product use and limitation:** Activity breaks produced small-to-moderate acute reductions in post-meal glucose and insulin; walking breaks generally performed best. These are acute laboratory outcomes, not proof of long-term disease prevention.

### [S004] Duran AT, et al. Breaking Up Prolonged Sitting to Improve Cardiometabolic Risk: Dose-Response Analysis of a Randomized Crossover Trial. Med Sci Sports Exerc. 2023;55(5):847-855. doi:10.1249/MSS.0000000000003109. PMID:36728338.

- **Year/status:** 2023
- **Evidence/source type:** Small randomized crossover dose-response trial
- **Link:** https://pubmed.ncbi.nlm.nih.gov/36728338/
- **Product use and limitation:** In 11 middle- and older-age adults, five minutes of light walking every 30 minutes was the only tested dose that significantly attenuated the glucose outcome; all tested doses affected systolic blood pressure. Acute, very small study.

### [S005] Loh R, et al. Effects of Interrupting Prolonged Sitting with Physical Activity Breaks on Blood Glucose, Insulin and Triacylglycerol Measures: A Systematic Review and Meta-analysis. Sports Med. 2020. PMID:31552570.

- **Year/status:** 2020
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/31552570/
- **Product use and limitation:** Breaking prolonged sitting with activity can attenuate acute postprandial metabolic responses; effects vary by population and protocol.

### [S006] Diaz KM, et al. Evaluating movement breaks as a public health strategy to mitigate the harms of prolonged sitting: a large-scale pragmatic intervention. Br J Sports Med. 2026;60:1208-1217. doi:10.1136/bjsports-2025-111221.

- **Year/status:** 2026
- **Evidence/source type:** Large pragmatic, self-selected, short-duration intervention
- **Link:** https://bjsm.bmj.com/content/60/16/1208
- **Product use and limitation:** Five-minute walking breaks every 30, 60, or 120 minutes were tested for two weeks in real life. Every 30 minutes showed stronger self-reported psychosocial change; hourly breaks offered the best feasibility/effectiveness balance. Self-selected arms, self-reported outcomes, brief follow-up.

## Neurologic / spinal red flags

### [S051] NHS and NICE. Cauda equina syndrome and emergency back-pain red flags.

- **Year/status:** Current
- **Evidence/source type:** Public-health clinical guidance
- **Link:** https://www.nice.org.uk/guidance/ng59
- **Product use and limitation:** New bladder or bowel dysfunction, saddle numbness or acute leg weakness warrants urgent assessment; the app must not normalize these as ordinary desk discomfort.

## Posture

### [S024] Slater D, et al. Sit Up Straight: Time to Re-evaluate. J Orthop Sports Phys Ther. 2019. PMID:31366294.

- **Year/status:** 2019
- **Evidence/source type:** Clinical perspective / evidence synthesis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/31366294/
- **Product use and limitation:** No single ideal posture has been established as a universal pain-prevention target; comfort, task fit and variation are better product concepts.

## Privacy / California

### [S063] California Privacy Protection Agency. CCPA regulations and sensitive personal information.

- **Year/status:** Current
- **Evidence/source type:** Privacy law guidance
- **Link:** https://cppa.ca.gov/regulations/
- **Product use and limitation:** Health and biometric information can be sensitive personal information; avoid collecting it unless necessary and explicitly controlled.

## Privacy / Canada

### [S059] Office of the Privacy Commissioner of Canada. Guidelines for obtaining meaningful consent.

- **Year/status:** Current
- **Evidence/source type:** Privacy regulator guidance
- **Link:** https://www.priv.gc.ca/en/privacy-topics/collecting-personal-information/consent/gl_omc_201805/
- **Product use and limitation:** Consent must be understandable and tied to meaningful choices; optional health and context integrations need separate purpose explanations.

### [S060] Office of the Privacy Commissioner of Canada. PIPEDA fair information principles.

- **Year/status:** Current
- **Evidence/source type:** Privacy law and regulator guidance
- **Link:** https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/p_principle/
- **Product use and limitation:** Limit collection, use, disclosure and retention; protect data with appropriate safeguards.

## Privacy / EU

### [S062] European Data Protection Board. Guidelines on data protection by design and by default.

- **Year/status:** Current
- **Evidence/source type:** Privacy regulator guidance
- **Link:** https://www.edpb.europa.eu/our-work-tools/our-documents/guidelines/guidelines-42019-article-25-data-protection-design-and_en
- **Product use and limitation:** Build minimization, local processing, purpose limitation and privacy-protective defaults into architecture rather than adding them later.

## Privacy / UK-EU

### [S061] UK Information Commissioner’s Office. Special category data.

- **Year/status:** Current
- **Evidence/source type:** Privacy regulator guidance
- **Link:** https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/lawful-basis/special-category-data/
- **Product use and limitation:** Health data is specially protected; symptom logs and inferred health status require heightened justification and controls.

## Prompting / sitting

### [S010] Leppe-Zamora M, et al. Prompt-based interventions to reduce sedentary behaviour: systematic review and meta-analysis. 2025. PMID:40514667.

- **Year/status:** 2025
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/40514667/
- **Product use and limitation:** Digital prompts can reduce sitting, but evidence for durability and downstream health outcomes remains limited.

## Regulatory / Canada

### [S055] Health Canada. Guidance Document: Software as a Medical Device (SaMD): Definition and Classification.

- **Year/status:** Current
- **Evidence/source type:** Regulatory guidance
- **Link:** https://www.canada.ca/en/health-canada/services/drugs-health-products/medical-devices/application-information/guidance-documents/software-medical-device-guidance-document.html
- **Product use and limitation:** Software is SaMD when intended for a medical purpose and performing that purpose independently of hardware; intended use and labelling are central.

## Regulatory / EU

### [S056] European Commission MDCG 2019-11 rev.1. Guidance on Qualification and Classification of Software under MDR/IVDR. June 2025.

- **Year/status:** 2025
- **Evidence/source type:** Regulatory guidance
- **Link:** https://health.ec.europa.eu/latest-updates/update-mdcg-2019-11-rev1-qualification-and-classification-software-regulation-eu-2017745-and-2025-06-17_en
- **Product use and limitation:** Qualification and classification depend on intended purpose and the nature of information or action provided.

## Regulatory / UK

### [S057] UK Medicines and Healthcare products Regulatory Agency. Medical devices: software applications.

- **Year/status:** Current
- **Evidence/source type:** Regulatory guidance
- **Link:** https://www.gov.uk/government/publications/medical-devices-software-applications-apps
- **Product use and limitation:** Explains when an app is a medical device; claims and intended purpose must be controlled.

### [S058] UK Medicines and Healthcare products Regulatory Agency. Borderlines with medical devices and other products in Great Britain. Updated June 29, 2026.

- **Year/status:** 2026
- **Evidence/source type:** Regulatory guidance
- **Link:** https://www.gov.uk/government/publications/borderlines-with-medical-devices/borderlines-with-medical-devices-and-other-products-in-great-britain
- **Product use and limitation:** Wellness and medical boundaries are claim- and function-sensitive; obtain legal and regulatory review before expanding intended purpose.

## Regulatory / US

### [S054] US Food and Drug Administration. General Wellness: Policy for Low Risk Devices. Final guidance, January 6, 2026.

- **Year/status:** 2026
- **Evidence/source type:** Regulatory guidance
- **Link:** https://www.fda.gov/regulatory-information/search-fda-guidance-documents/general-wellness-policy-low-risk-devices
- **Product use and limitation:** Healthy-lifestyle functions unrelated to diagnosis, cure, mitigation, prevention or treatment of disease can remain in general-wellness territory when low risk; intended use and claims matter.

## Screens and sleep

### [S041] National Sleep Foundation. The impact of screen use on sleep health across the lifespan: 2024 consensus statement. PMID:38806392.

- **Year/status:** 2024
- **Evidence/source type:** Expert consensus statement
- **Link:** https://pubmed.ncbi.nlm.nih.gov/38806392/
- **Product use and limitation:** For adults, evidence is nuanced and consensus is weaker than for children and adolescents; avoid a universal screen curfew presented as clinical fact.

### [S042] Zhong C, et al. Electronic Screen Use and Sleep Duration and Timing in Adults. JAMA Netw Open. 2025. PMID:40146105.

- **Year/status:** 2025
- **Evidence/source type:** Large cross-sectional observational study
- **Link:** https://pubmed.ncbi.nlm.nih.gov/40146105/
- **Product use and limitation:** Pre-bed screen use was associated with shorter or worse self-reported sleep; cross-sectional design does not establish causality.

### [S043] Consensus recommendations for screen use and sleep health. 2025. PMID:40701900.

- **Year/status:** 2025
- **Evidence/source type:** Consensus and practical guidance
- **Link:** https://pubmed.ncbi.nlm.nih.gov/40701900/
- **Product use and limitation:** An optional wind-down tool can focus on bedtime displacement, stimulation and comfort rather than promising that a filter fixes sleep.

## Sit-stand workstations

### [S011] Shrestha N, et al. Workplace interventions for reducing sitting at work. Cochrane Database Syst Rev. 2018. PMID:29926475.

- **Year/status:** 2018
- **Evidence/source type:** Cochrane systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/29926475/
- **Product use and limitation:** Sit-stand desks reduce workplace sitting in the short and medium term, but long-term and health-outcome evidence was low quality or uncertain.

### [S033] Canadian Centre for Occupational Health and Safety. Working in a Standing Position / Sit-Stand Workstations.

- **Year/status:** Current
- **Evidence/source type:** Canadian occupational-health guidance
- **Link:** https://www.ccohs.ca/oshanswers/ergonomics/standing/standing_basic.html
- **Product use and limitation:** Recommendations vary; gradual adaptation and position alternation matter more than a rigid ratio.

## Slow breathing

### [S040] Slow breathing and psychophysiological outcomes: review of mechanisms and evidence. 2023. PMCID:PMC10741869.

- **Year/status:** 2023
- **Evidence/source type:** Review
- **Link:** https://pmc.ncbi.nlm.nih.gov/articles/PMC10741869/
- **Product use and limitation:** Supports gentle paced breathing as optional; avoid forceful hyperventilation or long breath holds.

## Standing and treadmill desks

### [S034] MacEwen BT, MacDonald DJ, Burr JF. A systematic review of standing and treadmill desks in the workplace. Prev Med. 2015. PMID:25448843.

- **Year/status:** 2015
- **Evidence/source type:** Systematic review
- **Link:** https://pubmed.ncbi.nlm.nih.gov/25448843/
- **Product use and limitation:** Evidence for health and well-being outcomes was mixed; productivity effects were generally small but research quality varied.

## Treadmill desk performance

### [S037] Larson MJ, et al. Cognitive and typing outcomes measured simultaneously with slow treadmill walking or sitting. PLoS One. 2015. PMID:25874910.

- **Year/status:** 2015
- **Evidence/source type:** Randomized study
- **Link:** https://pubmed.ncbi.nlm.nih.gov/25874910/
- **Product use and limitation:** Slow walking produced modest decrements in typing and some cognitive measures in this study; the app should not recommend treadmill use for every task.

## Treadmill desks

### [S038] Treadmill-desk workplace interventions: systematic review and meta-analysis. BMC Public Health. 2021. doi:10.1186/s12889-021-12094-9.

- **Year/status:** 2021
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://doi.org/10.1186/s12889-021-12094-9
- **Product use and limitation:** Treadmill desks increase energy expenditure and reduce sitting, but evidence for durable physiological outcomes is not established.

## Visual breaks

### [S014] Talens-Estarelles C, et al. The effects of breaks on digital eye strain, dry eye and binocular vision: Testing the 20-20-20 rule. Cont Lens Anterior Eye. 2023;46:101744. doi:10.1016/j.clae.2022.101744. PMID:35963776.

- **Year/status:** 2023
- **Evidence/source type:** Small prospective intervention study
- **Link:** https://pubmed.ncbi.nlm.nih.gov/35963776/
- **Product use and limitation:** Reminder-supported 20-20-20 behaviour improved symptoms while reminders were used in a small symptomatic sample, but objective dry-eye signs did not change and effects were not maintained after reminders stopped.

## Work breaks

### [S007] Cochrane. Different types of work-break schedules for preventing musculoskeletal symptoms and disorders in healthy workers. Updated 2025. doi:10.1002/14651858.CD012886.pub3.

- **Year/status:** 2025
- **Evidence/source type:** Cochrane systematic review
- **Link:** https://doi.org/10.1002/14651858.CD012886.pub3
- **Product use and limitation:** Available trials were small and very uncertain; no optimal break frequency or type can be declared.

## Workplace neck-pain interventions

### [S026] Chen X, et al. Workplace-Based Interventions for Neck Pain in Office Workers: Systematic Review and Meta-Analysis. Phys Ther. 2018;98(1):40-62. PMID:29088401.

- **Year/status:** 2018
- **Evidence/source type:** Systematic review and meta-analysis
- **Link:** https://pubmed.ncbi.nlm.nih.gov/29088401/
- **Product use and limitation:** Neck and shoulder-specific strengthening helped symptomatic workers in some trials but did not show general-population prevention; evidence for work breaks was inconsistent.

## Worksite prompting

### [S077] Swartz AM, et al. Prompts to Disrupt Sitting Time and Increase Physical Activity at Work. Prev Chronic Dis. 2014.

- **Year/status:** 2014
- **Evidence/source type:** Workplace intervention study
- **Link:** https://www.cdc.gov/pcd/issues/2014/13_0318.htm
- **Product use and limitation:** Prompts can alter workday sitting patterns, but a desktop proxy must not claim to directly measure sitting.

## Workstation design

### [S079] ISO 9241-5:2024. Ergonomics of human-system interaction—Part 5: Workstation layout and postural requirements.

- **Year/status:** 2024
- **Evidence/source type:** International ergonomics standard
- **Link:** https://www.iso.org/standard/81594.html
- **Product use and limitation:** Use as a professional reference for layout and adjustability; do not reproduce proprietary standard text.

## Workstation setup

### [S028] US Occupational Safety and Health Administration. Computer Workstations eTool.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations
- **Product use and limitation:** There is no one correct workstation or posture for everyone; provides practical adjustable setup goals.

## Workstation setup / movement

### [S029] US Occupational Safety and Health Administration. Computer Workstations: Good Working Positions.

- **Year/status:** Current
- **Evidence/source type:** US occupational-safety guidance
- **Link:** https://www.osha.gov/etools/computer-workstations/positions
- **Product use and limitation:** Change position, make small adjustments and periodically stand or walk; static perfection is not the goal.

## macOS calendar integration

### [S070] Apple Developer. EventKit.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/eventkit
- **Product use and limitation:** Calendar access requires permission. Convert events to ephemeral busy or free intervals and discard titles, attendees and notes.

## macOS implementation

### [S064] Apple Developer. MenuBarExtra.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/swiftui/menubarextra
- **Product use and limitation:** Native entry point for a menu-bar-first macOS app.

### [S065] Apple Developer. CGEventSource.secondsSinceLastEventType.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/coregraphics/cgeventsource/secondssincelasteventtype(_:eventtype:)
- **Product use and limitation:** Can estimate elapsed time since input events without logging keystrokes; this is an activity proxy, not proof of gaze, sitting or movement.

### [S068] Apple Developer. Defining your app’s Focus filter.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/appintents/defining-your-app-s-focus-filter
- **Product use and limitation:** Focus Filters are user-configured app behaviour, not a general public API for silently reading all Focus state.

### [S069] Apple Developer. App Sandbox.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/security/app-sandbox
- **Product use and limitation:** Mac App Store distribution requires sandboxing; permissions and data access must be minimized.

### [S071] Apple Developer. SMAppService.

- **Year/status:** Current
- **Evidence/source type:** Official platform documentation
- **Link:** https://developer.apple.com/documentation/servicemanagement/smappservice
- **Product use and limitation:** Use supported launch-at-login APIs rather than legacy or private mechanisms.

## macOS notifications

### [S072] Apple Developer. User Notifications and notification Human Interface Guidelines.

- **Year/status:** Current
- **Evidence/source type:** Official platform guidance
- **Link:** https://developer.apple.com/design/human-interface-guidelines/notifications
- **Product use and limitation:** Wellness nudges should not misuse Time Sensitive or Critical interruption levels and should respect user control.
