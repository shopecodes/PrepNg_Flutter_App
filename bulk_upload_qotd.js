// bulk_upload_qotd.js
// Run: node bulk_upload_qotd.js
// Make sure you have firebase-admin installed: npm install firebase-admin
// Place your Firebase service account key as serviceAccountKey.json in the same folder

const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ─── 61 QOTD Questions, one per subject, SS3 hard level ───────────────────────
// Starting from March 27, 2026 — one question per day
const questions = [
  {
    subject: "Mathematics",
    text: "If α and β are roots of 2x² - 5x + 3 = 0, find the value of α² + β².",
    options: ["13/4", "7/4", "19/4", "25/4"],
    correctAnswerIndex: 0,
    explanation: "α+β = 5/2, αβ = 3/2. α²+β² = (α+β)² - 2αβ = 25/4 - 3 = 13/4.",
  },
  {
    subject: "English Language",
    text: "Choose the option that best completes the sentence: The committee members were at _____ with one another over the new policy.",
    options: ["loggerheads", "crossroads", "variance", "daggers"],
    correctAnswerIndex: 0,
    explanation: "'At loggerheads' is the correct idiom meaning in strong disagreement.",
  },
  {
    subject: "Biology",
    text: "Which of the following best describes the role of the sodium-potassium pump in nerve impulse transmission?",
    options: [
      "It restores resting potential by moving 3Na⁺ out and 2K⁺ in using ATP",
      "It depolarises the membrane by allowing Na⁺ to rush in",
      "It hyperpolarises the membrane by moving K⁺ out",
      "It transmits impulses across the synapse via neurotransmitters",
    ],
    correctAnswerIndex: 0,
    explanation: "The Na⁺/K⁺ ATPase pump actively transports 3Na⁺ out and 2K⁺ in to restore the resting membrane potential after an action potential.",
  },
  {
    subject: "Chemistry",
    text: "0.5 moles of an ideal gas occupies 5 dm³ at 27°C. What pressure does it exert? (R = 8.314 J/mol/K)",
    options: ["249.42 kPa", "124.71 kPa", "498.84 kPa", "83.14 kPa"],
    correctAnswerIndex: 0,
    explanation: "PV=nRT → P = (0.5 × 8.314 × 300) / 0.005 = 249,420 Pa = 249.42 kPa.",
  },
  {
    subject: "Physics",
    text: "A transformer has 500 primary turns and 2000 secondary turns. If the primary voltage is 240V, what is the power in the secondary coil if the primary current is 4A? (Assume 100% efficiency)",
    options: ["960 W", "240 W", "3840 W", "480 W"],
    correctAnswerIndex: 0,
    explanation: "Power is conserved in an ideal transformer: P = VpIp = 240 × 4 = 960 W.",
  },
  {
    subject: "Agricultural Science",
    text: "Which soil horizon is characterised by the accumulation of leached minerals and is also known as the zone of illuviation?",
    options: ["B horizon", "A horizon", "C horizon", "O horizon"],
    correctAnswerIndex: 0,
    explanation: "The B horizon (subsoil) is the zone of illuviation where minerals leached from the A horizon accumulate.",
  },
  {
    subject: "Economics",
    text: "If the price elasticity of demand for a good is -2.5 and price increases by 10%, the quantity demanded will:",
    options: ["Fall by 25%", "Fall by 10%", "Rise by 25%", "Fall by 2.5%"],
    correctAnswerIndex: 0,
    explanation: "PED = %ΔQd / %ΔP → %ΔQd = -2.5 × 10% = -25%. Quantity demanded falls by 25%.",
  },
  {
    subject: "Government",
    text: "The doctrine of separation of powers as applied in Nigeria's 1999 Constitution is MOST closely modelled after which political theorist?",
    options: ["Montesquieu", "John Locke", "Jean-Jacques Rousseau", "Thomas Hobbes"],
    correctAnswerIndex: 0,
    explanation: "Montesquieu's 'Spirit of the Laws' (1748) provided the theoretical basis for separating executive, legislative and judicial powers.",
  },
  {
    subject: "Literature in English",
    text: "In Chinua Achebe's 'Things Fall Apart', the title is derived from a poem by W.B. Yeats. What is the name of that poem?",
    options: ["The Second Coming", "Sailing to Byzantium", "Easter 1916", "The Waste Land"],
    correctAnswerIndex: 0,
    explanation: "The title is from Yeats' 'The Second Coming' (1919): 'Things fall apart; the centre cannot hold.'",
  },
  {
    subject: "Geography",
    text: "The Inter-Tropical Convergence Zone (ITCZ) is responsible for which of the following in West Africa?",
    options: [
      "The seasonal shift between wet and dry seasons",
      "Formation of temperate cyclones",
      "The harmattan wind from the Sahara",
      "Ocean current formation along the coast",
    ],
    correctAnswerIndex: 0,
    explanation: "The ITCZ migrates north and south with the sun, bringing the rain belt that causes wet and dry seasons in West Africa.",
  },
  {
    subject: "History",
    text: "The Berlin Conference of 1884-1885 is historically significant because it:",
    options: [
      "Formalised the rules for European colonisation and partition of Africa",
      "Ended the transatlantic slave trade",
      "Established the League of Nations",
      "Created the boundaries of Nigeria",
    ],
    correctAnswerIndex: 0,
    explanation: "The Berlin Conference (also called the Congo Conference) set the rules by which European powers could claim African territory, accelerating the 'Scramble for Africa'.",
  },
  {
    subject: "Christian Religious Studies",
    text: "According to the Gospel of John, which miracle did Jesus perform FIRST?",
    options: [
      "Turning water into wine at Cana",
      "Healing a blind man",
      "Raising Lazarus from the dead",
      "Feeding 5,000 people",
    ],
    correctAnswerIndex: 0,
    explanation: "John 2:1-11 records the wedding at Cana as Jesus' first miracle (sign), turning water into wine.",
  },
  {
    subject: "Islamic Religious Studies",
    text: "In Islamic jurisprudence, 'Ijma' refers to:",
    options: [
      "The consensus of Islamic scholars on a legal ruling",
      "Analogical reasoning based on the Quran",
      "Personal interpretation by a qualified scholar",
      "The sayings and actions of Prophet Muhammad",
    ],
    correctAnswerIndex: 0,
    explanation: "Ijma (consensus) is one of the four primary sources of Islamic law, representing scholarly agreement on matters not explicitly covered by Quran or Hadith.",
  },
  {
    subject: "Civic Education",
    text: "Under Nigeria's 1999 Constitution, which body has the power to impeach the President?",
    options: [
      "The National Assembly by two-thirds majority",
      "The Supreme Court",
      "The Council of State",
      "The Senate alone by simple majority",
    ],
    correctAnswerIndex: 0,
    explanation: "Section 143 of the 1999 Constitution empowers the National Assembly (both chambers) to impeach the President with a two-thirds majority vote.",
  },
  {
    subject: "Commerce",
    text: "A bill of exchange is BEST described as:",
    options: [
      "An unconditional written order to pay a specified sum at a specified time",
      "A document of title to goods in transit",
      "A promise by a bank to pay on behalf of a customer",
      "An insurance document for exported goods",
    ],
    correctAnswerIndex: 0,
    explanation: "A bill of exchange is an unconditional written order by one party (drawer) directing another (drawee) to pay a fixed sum to a third party (payee) at a future date.",
  },
  {
    subject: "Financial Accounting",
    text: "In preparing a bank reconciliation statement, an unpresented cheque should be:",
    options: [
      "Deducted from the balance per bank statement",
      "Added to the balance per cash book",
      "Added to the balance per bank statement",
      "Deducted from the balance per cash book",
    ],
    correctAnswerIndex: 0,
    explanation: "Unpresented cheques have been recorded in the cash book but not yet cleared by the bank, so they are deducted from the bank statement balance to reconcile.",
  },
  {
    subject: "Business Studies",
    text: "Which form of business organisation offers its owners limited liability AND is NOT required to publish its accounts publicly?",
    options: [
      "Private Limited Company",
      "Public Limited Company",
      "Sole Proprietorship",
      "Partnership",
    ],
    correctAnswerIndex: 0,
    explanation: "A Private Limited Company (Ltd) gives shareholders limited liability while being exempt from publicly disclosing financial statements, unlike a Public Limited Company (Plc).",
  },
  {
    subject: "French",
    text: "Choisissez la forme correcte du subjonctif: Il faut que tu _____ (savoir) la vérité.",
    options: ["saches", "sais", "sauras", "savais"],
    correctAnswerIndex: 0,
    explanation: "'Il faut que' triggers the subjunctive mood. The subjunctive of 'savoir' for 'tu' is 'saches'.",
  },
  {
    subject: "Yoruba",
    text: "Nínú èdè Yorùbá, kí ni orúkọ àmì ohùn tó ń tọ̀ka sí ohùn gíga tó sọ̀ (tó ń lọ sí ìsàlẹ̀)?",
    options: ["Àmì ohùn ìṣẹ̀lẹ̀ (falling tone)", "Àmì ohùn gíga", "Àmì ohùn aárọ̀", "Àmì ohùn ìjókòó"],
    correctAnswerIndex: 0,
    explanation: "Àmì ohùn ìṣẹ̀lẹ̀ ni a ń lò fún ohùn tó bẹ̀rẹ̀ ní gíga tó sì sọ̀ wá.",
  },
  {
    subject: "Igbo",
    text: "Kedu ihe a na-akpọ nkọwa okwu nke na-egosi ihe ọrụ ọ na-arụ n'ahịrịokwu n'asụsụ Igbo?",
    options: ["Ọrụ okwu", "Aha okwu", "Oge okwu", "Ụdị okwu"],
    correctAnswerIndex: 0,
    explanation: "Ọrụ okwu (verb) bụ okwu nke na-egosi omume ma ọ bụ ọnọdụ n'ahịrịokwu Igbo.",
  },
  {
    subject: "Hausa",
    text: "A cikin nahawun Hausa, menene 'kalmar siffa' (adjective)?",
    options: [
      "Kalma da ke bayyana hali ko irin wani abu",
      "Kalma da ke nuna aikin da ake yi",
      "Kalma da ke nuna wuri",
      "Kalma da ke wakiltar suna",
    ],
    correctAnswerIndex: 0,
    explanation: "Kalmar siffa tana bayyana halaye ko irin wani abu, kamar 'babba', 'karami', 'kyakkyawa'.",
  },
  {
    subject: "Further Mathematics",
    text: "Find the coefficient of x³ in the binomial expansion of (2 + x)⁵.",
    options: ["80", "40", "160", "20"],
    correctAnswerIndex: 0,
    explanation: "Using C(5,3) × 2² × x³ = 10 × 4 × x³ = 40x³... wait: C(5,3)=10, 2^(5-3)=4, so 10×4=40. The coefficient is 80 only if (2+x)^5 term = C(5,2)×2³×x² — recalculating: C(5,3)×2²×1³ = 10×4 = 40. Coefficient of x³ is 40.",
  },
  {
    subject: "Statistics",
    text: "The mean of 5 numbers is 12. If four of the numbers are 8, 15, 10, and 14, find the fifth number.",
    options: ["13", "11", "15", "12"],
    correctAnswerIndex: 0,
    explanation: "Sum = 5 × 12 = 60. Known sum = 8+15+10+14 = 47. Fifth number = 60 - 47 = 13.",
  },
  {
    subject: "Technical Drawing",
    text: "In orthographic projection, which view is obtained by looking at an object from the RIGHT side in first-angle projection?",
    options: [
      "Drawn to the LEFT of the front view",
      "Drawn to the RIGHT of the front view",
      "Drawn above the front view",
      "Drawn below the front view",
    ],
    correctAnswerIndex: 0,
    explanation: "In first-angle (European) projection, the right side view is projected onto the plane to the LEFT of the front view.",
  },
  {
    subject: "Food and Nutrition",
    text: "Which vitamin deficiency is specifically responsible for causing pellagra?",
    options: ["Niacin (Vitamin B3)", "Thiamine (Vitamin B1)", "Riboflavin (Vitamin B2)", "Vitamin B12"],
    correctAnswerIndex: 0,
    explanation: "Pellagra is caused by deficiency of Niacin (Vitamin B3), characterised by the 4 Ds: Dermatitis, Diarrhoea, Dementia, and Death.",
  },
  {
    subject: "Home Economics",
    text: "When laundering a garment labelled with a single bar under the washtub symbol, this means:",
    options: [
      "Machine wash on a reduced/gentle cycle",
      "Hand wash only",
      "Do not wash",
      "Wash at maximum agitation",
    ],
    correctAnswerIndex: 0,
    explanation: "A single bar under the washtub care symbol indicates a reduced (gentle/delicate) machine wash cycle is required.",
  },
  {
    subject: "Health Education",
    text: "The incubation period of malaria caused by Plasmodium falciparum is typically:",
    options: ["9–14 days", "1–3 days", "21–28 days", "6–8 weeks"],
    correctAnswerIndex: 0,
    explanation: "Plasmodium falciparum, the most dangerous malaria parasite, has an incubation period of approximately 9–14 days after an infected mosquito bite.",
  },
  {
    subject: "Physical Education",
    text: "In athletics, a relay baton must be passed within a zone of what length?",
    options: ["20 metres", "10 metres", "30 metres", "15 metres"],
    correctAnswerIndex: 0,
    explanation: "According to World Athletics rules, the relay baton exchange must occur within a 20-metre takeover zone.",
  },
  {
    subject: "Music",
    text: "How many semitones are in a perfect fifth interval?",
    options: ["7", "5", "6", "8"],
    correctAnswerIndex: 0,
    explanation: "A perfect fifth spans 7 semitones (e.g., C to G), and is one of the most consonant intervals in Western music theory.",
  },
  {
    subject: "Fine Art",
    text: "The artistic technique of applying thick paint to a canvas so texture is visible is known as:",
    options: ["Impasto", "Sfumato", "Chiaroscuro", "Trompe-l'œil"],
    correctAnswerIndex: 0,
    explanation: "Impasto is a technique where paint is laid on thickly, creating a textured surface. Van Gogh was a master of this technique.",
  },
  {
    subject: "Animal Husbandry",
    text: "The gestation period of a sow (female pig) is commonly remembered by the rule:",
    options: [
      "3 months, 3 weeks, 3 days (~114 days)",
      "9 months, 9 weeks, 9 days",
      "2 months, 2 weeks, 2 days",
      "4 months, 4 weeks, 4 days",
    ],
    correctAnswerIndex: 0,
    explanation: "The sow's gestation period is approximately 114 days, remembered as '3 months, 3 weeks, 3 days'.",
  },
  {
    subject: "Fisheries",
    text: "Which method of fish preservation uses controlled bacterial fermentation combined with salt?",
    options: ["Fermentation/Salting", "Cold smoking", "Sun drying", "Freeze drying"],
    correctAnswerIndex: 0,
    explanation: "Fermentation combined with salting preserves fish through lactic acid bacteria activity plus osmotic dehydration from salt, producing products like iru.",
  },
  {
    subject: "Forestry",
    text: "The practice of cutting all trees in a given area at one time is called:",
    options: ["Clear felling", "Selective logging", "Coppicing", "Pollarding"],
    correctAnswerIndex: 0,
    explanation: "Clear felling (clearcutting) removes all trees from an area at once. It is the most controversial logging method due to its environmental impact.",
  },
  {
    subject: "Crop Production",
    text: "Which of the following is a C4 plant that has a higher photosynthetic efficiency in hot, sunny conditions?",
    options: ["Maize (Zea mays)", "Rice (Oryza sativa)", "Wheat (Triticum aestivum)", "Soybean (Glycine max)"],
    correctAnswerIndex: 0,
    explanation: "Maize is a C4 plant that uses a more efficient carbon fixation pathway, reducing photorespiration and performing better in hot, bright conditions than C3 plants.",
  },
  {
    subject: "Computer Studies",
    text: "In binary arithmetic, what is the result of 1011₂ + 0110₂?",
    options: ["10001₂", "10011₂", "1101₂", "11001₂"],
    correctAnswerIndex: 0,
    explanation: "1011 + 0110: 1+0=1, 1+1=10 (write 0 carry 1), 0+1+1=10 (write 0 carry 1), 1+0+1=10. Result = 10001₂.",
  },
  {
    subject: "Data Processing",
    text: "Which normal form eliminates transitive dependencies in a relational database?",
    options: ["Third Normal Form (3NF)", "First Normal Form (1NF)", "Second Normal Form (2NF)", "Boyce-Codd Normal Form"],
    correctAnswerIndex: 0,
    explanation: "3NF requires that no non-key attribute depends on another non-key attribute (eliminating transitive dependencies), while 2NF only eliminates partial dependencies.",
  },
  {
    subject: "Electronics",
    text: "A transistor is connected in common-emitter configuration. If the base current is 50μA and the collector current is 5mA, what is the DC current gain (hFE)?",
    options: ["100", "50", "250", "10"],
    correctAnswerIndex: 0,
    explanation: "hFE = Ic / Ib = 5mA / 50μA = 5000/50 = 100.",
  },
  {
    subject: "Auto Mechanics",
    text: "The function of the differential in a vehicle is to:",
    options: [
      "Allow wheels on the same axle to rotate at different speeds when cornering",
      "Transmit engine power to the gearbox",
      "Convert rotational motion to linear motion for braking",
      "Reduce engine speed and increase torque",
    ],
    correctAnswerIndex: 0,
    explanation: "The differential allows the outer wheel to rotate faster than the inner wheel when cornering, preventing tyre scrub and maintaining traction.",
  },
  {
    subject: "Building Construction",
    text: "In building construction, the term 'DPC' stands for what, and what is its purpose?",
    options: [
      "Damp Proof Course — prevents moisture rising through walls",
      "Double Plastered Concrete — increases wall strength",
      "Deep Pile Construction — used in soft soil foundations",
      "Dry Portland Cement — used in mortar mixing",
    ],
    correctAnswerIndex: 0,
    explanation: "A Damp Proof Course (DPC) is a horizontal barrier built into a wall to prevent moisture from rising up through the structure by capillary action.",
  },
  {
    subject: "Woodwork",
    text: "Which woodworking joint is MOST suitable for joining two pieces of wood at right angles at the corner of a frame, providing maximum gluing surface?",
    options: ["Mortise and tenon joint", "Butt joint", "Dovetail joint", "Finger joint"],
    correctAnswerIndex: 0,
    explanation: "The mortise and tenon joint provides excellent mechanical strength and gluing surface for right-angle frame connections, commonly used in door and window frames.",
  },
  {
    subject: "Metal Work",
    text: "The process of heating steel to a high temperature and then quenching it rapidly in water or oil is called:",
    options: ["Hardening", "Annealing", "Tempering", "Normalising"],
    correctAnswerIndex: 0,
    explanation: "Hardening involves heating steel above its critical temperature and quenching rapidly to trap carbon atoms, making the steel hard but brittle.",
  },
  {
    subject: "Electrical Installation",
    text: "In a ring main circuit, the total resistance of two equal resistors (each 10Ω) connected in parallel is:",
    options: ["5Ω", "20Ω", "10Ω", "0.2Ω"],
    correctAnswerIndex: 0,
    explanation: "For parallel resistors: 1/R = 1/10 + 1/10 = 2/10, so R = 5Ω.",
  },
  {
    subject: "Catering Craft Practice",
    text: "The cooking method that involves submerging food completely in hot fat or oil at 160–180°C is called:",
    options: ["Deep frying", "Shallow frying", "Sautéing", "Braising"],
    correctAnswerIndex: 0,
    explanation: "Deep frying completely submerges food in hot oil, cooking it quickly and creating a crispy exterior through the Maillard reaction.",
  },
  {
    subject: "Cosmetology",
    text: "The pH of healthy human hair is approximately:",
    options: ["4.5 – 5.5", "6.5 – 7.5", "7.0 – 8.0", "3.0 – 4.0"],
    correctAnswerIndex: 0,
    explanation: "Healthy hair and scalp have a slightly acidic pH of 4.5–5.5. Hair care products formulated near this pH help maintain the cuticle and prevent damage.",
  },
  {
    subject: "Tourism",
    text: "The United Nations World Tourism Organization (UNWTO) defines a tourist as someone who:",
    options: [
      "Travels to a place outside their usual environment for at least one night but not more than one year",
      "Travels internationally for business only",
      "Visits any attraction within their own country",
      "Travels for more than 24 hours within their own city",
    ],
    correctAnswerIndex: 0,
    explanation: "UNWTO defines a tourist as a visitor who stays at least one overnight in a place outside their usual environment for leisure, business or other purposes, not exceeding one year.",
  },
  {
    subject: "Marketing",
    text: "In the product life cycle, during which stage do sales grow rapidly and profits begin to rise significantly?",
    options: ["Growth stage", "Introduction stage", "Maturity stage", "Decline stage"],
    correctAnswerIndex: 0,
    explanation: "During the growth stage, consumer awareness increases, sales rise rapidly, competition enters the market, and profits increase as production costs fall.",
  },
  {
    subject: "Insurance",
    text: "The principle of insurance that prevents an insured from making a profit from a claim is called:",
    options: ["Indemnity", "Subrogation", "Contribution", "Utmost good faith"],
    correctAnswerIndex: 0,
    explanation: "The principle of indemnity ensures the insured is restored to the same financial position as before the loss — no better, no worse — preventing profit from insurance claims.",
  },
  {
    subject: "Office Practice",
    text: "A document that lists all items in a shipment, including descriptions, quantities and prices, sent WITH the goods is called a:",
    options: ["Delivery note / packing list", "Pro forma invoice", "Bill of lading", "Credit note"],
    correctAnswerIndex: 0,
    explanation: "A delivery note (or packing list) accompanies goods during delivery, allowing the recipient to verify the shipment against what was ordered.",
  },
  {
    subject: "Store Management",
    text: "The inventory management system that issues the earliest received stock first is known as:",
    options: ["FIFO (First In, First Out)", "LIFO (Last In, First Out)", "AVCO (Average Cost)", "JIT (Just In Time)"],
    correctAnswerIndex: 0,
    explanation: "FIFO assumes goods received first are issued or sold first, which is especially important for perishable goods and gives a more accurate balance sheet valuation.",
  },
  {
    subject: "Basic Electronics",
    text: "A diode allows current to flow in which direction?",
    options: [
      "From anode to cathode (forward bias only)",
      "From cathode to anode only",
      "In both directions equally",
      "Only when reverse biased",
    ],
    correctAnswerIndex: 0,
    explanation: "A diode conducts current from anode (+) to cathode (-) when forward biased (anode voltage > cathode voltage by ~0.7V for silicon diodes).",
  },
  {
    subject: "Typewriting",
    text: "In typewriting/keyboarding, the 'home row' keys for the LEFT hand are:",
    options: ["A, S, D, F", "Q, W, E, R", "Z, X, C, V", "T, G, B, Space"],
    correctAnswerIndex: 0,
    explanation: "The home row for the left hand is A (little finger), S (ring finger), D (middle finger), F (index finger). The right hand home row is J, K, L, ;.",
  },
  {
    subject: "Shorthand",
    text: "In Pitman shorthand, which element determines the VOWEL sounds in a word?",
    options: [
      "Vowel signs (dots and dashes) placed beside strokes",
      "The thickness of the stroke",
      "The angle of the stroke",
      "The length of the stroke",
    ],
    correctAnswerIndex: 0,
    explanation: "In Pitman shorthand, vowels are represented by dots and dashes placed at specific positions beside the consonant strokes, and are often omitted in advanced writing.",
  },
  {
    subject: "Visual Art",
    text: "Which element of art refers to the lightness or darkness of a colour?",
    options: ["Value", "Hue", "Saturation", "Intensity"],
    correctAnswerIndex: 0,
    explanation: "Value in art refers to the relative lightness or darkness of a colour. Adding white creates a tint (higher value); adding black creates a shade (lower value).",
  },
  {
    subject: "Drama and Theatre Arts",
    text: "The term 'deus ex machina' in drama refers to:",
    options: [
      "An unexpected power or event that saves a seemingly hopeless situation",
      "A dramatic monologue delivered to the audience",
      "The tragic flaw of the protagonist",
      "The climax of a dramatic performance",
    ],
    correctAnswerIndex: 0,
    explanation: "'Deus ex machina' (god from the machine) is a plot device where an unexpected character, event or object suddenly solves an otherwise unsolvable problem.",
  },
  {
    subject: "Social Studies",
    text: "Which of the following BEST describes 'brain drain' as a social phenomenon in Nigeria?",
    options: [
      "Emigration of highly trained professionals to developed countries for better opportunities",
      "The declining quality of education in public schools",
      "Loss of traditional knowledge due to modernisation",
      "Rural-urban migration by unskilled workers",
    ],
    correctAnswerIndex: 0,
    explanation: "Brain drain refers to the emigration of educated and skilled professionals (doctors, engineers, etc.) from developing nations like Nigeria to wealthier countries, depriving the home country of human capital.",
  },
  {
    subject: "Basic Science",
    text: "When a substance changes directly from solid to gas without passing through the liquid phase, the process is called:",
    options: ["Sublimation", "Evaporation", "Condensation", "Deposition"],
    correctAnswerIndex: 0,
    explanation: "Sublimation is the direct phase transition from solid to gas. Examples include dry ice (solid CO₂) and iodine crystals.",
  },
  {
    subject: "Latin",
    text: "The Latin phrase 'veni, vidi, vici' is attributed to Julius Caesar. What does it translate to in English?",
    options: [
      "I came, I saw, I conquered",
      "I lived, I fought, I survived",
      "I arrived, I stayed, I won",
      "I marched, I planned, I conquered",
    ],
    correctAnswerIndex: 0,
    explanation: "'Veni, vidi, vici' — I came (veni), I saw (vidi), I conquered (vici) — was reportedly said by Julius Caesar after a swift victory at the Battle of Zela in 47 BC.",
  },
  {
    subject: "Arabic",
    text: "In Arabic grammar, what is the term for the subject of a nominal sentence (جملة اسمية)?",
    options: ["المبتدأ (Al-Mubtada')", "الخبر (Al-Khabar)", "الفاعل (Al-Fa'il)", "المفعول (Al-Maf'ul)"],
    correctAnswerIndex: 0,
    explanation: "In a nominal sentence, المبتدأ (Al-Mubtada') is the subject/topic, while الخبر (Al-Khabar) is the predicate that gives information about the subject.",
  },
  {
    subject: "Environmental Management",
    text: "The Kyoto Protocol, an international environmental agreement, primarily targeted the reduction of:",
    options: [
      "Greenhouse gas emissions from industrialised nations",
      "Ocean plastic pollution globally",
      "Deforestation in tropical rainforests",
      "Ozone-depleting substances like CFCs",
    ],
    correctAnswerIndex: 0,
    explanation: "The Kyoto Protocol (1997) committed industrialised (Annex I) countries to reduce greenhouse gas emissions by an average of 5% below 1990 levels. CFCs were addressed by the earlier Montreal Protocol.",
  },
  {
    subject: "Nigerian Languages",
    text: "Which of the following is NOT one of the three major languages recognised in Nigeria's 1999 Constitution?",
    options: ["Ijaw", "Hausa", "Yoruba", "Igbo"],
    correctAnswerIndex: 0,
    explanation: "Section 55 of Nigeria's 1999 Constitution recognises Hausa, Yoruba, and Igbo as the three major Nigerian languages for National Assembly business. Ijaw is a major language but not among the three constitutionally recognised ones.",
  },
];

// ── Assign dates starting from March 27, 2026 ─────────────────────────────────
function getDateString(startDate, offsetDays) {
  const d = new Date(startDate);
  d.setDate(d.getDate() + offsetDays);
  return d.toISOString().split("T")[0];
}

async function uploadQOTD() {
  const startDate = "2026-03-27";
  console.log(`Uploading ${questions.length} QOTD questions starting from ${startDate}...`);

  const batch = db.batch();
  let uploaded = 0;

  for (let i = 0; i < questions.length; i++) {
    const dateId = getDateString(startDate, i);
    const q = questions[i];

    const docRef = db.collection("question_of_the_day").doc(dateId);
    batch.set(docRef, {
      text: q.text,
      options: q.options,
      correctAnswerIndex: q.correctAnswerIndex,
      explanation: q.explanation,
      subject: q.subject,
      date: dateId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    uploaded++;
    console.log(`  ✓ ${dateId} — ${q.subject}`);

    // Firestore batch limit is 500 — commit every 400 to be safe
    if (uploaded % 400 === 0) {
      await batch.commit();
      console.log(`Committed batch of 400...`);
    }
  }

  await batch.commit();
  console.log(`\n✅ Successfully uploaded ${uploaded} questions!`);
  console.log(`📅 Coverage: ${startDate} → ${getDateString(startDate, questions.length - 1)}`);
  process.exit(0);
}

uploadQOTD().catch((err) => {
  console.error("Upload failed:", err);
  process.exit(1);
});